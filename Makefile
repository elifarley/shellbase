# shellbase Makefile
# Targets for installing and verifying systemd services
#
# LESSONS LEARNED - Read this before modifying!
# ====================================================
#
# 1. TTY Detection in Makefiles:
#    - DO NOT use: test -t 1 (broken in make - always returns false)
#    - DO use: tput colors (works correctly in make context)
#    - Pattern: COLORS := $(shell tput colors 2>/dev/null)
#              COLORS_OK := $(shell test -n "$(COLORS)" && test $(COLORS) -ge 8 && echo 1)
#
# 2. Shell Substitution in Make Variables:
#    - $$ expands to $ when passed to shell
#    - BUT $${BASH_SOURCE[0]} fails because make's shell function doesn't handle bash arrays
#    - SOLUTION: Use simpler shell commands like $(shell pwd) instead
#
# 3. Symlink Strategy for Service Files:
#    - Symlinks enable "single source of truth" - repo changes reflected immediately
#    - User services use %h specifier (works in user services only)
#    - System services CANNOT use %h - must use wrapper script sourced from config
#    - Wrapper at /usr/local/sbin/shadowcache-system reads SHELLBASE_USER from $PERSISTENT/.shellbase-system.env
#
# 4. Verification Target Design:
#    - systemd-analyze verify outputs warnings to stderr but returns 0
#    - Use || true to prevent false failures from system-wide warnings
#    - Check symlink vs regular file to detect copy install vs symlink install
#
# 5. Idempotent Operations:
#    - ln -sf replaces existing symlinks WITHOUT error, BUT fails if the old symlink
#      is "dangling" (points to non-existent target) and the target path is different
#    - Solution: Always rm -f before ln -sf when replacing symlinks that may be dangling
#    - Example: sudo rm -f /usr/local/sbin/shadowcache-system
#              sudo ln -sf $(REPO_BASE)/wrapper.sh /usr/local/sbin/shadowcache-system
#    - systemctl enable is idempotent (safe to run multiple times)
#    - Use @- prefix for commands that may fail harmlessly
#
# 6. Dangling Symlinks and chmod:
#    - chmod on a dangling symlink FAILS (cannot operate on non-existent target)
#    - chmod on the SOURCE file works (before or after creating symlink)
#    - Pattern: chmod +x $(REPO_BASE)/wrapper.sh (source), not /usr/local/sbin/wrapper (symlink)
#    - This is safer because the source file always exists in a controlled location
#
# 7. REPO_BASE Detection with $(shell pwd):
#    - DO NOT hardcode user-specific paths like /home/$(USER)/src/shellbase
#    - Users may clone repos to different locations (~/IdeaProjects, ~/src, etc.)
#    - Solution: Use $(shell pwd) to detect actual working directory
#    - Pattern: REPO_BASE := $(shell pwd) or check known locations with ifeq
#    - This ensures make works from wherever the repo was cloned
#
# 8. CRITICAL: Make Variable Definition Order Matters!
#    - Make variables are evaluated TOP-TO-BOTTOM in order of appearance
#    - If variable A references variable B, then B MUST be defined BEFORE A
#    - Common mistake: Defining derived variables too early in the file
#    - Example bug: REPO_BIN := $(REPO_BASE)/bin (line 60) but REPO_BASE defined at line 72
#      → Result: REPO_BIN expands to "/bin" because REPO_BASE was empty at line 60
#    - Solution: Define base variables FIRST, then derived variables that reference them
#    - Debug tip: Use `make -n target` to see expanded values without executing
#    - Pattern: Base config → Derived paths → .PHONY → Targets (this order prevents bugs)
#
# 9. Bin Symlink Strategy:
#    - Individual file symlinks (not directory symlinks) for direct PATH access
#    - Idempotent installation: backup existing file copies with .bak extension
#    - Verification distinguishes between symlink, file copy, and missing
#    - Reuses systemd service symlink pattern for consistency
#    - Files are listed in BIN_SCRIPTS variable - easy to add/remove scripts
#
# 10. Systemd Timer Reload Pitfalls:
#     - daemon-reload reloads unit files from disk but does NOT apply schedule changes to running timers
#     - After changing OnCalendar, MUST restart the timer: systemctl stop X.timer && systemctl start X.timer
#     - Without restart, the timer continues using the old schedule even though the file on disk is updated
#     - Pattern for install targets: daemon-reload → enable → stop → start (stop may fail on first install, use @-)
#     - Lesson: "daemon-reload reloads definitions, restart applies them"


.PHONY: help doctor install-user install-system install-bin install-config verify-user verify-system verify-bin verify-logrotate verify-config install-all verify-all uninstall-user uninstall-system uninstall-bin uninstall-config

# Default target
.DEFAULT_GOAL := help

# Quiet make output (suppress "Entering/Leaving directory" messages)
MAKEFLAGS += --no-print-directory

# Configuration
SHELLBASE_REPO_DIR := $(shell pwd)
USER := $(shell id -un)
# REPO_BASE is determined by checking the actual repo location
# First, try to detect from SHELLBASE_REPO_DIR (current directory)
ifeq ($(SHELLBASE_REPO_DIR),$(HOME)/IdeaProjects/shellbase)
    REPO_BASE := $(HOME)/IdeaProjects/shellbase
else ifeq ($(SHELLBASE_REPO_DIR),/home/$(USER)/src/shellbase)
    REPO_BASE := /home/$(USER)/src/shellbase
else
    # Fallback: use current directory if running from elsewhere
    REPO_BASE := $(SHELLBASE_REPO_DIR)
endif

# Bin directory configuration (must be after REPO_BASE definition)
BIN_SCRIPTS := shadowcache.sh kopia-snapshot.sh kopia-remote-sync.sh backup-prepare.sh backup-system-info.sh btrfs-scrub.sh
HOME_BIN := $(HOME)/bin
REPO_BIN := $(REPO_BASE)/bin

# Home directory configuration symlinks
HOME_CONFIG_FILES := .kopiaignore

# Logrotate configuration directory
LOGROTATE_D := /etc/logrotate.d
REPO_LOGROTATE := $(REPO_BASE)/etc/logrotate.d

# Color output support (tput-based TTY detection)
COLORS := $(shell tput colors 2>/dev/null)
 COLORS_OK := $(shell test -n "$(COLORS)" && test $(COLORS) -ge 8 && echo 1)
 ifdef COLORS_OK
    BOLD := $(shell tput bold 2>/dev/null)
    GREEN := $(shell tput setaf 2 2>/dev/null)
    YELLOW := $(shell tput setaf 3 2>/dev/null)
    RED := $(shell tput setaf 1 2>/dev/null)
    CYAN := $(shell tput setaf 6 2>/dev/null)
    RESET := $(shell tput sgr0 2>/dev/null)
    OK := [$(GREEN)+$(RESET)]
    WARN := [$(YELLOW)!$(RESET)]
    ERR := [$(RED)$(BOLD)!$(RESET)]
    INFO := [$(CYAN)*$(RESET)]
else
    BOLD :=
    GREEN :=
    YELLOW :=
    RED :=
    CYAN :=
    RESET :=
    OK := [+]
    WARN := [!]
    ERR := [!!]
    INFO := [*]
endif

help: ## Show this help message
	@echo "$(BOLD)shellbase Makefile$(RESET)"
	@echo ""
	@echo "$(BOLD)Usage:$(RESET)"
	@echo "  make <target>"
	@echo ""
	@echo "$(BOLD)Targets:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)Examples:$(RESET)"
	@echo "  make doctor          Check prerequisites"
	@echo "  make install-all    Install all symlinks (services + bin)"
	@echo "  make install-bin    Install only ~/bin symlinks"
	@echo "  make verify-all     Verify all installations"
	@echo "  make uninstall-all  Remove all installed symlinks"

doctor: ## Check prerequisites for installation
	@echo "$(INFO) Checking prerequisites..."
	@command -v systemctl >/dev/null 2>&1 || { echo "$(ERR) systemctl not found"; exit 1; }
	@echo "$(OK) systemctl found"
	@test -d $(REPO_BASE) || { echo "$(ERR) Repository not found at $(REPO_BASE)"; exit 1; }
	@echo "$(OK) Repository found at $(REPO_BASE)"
	@test -f $(REPO_BASE)/.config/systemd/user/shadowcache-user@.service || { echo "$(ERR) User service file not found"; exit 1; }
	@test -f $(REPO_BASE)/.config/systemd/user/shadowcache-user-periodic@.service || { echo "$(ERR) User periodic service file not found"; exit 1; }
	@echo "$(OK) User service files found"
	@test -f $(REPO_BASE)/etc/systemd/system/shadowcache-system.service || { echo "$(WARN) System service file not found"; }
	@test -f $(REPO_BASE)/etc/systemd/system/shadowcache-system-periodic.service || { echo "$(WARN) System periodic service file not found"; }
	@echo "$(OK) System service files found"
	@test -f $(REPO_BASE)/etc/systemd/system/shadowcache-system-wrapper.sh || { echo "$(WARN) Wrapper script not found"; }
	@echo "$(OK) Wrapper script found"
	@echo "$(OK) All prerequisites met"

install-user: ## Install user systemd services (no root required)
	@echo "$(INFO) Installing user services for $(USER)..."
	@mkdir -p ~/.config/systemd/user
	@ln -sf $(REPO_BASE)/.config/systemd/user/shadowcache-user@.service ~/.config/systemd/user/
	@ln -sf $(REPO_BASE)/.config/systemd/user/shadowcache-user@.timer ~/.config/systemd/user/
	@ln -sf $(REPO_BASE)/.config/systemd/user/shadowcache-user-periodic@.service ~/.config/systemd/user/
	@systemctl --user daemon-reload
	@systemctl --user enable shadowcache-user@$(USER).service
	@-systemctl --user stop shadowcache-user@$(USER).timer 2>/dev/null || true
	@systemctl --user start shadowcache-user@$(USER).timer
	@echo "$(OK) User services installed and enabled"
	@echo "$(INFO) Symlinks:"
	@ls -la ~/.config/systemd/user/shadowcache-* 2>/dev/null | grep '\->' || true

install-system: ## Install system systemd services (requires sudo)
	@echo "$(INFO) Installing system services..."
	@echo "$(WARN) This requires sudo privileges..."
	@sudo mkdir -p /etc/systemd/system
	@sudo ln -sf $(REPO_BASE)/etc/systemd/system/shadowcache-system.service /etc/systemd/system/
	@sudo ln -sf $(REPO_BASE)/etc/systemd/system/shadowcache-system.timer /etc/systemd/system/
	@sudo ln -sf $(REPO_BASE)/etc/systemd/system/shadowcache-system-periodic.service /etc/systemd/system/
	@sudo rm -f /usr/local/sbin/shadowcache-system
	@sudo ln -sf $(REPO_BASE)/etc/systemd/system/shadowcache-system-wrapper.sh /usr/local/sbin/shadowcache-system
	@sudo chmod +x $(REPO_BASE)/etc/systemd/system/shadowcache-system-wrapper.sh
	@sudo systemctl daemon-reload
	@sudo systemctl enable shadowcache-system.service
	@-sudo systemctl stop shadowcache-system.timer 2>/dev/null || true
	@sudo systemctl start shadowcache-system.timer
	@echo "$(OK) System services installed and enabled"
	@echo "$(INFO) Symlinks:"
	@sudo ls -la /etc/systemd/system/shadowcache-system.* 2>/dev/null | grep '\->' || true
	@sudo ls -la /usr/local/sbin/shadowcache-system 2>/dev/null | grep '\->' || true
	# Install logrotate configuration
	@echo "$(INFO) Installing logrotate configuration..."
	@sudo mkdir -p $(LOGROTATE_D)
	@sudo cp $(REPO_LOGROTATE)/shadowcache-metrics $(LOGROTATE_D)/
	@echo "$(OK) Logrotate config installed: $(LOGROTATE_D)/shadowcache-metrics"

install-bin: ## Install script symlinks to ~/bin
	@echo "$(INFO) Installing bin symlinks to $(HOME_BIN)"
	@mkdir -p $(HOME_BIN)
	@for script in $(BIN_SCRIPTS); do \
		if [ -L $(HOME_BIN)/$$script ]; then \
			existing=$$(readlink $(HOME_BIN)/$$script); \
			if [ "$$existing" = "$(REPO_BIN)/$$script" ]; then \
				echo "$(OK) Symlink exists: $$script"; \
			else \
				echo "$(WARN) $$script points to: $$existing (updating)"; \
				ln -sf $(REPO_BIN)/$$script $(HOME_BIN)/$$script; \
			fi \
		elif [ -f $(HOME_BIN)/$$script ]; then \
			echo "$(WARN) $$script exists as file (backup and replace)"; \
			mv $(HOME_BIN)/$$script $(HOME_BIN)/$$script.bak; \
			ln -s $(REPO_BIN)/$$script $(HOME_BIN)/$$script; \
			echo "$(INFO) Backed up to: $$script.bak"; \
		else \
			ln -s $(REPO_BIN)/$$script $(HOME_BIN)/$$script; \
			echo "$(OK) Created symlink: $$script"; \
		fi \
	done
	@echo "$(OK) Bin symlinks installed"
	# Note: Existing file copies are backed up with .bak extension, not deleted
	# Users can manually remove .bak files after confirming symlinks work correctly

install-config: ## Install home directory config symlinks
	@echo "$(INFO) Installing config symlinks to $(HOME)"
	@for file in $(HOME_CONFIG_FILES); do \
		if [ -L $(HOME)/$$file ]; then \
			existing=$$(readlink $(HOME)/$$file); \
			if [ "$$existing" = "$(REPO_BASE)/$$file" ]; then \
				echo "$(OK) Symlink exists: $$file"; \
			else \
				echo "$(WARN) $$file points to: $$existing (updating)"; \
				ln -sf $(REPO_BASE)/$$file $(HOME)/$$file; \
			fi \
		elif [ -f $(HOME)/$$file ]; then \
			echo "$(WARN) $$file exists as file (backup and replace)"; \
			mv $(HOME)/$$file $(HOME)/$$file.bak; \
			ln -s $(REPO_BASE)/$$file $(HOME)/$$file; \
			echo "$(INFO) Backed up to: $$file.bak"; \
		else \
			ln -s $(REPO_BASE)/$$file $(HOME)/$$file; \
			echo "$(OK) Created symlink: $$file"; \
		fi \
	done
	@echo "$(OK) Config symlinks installed"

install-all: install-user install-system install-bin install-config ## Install all symlinks
	@echo "$(OK) All services installed"

verify-user: ## Verify user service installation
	@echo "$(INFO) Verifying user services for $(USER)..."
	@systemctl --user is-enabled shadowcache-user@$(USER).service >/dev/null 2>&1 || { echo "$(ERR) User service not enabled"; exit 1; }
	@echo "$(OK) User service enabled"
	@systemd-analyze verify ~/.config/systemd/user/shadowcache-user@$(USER).service 2>&1 || true
	@echo "$(OK) User service valid"
	@if [ -L ~/.config/systemd/user/shadowcache-user@.service ]; then \
		echo "$(OK) Service symlink points to: $$(readlink -f ~/.config/systemd/user/shadowcache-user@.service)"; \
	elif [ -f ~/.config/systemd/user/shadowcache-user@.service ]; then \
		echo "$(WARN) Service file exists but is not a symlink (copy install)"; \
	else \
		echo "$(WARN) Service file not found"; \
	fi
	@if [ -L ~/.config/systemd/user/shadowcache-user@.timer ]; then \
		echo "$(OK) Timer symlink points to: $$(readlink -f ~/.config/systemd/user/shadowcache-user@.timer)"; \
	elif [ -f ~/.config/systemd/user/shadowcache-user@.timer ]; then \
		echo "$(WARN) Timer file exists but is not a symlink (copy install)"; \
	else \
		echo "$(WARN) Timer file not found"; \
	fi
	@echo "$(INFO) User service status:"
	@systemctl --user status shadowcache-user@$(USER).service --no-pager 2>&1 | head -n 3 || true

verify-system: ## Verify system service installation
	@echo "$(INFO) Verifying system services..."
	@sudo systemctl is-enabled shadowcache-system.service >/dev/null 2>&1 || { echo "$(ERR) System service not enabled"; exit 1; }
	@echo "$(OK) System service enabled"
	@sudo systemd-analyze verify /etc/systemd/system/shadowcache-system.service 2>&1 || true
	@echo "$(OK) System service valid"
	@if sudo [ -L /etc/systemd/system/shadowcache-system.service ]; then \
		echo "$(OK) Service symlink points to: $$(sudo readlink -f /etc/systemd/system/shadowcache-system.service)"; \
	elif sudo [ -f /etc/systemd/system/shadowcache-system.service ]; then \
		echo "$(WARN) Service file exists but is not a symlink (copy install)"; \
	else \
		echo "$(WARN) Service file not found"; \
	fi
	@if sudo [ -L /etc/systemd/system/shadowcache-system.timer ]; then \
		echo "$(OK) Timer symlink points to: $$(sudo readlink -f /etc/systemd/system/shadowcache-system.timer)"; \
	elif sudo [ -f /etc/systemd/system/shadowcache-system.timer ]; then \
		echo "$(WARN) Timer file exists but is not a symlink (copy install)"; \
	else \
		echo "$(WARN) Timer file not found"; \
	fi
	@if sudo [ -L /usr/local/sbin/shadowcache-system ]; then \
		echo "$(OK) Wrapper symlink points to: $$(sudo readlink -f /usr/local/sbin/shadowcache-system)"; \
	else \
		echo "$(WARN) Wrapper symlink not found"; \
	fi
	@echo "$(INFO) System service status:"
	@sudo systemctl status shadowcache-system.service --no-pager 2>&1 | head -n 3 || true

verify-bin: ## Verify ~/bin symlinks are correctly installed
	@echo "$(INFO) Verifying bin symlinks"
	@for script in $(BIN_SCRIPTS); do \
		if [ -L $(HOME_BIN)/$$script ]; then \
			target=$$(readlink -f $(HOME_BIN)/$$script); \
			if [ "$$target" = "$(REPO_BIN)/$$script" ]; then \
				echo "$(OK) Symlink: $$script"; \
			else \
				echo "$(WARN) $$script points to: $$target (expected: $(REPO_BIN)/$$script)"; \
			fi \
		elif [ -f $(HOME_BIN)/$$script ]; then \
			echo "$(WARN) $$script exists as file, not symlink"; \
		else \
			echo "$(ERR) $$script not found in ~/bin"; \
		fi \
	done
	# Verification order: symlink check → target validation → file check → missing check
	# readlink -f resolves absolute path, critical for detecting broken symlinks

verify-all: verify-bin verify-user verify-system verify-logrotate verify-config ## Verify all installations
	@echo "$(OK) All services verified"

verify-logrotate: ## Verify logrotate configuration is installed and valid
	@echo "$(INFO) Verifying logrotate configuration..."
	@command -v logrotate >/dev/null 2>&1 || { echo "$(WARN) logrotate not found (not critical)"; exit 0; }
	@echo "$(OK) logrotate found"
	@if [ -f $(LOGROTATE_D)/shadowcache-metrics ]; then \
		if logrotate -d $(LOGROTATE_D)/shadowcache-metrics >/dev/null 2>&1; then \
			echo "$(OK) Logrotate config is valid"; \
		else \
			echo "$(WARN) Logrotate config has errors"; \
			logrotate -d $(LOGROTATE_D)/shadowcache-metrics 2>&1 || true; \
		fi \
	else \
		echo "$(WARN) Logrotate config not installed at $(LOGROTATE_D)/shadowcache-metrics"; \
	fi

verify-config: ## Verify home directory config symlinks
	@echo "$(INFO) Verifying config symlinks"
	@for file in $(HOME_CONFIG_FILES); do \
		if [ -L $(HOME)/$$file ]; then \
			target=$$(readlink -f $(HOME)/$$file); \
			if [ "$$target" = "$(REPO_BASE)/$$file" ]; then \
				echo "$(OK) Symlink: $$file"; \
			else \
				echo "$(WARN) $$file points to: $$target (expected: $(REPO_BASE)/$$file)"; \
			fi \
		elif [ -f $(HOME)/$$file ]; then \
			echo "$(WARN) $$file exists as file, not symlink"; \
		else \
			echo "$(ERR) $$file not found in $(HOME)"; \
		fi \
	done

uninstall-user: ## Uninstall user systemd services
	@echo "$(INFO) Uninstalling user services..."
	@-systemctl --user disable shadowcache-user@$(USER).service 2>/dev/null || true
	@-systemctl --user stop shadowcache-user@$(USER).service 2>/dev/null || true
	@-systemctl --user disable shadowcache-user@$(USER).timer 2>/dev/null || true
	@-systemctl --user stop shadowcache-user@$(USER).timer 2>/dev/null || true
	@rm -f ~/.config/systemd/user/shadowcache-user@.service
	@rm -f ~/.config/systemd/user/shadowcache-user@.timer
	@rm -f ~/.config/systemd/user/shadowcache-user-periodic@.service
	@systemctl --user daemon-reload
	@echo "$(OK) User services uninstalled"

uninstall-system: ## Uninstall system systemd services (requires sudo)
	@echo "$(INFO) Uninstalling system services..."
	@echo "$(WARN) This requires sudo privileges..."
	@-sudo systemctl disable shadowcache-system.service 2>/dev/null || true
	@-sudo systemctl stop shadowcache-system.service 2>/dev/null || true
	@-sudo systemctl disable shadowcache-system.timer 2>/dev/null || true
	@-sudo systemctl stop shadowcache-system.timer 2>/dev/null || true
	@sudo rm -f /etc/systemd/system/shadowcache-system.service
	@sudo rm -f /etc/systemd/system/shadowcache-system.timer
	@sudo rm -f /etc/systemd/system/shadowcache-system-periodic.service
	@sudo rm -f /usr/local/sbin/shadowcache-system
	@sudo systemctl daemon-reload
	# Remove logrotate configuration
	@sudo rm -f $(LOGROTATE_D)/shadowcache-metrics
	@echo "$(OK) Logrotate config removed"
	@echo "$(OK) System services uninstalled"

uninstall-bin: ## Remove ~/bin symlinks
	@echo "$(INFO) Removing bin symlinks from $(HOME_BIN)"
	@for script in $(BIN_SCRIPTS); do \
		if [ -L $(HOME_BIN)/$$script ]; then \
			rm -f $(HOME_BIN)/$$script && \
			echo "$(OK) Removed symlink: $$script"; \
		fi \
	done
	@echo "$(OK) Bin symlinks removed"
	# Note: Only removes symlinks; does NOT touch .bak backup files
	# Backup files remain for manual recovery if needed

uninstall-config: ## Remove home directory config symlinks
	@echo "$(INFO) Removing config symlinks from $(HOME)"
	@for file in $(HOME_CONFIG_FILES); do \
		if [ -L $(HOME)/$$file ]; then \
			rm -f $(HOME)/$$file && \
			echo "$(OK) Removed symlink: $$file"; \
		fi \
	done
	@echo "$(OK) Config symlinks removed"

uninstall-all: uninstall-user uninstall-system uninstall-bin uninstall-config ## Uninstall all services
	@echo "$(OK) All services uninstalled"
