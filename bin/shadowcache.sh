#!/bin/env bash

# Shadowcache - Synchronize cache between tmpfs and persistent storage
#
# When started, copy persistent data to the tmpfs-backed folder.
# When stopped, copy from tmpfs back to persistent storage.
#
# See: ~/src/shellbase/etc/systemd/system/README.md
#
# Usage:
#   shadowcache.sh load [--dry-run]     Load cache from persistent storage to tmpfs
#   shadowcache.sh save [--dry-run]     Save cache from tmpfs to persistent storage
#   shadowcache.sh status               Show system health and last sync info
#   shadowcache.sh validate             Verify all mounts and paths are ready

set -euo pipefail

# ============================================================================
# LESSONS LEARNED - Read this before modifying!
# ============================================================================
#
# This script uses `set -euo pipefail` for strict error handling. Be aware:
#
# 1. Arithmetic with set -e: `(( x++ ))` returns exit code 1 when x becomes 0
#    after the increment (post-increment returns the OLD value).
#    Solution: Always use `|| true` after arithmetic if the result might be 0.
#    Example: ((OPERATION_COUNT++)) || true
#
# 2. Command substitution with failing commands: Even with `|| true`, the exit
#    status of the command inside $() propagates. Ensure commands that may
#    fail are followed by `|| true` OUTSIDE the substitution.
#    Example: output=$(command_that_might_fail 2>&1) || true
#
# 3. Empty variables in arithmetic: If a variable is empty, arithmetic fails.
#    Solution: Use default values with ${var:-default}.
#    Example: ((TOTAL += ${value:-0})) || true
#
# 4. Rsync exit code 23 (partial transfer) is NOT an error for our use case.
#    Some directories may have permission issues but most files sync fine.
#    Solution: Use `|| true` after rsync command.
#
# 5. Systemd user services:
#    - User services go in /etc/systemd/user/ or ~/.config/systemd/user/
#    - System services go in /etc/systemd/system/
#    - User services CANNOT use User= directive (already run as user)
#    - User services CANNOT use local-fs.target dependency
#    - Template services require full instance name: shadowcache-user@ecc.service
#
# 6. Write permissions: User scope cannot write to $PERSISTENT root if owned by root.
#    Solution: State file for user scope goes in $PERSISTENT/${CACHE_USER}-cache/
#    System scope state file goes in $PERSISTENT root (requires root).
#
# 7. Rsync -h flag outputs human-readable (1.24G) which breaks numeric parsing.
#    Solution: Use --no-H or parse without -h flag for consistent numeric output.
#
# 8. PERSISTENT path has NO trailing slash: /volumes/APM-cache
#    This prevents double-slash (//) in path concatenation.
#    CRITICAL: Always add "/" after $PERSISTENT when concatenating:
#    - WRONG:  "${PERSISTENT}${CACHE_USER}-cache/"  → /volumes/APM-cacheecc-cache/
#    - RIGHT:  "${PERSISTENT}/${CACHE_USER}-cache/"  → /volumes/APM-cache/ecc-cache/
#
# 9. Systemd status detection: systemctl is-active exits non-zero for "failed" state.
#    Using $(cmd || echo "unknown") captures both "failed" AND "unknown" on separate lines.
#    Solution: Use `systemctl show --property=ActiveState --value` which always exits 0.
#
# 10. AWK portability: mawk (default on many systems) has limited function support.
#     Avoid defining functions inside awk scripts. Use inline code or variables instead.
#     Function syntax like `function fmt(x) { ... }` works in gawk but fails in mawk.
#
# 11. Metrics file paths are scope-aware for permissions:
#     - User scope:  $PERSISTENT/${CACHE_USER}-cache/.shadowcache-metrics.csv (user-writable)
#     - System scope: $PERSISTENT/.shadowcache-metrics.csv (root-only)
#     - XDG symlink:  ~/.local/state/shadowcache-metrics.csv → points to actual file
#     Always follow this pattern when adding new persistent state files.
#
# 12. Per-operation duration tracking for accurate metrics:
#     When measuring sync duration for multiple sequential operations (e.g., system-load
#     syncs both var-cache and var-tmp), NEVER use a global start time for all operations.
#     This causes cumulative timing where the second operation's duration includes the
#     first operation's time.
#     Solution: Capture start time inside each sync_* function using $(date +%s%3N)
#     and pass it to parse_rsync_stats as the 4th parameter.
#     Example: local op_start_ms=$(date +%s%3N) at function start, then:
#              parse_rsync_stats "$output" "$cache" "$op" "$op_start_ms"
#
# 13. OnUnitActiveSec timers and RemainAfterExit are INCOMPATIBLE:
#     OnUnitActiveSec=2h means "trigger 2 hours AFTER the service UNIT becomes active".
#     With RemainAfterExit=yes, the service stays active forever after first run.
#     The timer never sees the service transition from inactive→active again.
#     Solution: Use separate service units for timer-triggered operations:
#     - Main service (shadowcache-*.service): Has RemainAfterExit, used for boot/shutdown
#     - Periodic service (shadowcache-*-periodic@.service): No RemainAfterExit, for timers
#     - Timer explicitly specifies Unit=shadowcache-*-periodic.service
#     Example: [Timer] OnUnitActiveSec=2h Unit=shadowcache-user-periodic@%i.service
#
# 14. OnCalendar vs OnUnitActiveSec for periodic timers:
#     - OnCalendar: Absolute wall-clock time (cron-like)
#       - Good for: Fixed schedule, predictable next run time, better visibility
#       - Works with: RemainAfterExit services
#       - Next run: Always shown in "systemctl list-timers"
#       - Risk: Potential overlap if operation takes longer than interval
#     - OnUnitActiveSec: Relative to last service COMPLETION (deactivation→activation)
#       - Good for: Operations where duration varies, want guaranteed spacing
#       - Requires: Service without RemainAfterExit (must cycle inactive→active)
#       - Next run: Not shown in "systemctl list-timers" (shows n/a) until execution
#       - Risk: Timer gets stuck (NextElapseUSecMonotonic=infinity) if service never runs
#     For shadowcache: OnCalendar=*:00/2:00 (every 2 hours on the hour) is used because
#     saves are typically fast (<1 min), so overlap risk is minimal, and we get better
#     visibility into next scheduled run. The OnUnitActiveSec approach had a bug where
#     the timer would get stuck if the periodic service never ran successfully.
#
# 15. Scope-aware metrics display:
#     User and system caches write to SEPARATE metrics files (different permissions).
#     - User:  $PERSISTENT/${CACHE_USER}-cache/.shadowcache-metrics.csv (ecc-cache entries)
#     - System: $PERSISTENT/.shadowcache-metrics.csv (var-cache, var-tmp entries)
#     When displaying stats, NEVER assume both files exist or combine data from a single
#     file to show "user" and "system" sections. This causes identical values in both
#     sections when only one scope has data.
#     Solution: Use scope-specific commands (user-stats, system-stats) that read from
#     their respective files, or make the awk script DYNAMIC - iterate over whatever
#     cache names are present in the CSV rather than hardcoding ecc-cache/var-cache.
#     Pattern: for (cache in cache_total) { print cache ... }  # Shows what's there
#
# 16. Parsing OnCalendar timer schedules:
#     When displaying timer status from systemctl show, the TimersCalendar property
#     contains the OnCalendar schedule. Be careful with regex patterns containing special
#     characters like * and - which have meaning in regex.
#     WRONG: [[ $timer_info =~ OnCalendar=\*\-\*\-\* \*:00/([0-9]+):00 ]]  # Syntax error
#     RIGHT: [[ $timer_info =~ .*:00/([0-9]+):00 ]]  # Match the unique part
#     The .* pattern matches any characters (including * and -) safely, then we match
#     the distinctive ":00/N:00" pattern to extract the interval N. This is more portable
#     and avoids escaping issues with bash regex.
#
# ============================================================================

# ============================================================================
# CONFIGURATION
# ============================================================================
#
# Storage Architecture Overview
# -----------------------------
#
# PERSISTENT (/volumes/APM-cache/) is the parent of all persistent storage:
#
#   ecc-cache/      → rsync target for ~/.cache/ (hot data)
#   var-cache/      → rsync target for /var/cache/ (hot data)
#   var-tmp/        → rsync target for /var/tmp/ (hot data)
#   large-caches/   → bind mount backing for cold caches (NOT an rsync target)
#
# Key distinction:
#   - ecc-cache/, var-cache/, var-tmp/ are rsync targets (shadowcache reads/writes here)
#   - large-caches/ is bind mount backing (kernel mounts directly, no rsync)
#
# Hybrid Solution:
#   - Hot data (frequently accessed): stays in tmpfs, synced via rsync
#   - Cold data (rarely accessed): bind-mounted directly to SSD, excluded from rsync
#
# Bind Mounts (excluded from rsync sync):
#   ~/.cache/kopia            → /volumes/APM-cache/ecc-cache/kopia
#   ~/.cache/ms-playwright    → /volumes/APM-cache/large-caches/ms-playwright
#   ~/.cache/puppeteer        → /volumes/APM-cache/large-caches/puppeteer
#   ~/.cache/prisma-python    → /volumes/APM-cache/large-caches/prisma-python
#   ~/.cache/uv/archive-v0    → /volumes/APM-cache/large-caches/uv-archive-v0
#
# Why Bind Mounts Instead of Rsync?
# --------------------------------
# Bind mounts are used for specific data types that have different requirements:
#
# 1. Kopia (backup repository):
#    - Large deduplicated blob store (multi-GB)
#    - Rarely accessed during normal operations (scheduled backups only)
#    - Contains its own internal caching and integrity mechanisms
#    - Benefits from direct SSD access for backup/restore operations
#    - Would waste tmpfs space and slow down boot if synced via rsync
#
# 2. Test browser binaries (ms-playwright, puppeteer):
#    - Large archives (600MB+) only loaded during test runs
#    - Write-once, read-many access pattern (downloaded once, used many times)
#    - No benefit from RAM speed (browser startup is I/O bound anyway)
#    - Would consume 1.2GB of tmpfs space for infrequently used data
#
# 3. Build/package archives (prisma-python, uv/archive-v0):
#    - Wheel archives and build artifacts (write-once storage)
#    - Accessed only during package installation or builds
#    - No runtime performance benefit from being in RAM
#    - Archive format doesn't benefit from caching (sequential read pattern)
#
# Benefits of Bind Mounts:
# - Instant access (kernel-level mount, no sync delay)
# - No tmpfs space consumption (data stays on SSD)
# - No rsync overhead on boot/shutdown
# - Direct SSD I/O for large sequential reads (archives, backups)
#
# Hot Data (kept in rsync for RAM speed AND SSD endurance):
# - Package indexes (uv/simple-v18, wheels-v5) - frequent small lookups
# - Daily applications (thorium, JetBrains) - benefit from RAM speed
# - Build caches (node-gyp, pip, go-build) - frequent small file operations
# - Application state (gnome-software, mozilla) - high write frequency
#
# Critical: SSD Write Endurance
# -----------------------------
# WHY certain data stays in tmpfs (NOT on SSD):
# - High-frequency writes (build caches, app state, browser profiles)
# - Small random writes (worst case for SSD wear leveling)
# - Metadata-heavy operations (file creation, deletion, renames)
# - Temporary/runtime data that doesn't need persistence
#
# Modern SSDs have limited write cycles per cell:
# - Consumer NVMe SSD: ~600-3000 TBW (terabytes written)
# - Heavy write workloads can reduce lifespan significantly
# - Tmpfs absorbs write-intensive operations, extending SSD life
# - RAM is designed for essentially unlimited read/write cycles
#
# The hybrid solution optimizes BOTH:
# - Performance (hot data in RAM for speed)
# - SSD longevity (write-intensive data stays in RAM, offloaded to SSD only on shutdown)
#
# ============================================================================

# Use shellbase environment variables with fallbacks
# Preserve original user when running via sudo
if [[ -n ${SUDO_USER:-} ]]; then
    : "${SHELLBASE_USER:=$SUDO_USER}"
    : "${SHELLBASE_CACHE_DIR:=$(eval echo ~$SUDO_USER)/.cache}"
else
    : "${SHELLBASE_USER:=$(id -un)}"
    # Defensive: HOME may be unset in some systemd contexts
    : "${SHELLBASE_CACHE_DIR:=${HOME:-$(eval echo ~$(id -un))}/.cache}"
fi

# Shadowcache-specific configuration
PERSISTENT="${SHADOWCACHE_PERSISTENT:-/volumes/APM-cache}"
CACHE_USER="${SHELLBASE_USER}"

# Lock and state files - now parameterized by scope
# Scope can be "user" or "system" (set via SHADOWCACHE_SCOPE env var or command)
SHADOWCACHE_SCOPE="${SHADOWCACHE_SCOPE:-user}"
LOCKFILE="${SHADOWCACHE_LOCKFILE:-/run/lock/shadowcache-${SHADOWCACHE_SCOPE}.lock}"
# State file defaults - will be overridden by set_scope() for proper scoping
STATEFILE="${SHADOWCACHE_STATEFILE:-$PERSISTENT/${CACHE_USER}-cache/.shadowcache-user-state}"

# Lock stale thresholds (seconds)
# Boot mode: more aggressive cleanup (first 5 minutes after boot)
LOCK_STALE_BOOT_SECS="${SHADOWCACHE_LOCK_STALE_BOOT_SECS:-60}"
# Normal mode: conservative cleanup (5 minutes)
LOCK_STALE_NORMAL_SECS="${SHADOWCACHE_LOCK_STALE_NORMAL_SECS:-300}"

# Rsync options (base)
# Use --no-H for numeric byte counts (makes parsing easier)
RSYNC_BASE_OPTS="-a --delete --stats"

# Flags (set via argument parsing)
declare -g DRY_RUN=false
declare -g VERBOSE=false

# Global state for tracking sync operations
declare -g SYNC_START_TIME=""
declare -gi TOTAL_BYTES_TRANSFERRED=0
declare -gi OPERATION_COUNT=0

# Set scope and update lock/state file paths
# Args:
#   $1 - scope: Either "user" or "system"
set_scope() {
    local scope=$1
    SHADOWCACHE_SCOPE="$scope"
    LOCKFILE="/run/lock/shadowcache-${scope}.lock"

    # State file location depends on scope and user permissions
    if [[ $scope == "user" ]]; then
        # User scope: state file goes in user-writable cache directory
        STATEFILE="$PERSISTENT/${CACHE_USER}-cache/.shadowcache-user-state"
    else
        # System scope: state file goes in persistent storage root (requires root)
        STATEFILE="$PERSISTENT/.shadowcache-system-state"
    fi

    log_debug "Scope set to: $scope (lock: $LOCKFILE, state: $STATEFILE)"
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo "[+] $*" >&2
}

log_error() {
    echo "[!] $*" >&2
}

log_debug() {
    if [[ $VERBOSE == true ]]; then
        echo "[D] $*" >&2
    fi
}

log_warn() {
    echo "[W] $*" >&2
}

# Log a metric in key=value format
# Args:
#   $1 - metric: The metric name
#   $2 - value: The metric value
log_metric() {
    local metric=$1
    local value=$2
    echo "[M] ${metric}=${value}" >&2
}

# ============================================================================
# LOCK MANAGEMENT
# ============================================================================

# Helper function: Get system uptime in seconds
# Returns uptime in global variable _UPTIME_SECS, return code indicates success
get_uptime_secs() {
    local uptime_content

    if [[ -r /proc/uptime ]]; then
        uptime_content=$(cat /proc/uptime)
        _UPTIME_SECS=${uptime_content%%.*}
        return 0
    fi

    # Fallback: try using awk
    _UPTIME_SECS=$(awk '{print int($1)}' /proc/uptime 2>/dev/null) && return 0

    log_warn "Could not determine system uptime"
    return 1
}

acquire_lock() {
    local lock_pid lock_age now stale_threshold

    log_debug "Attempting to acquire lock: $LOCKFILE"

    # Create lockfile directory if it doesn't exist
    mkdir -p "$(dirname "$LOCKFILE")"

    # Use flock for exclusive lock (file descriptor 200)
    exec 200>"$LOCKFILE"

    # Try non-blocking acquire first (fast path for normal case)
    if flock -n 200; then
        echo $$ > "$LOCKFILE"
        log_debug "Lock acquired (PID: $$)"
        return 0
    fi

    # Lock is held - check if it's stale
    log_debug "Lock held, checking if stale..."

    if [[ ! -f $LOCKFILE ]]; then
        log_error "Cannot acquire lock (unknown reason)"
        exit 1
    fi

    # Read PID from lockfile
    lock_pid=$(cat "$LOCKFILE" 2>/dev/null || echo "")

    # Check if the PID is actually running
    if [[ -n $lock_pid ]] && kill -0 "$lock_pid" 2>/dev/null; then
        log_error "Lock held by active process: PID $lock_pid"
        log_error "If this is incorrect, remove the lock file manually:"
        log_error "  sudo rm -f $LOCKFILE"
        exit 1
    fi

    # PID is not running - check file age to determine staleness
    now=$(date +%s)
    lock_age=$((now - $(stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0)))

    # Determine stale threshold based on system uptime
    # Boot mode (< 5 min uptime): use aggressive threshold
    # Normal mode: use conservative threshold
    if get_uptime_secs; then
        if [[ $_UPTIME_SECS -lt 300 ]]; then
            stale_threshold=$LOCK_STALE_BOOT_SECS
            log_debug "Boot mode detected (uptime: ${_UPTIME_SECS}s), using aggressive threshold: ${stale_threshold}s"
        else
            stale_threshold=$LOCK_STALE_NORMAL_SECS
            log_debug "Normal mode (uptime: ${_UPTIME_SECS}s), using conservative threshold: ${stale_threshold}s"
        fi
    else
        # Fallback if uptime check fails
        stale_threshold=$LOCK_STALE_NORMAL_SECS
        log_debug "Could not determine uptime, using default threshold: ${stale_threshold}s"
    fi

    # Remove stale lockfile and retry
    if [[ $lock_age -ge $stale_threshold ]]; then
        if [[ -n $lock_pid ]]; then
            log_warn "Removing stale lockfile (PID $lock_pid not running, age: ${lock_age}s)"
        else
            log_warn "Removing stale lockfile (no valid PID, age: ${lock_age}s)"
        fi
        rm -f "$LOCKFILE"

        # Retry acquisition
        if flock -n 200; then
            echo $$ > "$LOCKFILE"
            log_debug "Lock acquired after cleanup (PID: $$)"
            return 0
        fi

        log_error "Failed to acquire lock even after cleanup (race condition?)"
        exit 1
    fi

    # Lock is not stale enough
    log_error "Lock file is recent (${lock_age}s old, threshold: ${stale_threshold}s)"
    log_error "Another shadowcache operation may be running, or wait for it to complete."
    exit 1
}

release_lock() {
    log_debug "Releasing lock"
    flock -u 200 2>/dev/null || true
    rm -f "$LOCKFILE" 2>/dev/null || true
}

# ============================================================================
# STATE TRACKING
# ============================================================================

load_state() {
    if [[ -f $STATEFILE ]]; then
        # shellcheck source=/dev/null
        source "$STATEFILE"
        log_debug "Loaded state from: $STATEFILE"
    else
        log_debug "No state file found (first run?)"
    fi
}

# Save shadowcache state to file
# Args:
#   $1 - operation: The operation performed (load|save)
#   $2 - status: The operation status (default: success)
#   $3 - bytes: Bytes transferred (default: 0)
save_state() {
    local operation=$1
    local status=${2:-success}
    local bytes=${3:-0}

    cat > "$STATEFILE" <<EOF
# Shadowcache state file - Generated $(date -Iseconds)
LAST_SYNC="$(date -Iseconds)"
LAST_OPERATION="$operation"
LAST_STATUS="$status"
LAST_BYTES="$bytes"
LAST_PID="$$"
EOF

    log_debug "State saved: ${operation}=${status}"
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_persistent_mount() {
    log_debug "Checking persistent mount: $PERSISTENT"

    if [[ ! -d $PERSISTENT ]]; then
        log_error "Persistent storage path does not exist: $PERSISTENT"
        return 1
    fi

    # Check if it's actually mounted (not just a directory)
    if ! mountpoint -q "$PERSISTENT"; then
        log_error "Persistent storage is not mounted: $PERSISTENT"
        log_error "Mount it first with: sudo mount $PERSISTENT"
        return 1
    fi

    # Check write access to the appropriate location based on scope
    local test_dir
    if [[ $SHADOWCACHE_SCOPE == "user" ]]; then
        # User scope: check write to user's cache directory
        test_dir="$PERSISTENT/${CACHE_USER}-cache"
    else
        # System scope: check write to persistent root
        test_dir="$PERSISTENT"
    fi

    if [[ ! -d $test_dir ]]; then
        log_error "Target directory does not exist: $test_dir"
        return 1
    fi

    local test_file="$test_dir/.shadowcache-write-test-$$"
    if ! touch "$test_file" 2>/dev/null; then
        log_error "Cannot write to persistent storage: $test_dir"
        rm -f "$test_file"
        return 1
    fi
    rm -f "$test_file"

    log_debug "Persistent mount OK (writable: $test_dir)"
    return 0
}

check_rsync_available() {
    if ! command -v rsync >/dev/null 2>&1; then
        log_error "rsync not found. Install with: sudo apt install rsync"
        return 1
    fi
    log_debug "rsync available: $(rsync --version | head -1)"
    return 0
}

# Check bind mounts for hybrid shadowcache setup
# Validates that cold cache directories are properly bind-mounted to SSD
check_bind_mounts() {
    local all_ok=true

    # Expected bind mounts for hybrid solution
    # Format: "cache_dir:expected_backing_path"
    local expected_mounts=(
        "kopia:${PERSISTENT}/ecc-cache/kopia"
        "ms-playwright:${PERSISTENT}/large-caches/ms-playwright"
        "puppeteer:${PERSISTENT}/large-caches/puppeteer"
        "prisma-python:${PERSISTENT}/large-caches/prisma-python"
        "uv/archive-v0:${PERSISTENT}/large-caches/uv-archive-v0"
    )

    log_debug "Checking hybrid bind mounts..."

    for mount_spec in "${expected_mounts[@]}"; do
        local cache_dir="${mount_spec%%:*}"
        local backing_path="${mount_spec##*:}"
        local full_cache_path="${SHELLBASE_CACHE_DIR}/${cache_dir}"

        # Skip validation if the cache directory doesn't exist yet
        # (this is normal before first use or after clean install)
        if [[ ! -d "$full_cache_path" ]]; then
            log_debug "  Cache dir not found (skipping): ${cache_dir}"
            continue
        fi

        # Check if it's a mount point
        if ! mountpoint -q "$full_cache_path"; then
            log_warn "  Not bind-mounted: ${cache_dir}"
            log_warn "    Expected: ${backing_path}"
            log_warn "    This will cause shadowcache to sync it (may exceed tmpfs)"
            # Don't fail validation, just warn - allow graceful degradation
            continue
        fi

        # Verify the mount points to the expected backing path
        local actual_mount
        actual_mount=$(findmnt -n -o TARGET,SOURCE "$full_cache_path" 2>/dev/null | awk '{print $2}')

        if [[ -z "$actual_mount" ]]; then
            log_warn "  Could not verify mount target: ${cache_dir}"
            continue
        fi

        # Check ownership - should be owned by the user, not root
        local actual_owner actual_group
        actual_owner=$(stat -c "%U" "$full_cache_path" 2>/dev/null)
        actual_group=$(stat -c "%G" "$full_cache_path" 2>/dev/null)

        if [[ "$actual_owner" == "root" ]]; then
            log_error "  ✗ Wrong ownership: ${cache_dir}"
            log_error "    Current: ${actual_owner}:${actual_group}"
            log_error "    Expected: ${SHELLBASE_USER}:${SHELLBASE_USER}"
            log_error "    Fix: sudo chown -R ${SHELLBASE_USER}:${SHELLBASE_USER} ${backing_path}"
            all_ok=false
        else
            log_debug "  ✓ Bind-mounted: ${cache_dir} -> ${backing_path} (${actual_owner}:${actual_group})"
        fi
    done

    [[ $all_ok == true ]]
}

# ============================================================================
# SYNC OPERATIONS
# ============================================================================

# Execute rsync command with global options and optional excludes
# Args:
#   $1 - src: Source path (with trailing slash for directory contents)
#   $2 - dst: Destination path
#   $3 - extra_excludes: Additional rsync --exclude patterns (optional)
# Returns: 0 on success, updates global TOTAL_BYTES_TRANSFERRED with bytes transferred
run_rsync() {
    local src=$1
    local dst=$2
    local extra_excludes=${3:-}
    local rsync_cmd
    local rsync_output
    local transferred_bytes
    local files_log

    # Determine file log location based on scope (lesson #11: scope-aware paths)
    if [[ $SHADOWCACHE_SCOPE == "user" ]]; then
        files_log="$PERSISTENT/${CACHE_USER}-cache/.shadowcache-files.log"
    else
        files_log="$PERSISTENT/.shadowcache-files.log"
    fi

    # Build rsync command
    rsync_cmd="rsync $RSYNC_BASE_OPTS"

    if [[ $DRY_RUN == true ]]; then
        rsync_cmd="$rsync_cmd --dry-run"
        log_info "[DRY-RUN] Would sync: $src -> $dst"
    else
        log_debug "Syncing: $src -> $dst"
        # Add itemize changes to capture file list for last operation
        rsync_cmd="$rsync_cmd --itemize-changes --log-file=$files_log"
        # Clear previous log for fresh capture of this operation
        : > "$files_log"
    fi

    # Add excludes and run, capturing output for stats parsing
    # shellcheck disable=SC2086
    # Note: rsync exit code 23 (partial transfer) is acceptable - some files may be unreadable
    rsync_output=$(eval $rsync_cmd $extra_excludes "$src" "$dst" 2>&1) || true

    # Parse bytes transferred from rsync --stats output
    # Format: "Total transferred file size: X bytes" or "1.24G bytes"
    transferred_bytes=$(echo "$rsync_output" | grep -oP 'Total transferred file size: \K[0-9,]+' | tr -d ',' || echo "0")
    # Ensure transferred_bytes is never empty (set -e would cause exit)
    transferred_bytes=${transferred_bytes:-0}
    ((TOTAL_BYTES_TRANSFERRED += transferred_bytes)) || true

    # Track operation count
    ((OPERATION_COUNT++)) || true

    # Log stats if verbose
    if [[ $VERBOSE == true && $transferred_bytes -gt 0 ]]; then
        log_metric "bytes_transferred" "$transferred_bytes"
    fi

    # Return output for metrics parsing
    echo "$rsync_output"
    return 0
}

# ============================================================================
# METRICS COLLECTION
# ============================================================================

# Parse rsync --stats output into structured metrics
# Args:
#   $1 - rsync_output: The captured rsync output
#   $2 - cache_name: Identifier for the cache (ecc-cache, var-cache, var-tmp)
#   $3 - operation: load or save
#   $4 - op_start_ms: Optional start time in milliseconds since epoch (for accurate per-operation duration)
# Returns: 0, writes metrics to log file
parse_rsync_stats() {
    local rsync_output="$1"
    local cache_name="$2"
    local operation="$3"
    local op_start_ms="${4:-0}"
    local timestamp=$(date -Iseconds)

    # Parse key metrics from rsync --stats
    local total_size=$(echo "$rsync_output" | grep -oP 'Total transferred file size: \K[0-9,]+' | tr -d ',' || echo "0")
    local literal_data=$(echo "$rsync_output" | grep -oP 'Literal data: \K[0-9,]+' | tr -d ',' || echo "0")
    local matched_data=$(echo "$rsync_output" | grep -oP 'Matched data: \K[0-9,]+' | tr -d ',' || echo "0")
    local file_list=$(echo "$rsync_output" | grep -oP 'File list size: \K[0-9,]+' | tr -d ',' || echo "0")
    local file_count=$(echo "$rsync_output" | grep -oP 'Number of regular files transferred: \K[0-9]+' || echo "0")

    # Ensure variables are never empty (set -e would cause exit)
    total_size=${total_size:-0}
    literal_data=${literal_data:-0}
    matched_data=${matched_data:-0}
    file_list=${file_list:-0}
    file_count=${file_count:-0}

    # Estimate SSD writes: literal data * compression factor
    # BTRFS zstd:5 typically achieves ~85% ratio
    local estimated_ssd_writes=$((literal_data * 85 / 100))

    # Calculate duration from passed start time (preferred) or global SYNC_START_TIME (fallback)
    local duration_ms=0
    if [[ $op_start_ms -gt 0 ]]; then
        # Use per-operation start time for accurate duration
        local end_time=$(date +%s%3N)
        duration_ms=$((end_time - op_start_ms))
    elif [[ -n ${SYNC_START_TIME:-} ]]; then
        # Fallback to global start time (may be cumulative for multi-sync operations)
        local end_time=$(date +%s%3N)
        local start_ms=$(($SYNC_START_TIME * 1000))
        duration_ms=$((end_time - start_ms))
    fi

    # Write to metrics log (only if not dry-run and actually transferred data)
    if [[ $DRY_RUN == false && $literal_data -gt 0 ]]; then
        local metrics_log
        local xdg_symlink="${XDG_STATE_HOME:-$HOME/.local/state}/shadowcache-metrics.csv"

        if [[ $SHADOWCACHE_SCOPE == "user" ]]; then
            # User scope: metrics in user's cache directory (persistent storage)
            metrics_log="$PERSISTENT/${CACHE_USER}-cache/.shadowcache-metrics.csv"

            # Ensure XDG-compliant symlink exists
            local xdg_dir="${XDG_STATE_HOME:-$HOME/.local/state}"
            if [[ ! -e "$xdg_symlink" ]]; then
                mkdir -p "$xdg_dir"
                ln -sf "$metrics_log" "$xdg_symlink"
            fi
        else
            # System scope: metrics in persistent root (requires root)
            metrics_log="$PERSISTENT/.shadowcache-metrics.csv"
        fi

        # Create CSV with header if it doesn't exist
        if [[ ! -f $metrics_log ]]; then
            echo "timestamp,cache_name,operation,total_bytes,literal_bytes,matched_bytes,file_count,duration_ms" > "$metrics_log"
        fi
        echo "$timestamp,$cache_name,$operation,$total_size,$literal_data,$matched_data,$file_count,$duration_ms" >> "$metrics_log"
    fi

    log_debug "Metrics: $cache_name=$estimated_ssd_writes bytes (85% CI: ±5%)"
    return 0
}

# Run rsync to sync user cache directory
#
# IMPORTANT: Understanding the "direction" parameter
# -----------------------------------------------
# The "direction" parameter is ONLY a semantic label for logging/metrics.
# ACTUAL sync direction is determined SOLELY by the order of src/dst arguments.
#
# This design allows the same function to handle both load and save operations
# while maintaining clear semantic meaning in logs and metrics.
#
# Directions:
#   "load" - Persistent storage (SSD) → Runtime location (RAM/root SSD)
#            Used on boot to restore data from persistent storage
#   "save" - Runtime location (RAM/root SSD) → Persistent storage (SSD)
#            Used on shutdown/periodically to protect data from RAM loss
#
# Args:
#   $1 - direction: "load" or "save" - used ONLY for log output and metrics
#   $2 - src: Source directory path (rsync reads FROM here)
#   $3 - dst: Destination directory path (rsync writes TO here)
#
# LESSON: Don't rely on the direction parameter for logic - always use src/dst order.
# The direction string is purely for human-readable logs and metrics categorization.
#
sync_user_cache() {
    local direction=$1
    local src=$2
    local dst=$3
    local rsync_output
    local op_start_ms=$(date +%s%3N)

    log_info "Syncing user cache (${direction})..."
    # Exclude bind-mounted cold caches (hybrid solution)
    # kopia is already bind-mounted separately
    rsync_output=$(run_rsync "$src" "$dst" "--exclude kopia --exclude ms-playwright --exclude puppeteer --exclude prisma-python --exclude 'uv/archive-v0'")

    # Parse and log metrics
    parse_rsync_stats "$rsync_output" "ecc-cache" "$direction" "$op_start_ms"

    # Sync ONLY Thorium config from ~/.config - for write tracking
    # All other ~/.config directories remain UNSYNCED (stay on root SSD)
    #
    # NOTE: ~/.config is NOT on tmpfs - it lives on root SSD at /home/ecc/.config/
    # Only ~/.cache is on tmpfs (RAM). This sync moves Thorium config from
    # root SSD to RAID0 SSD for write tracking and backup protection.
    #
    op_start_ms=$(date +%s%3N)
    log_info "Syncing Thorium config (${direction})..."

    # Ensure config persistent directory exists
    if [[ ! -d "$PERSISTENT/${CACHE_USER}-config" ]]; then
        mkdir -p "$PERSISTENT/${CACHE_USER}-config"
    fi

    # LESSON: Direction-based path swapping
    # ------------------------------------
    # For config sync, we need to swap src/dst based on direction because
    # the caller passes cache paths, not config paths. We construct the
    # actual config paths here based on the semantic direction.
    #
    # load: SSD (persistent) → root SSD (runtime)
    # save: root SSD (runtime) → SSD (persistent)
    #
    local config_src config_dst
    if [[ $direction == "load" ]]; then
        config_src="$PERSISTENT/${CACHE_USER}-config/thorium/"
        config_dst="$HOME/.config/thorium/"
    else
        config_src="$HOME/.config/thorium/"
        config_dst="$PERSISTENT/${CACHE_USER}-config/thorium/"
    fi

    # Only sync if Thorium config directory exists
    if [[ -d "$HOME/.config/thorium" ]]; then
        # Sync Thorium config, excluding write-heavy components
        #
        # CRITICAL: SSD Endurance Protection
        # ----------------------------------
        # These exclusions protect SSD endurance by keeping high-write data in RAM.
        # The excluded directories cause EXCESSIVE SSD wear through:
        #   - Continuous small random writes (worst case for SSD wear leveling)
        #   - High-frequency metadata updates (file creation, deletion, renames)
        #   - Write amplification from journaling/LSM trees (LevelDB, IndexedDB)
        #
        # Browser data characteristics:
        #   - IndexedDB:      1.1GB - LevelDB LSM tree, continuous compaction writes
        #   - Service Worker: 2.6GB - Cache storage, frequent incremental updates
        #   - WebStorage:     493MB - localStorage writes on every page interaction
        #   - GPUCache:       12MB  - Shader cache, regenerated on demand
        #
        # WHY EXCLUDE THESE:
        #   1. They're TEMPORARY/CACHABLE - browser regenerates them as needed
        #   2. They're HIGH-FREQUENCY WRITE - kills SSD through write amplification
        #   3. They're NOT USER DATA - bookmarks, cookies, history are synced instead
        #   4. They're VOLATILE - no loss if system crashes (browser recreates them)
        #
        # WHAT GETS SYNCED (the important stuff):
        #   - Preferences, Cookies, History       - User data, low write frequency
        #   - Bookmarks, Sessions, Extensions      - User configuration
        #   - Login Data, Certificate store       - Authentication data
        #
        # EXCLUSION LIST (write-heavy browser internals):
        #   --exclude '*/IndexedDB'          - LevelDB database (LSM tree, heavy writes)
        #   --exclude '*/WebStorage'         - localStorage (immediate writes on changes)
        #   --exclude '*/GPUCache'           - Compiled shaders (regeneratable)
        #   --exclude '*/Code Cache'         - JIT-compiled JavaScript (regeneratable)
        #   --exclude '*/ShaderCache'        - GPU shader cache (regeneratable)
        #   --exclude '*/DawnWebGPUCache'    - WebGPU shader cache (regeneratable)
        #   --exclude '*/DawnGraphiteCache'  - WebGPU compute cache (regeneratable)
        #   --exclude '*/Service Worker'     - Service worker cache storage
        #   --exclude '*/BudgetEstimates'    - Performance budget tracking (volatile)
        #   --exclude '*/Blob Storage'       - Large binary blobs (usually cache)
        #   --exclude '*/Cache'              - General HTTP cache
        #   --exclude '*/Application Cache'  - Deprecated app cache API
        #   --exclude '*/Media Cache'        - Media streaming cache
        #
        # DESIGN PHILOSOPHY:
        #   - Keep HIGH-WRITE data in RAM (tmpfs) - protects SSD, extends lifespan
        # Sync entire Thorium profile to tmpfs (no exclusions needed)
        # All data is in RAM - no SSD wear concern, complete crash protection
        #
        # HISTORICAL EXCLUSIONS (removed when moving to tmpfs):
        # These were excluded when ~/.config/thorium lived on root SSD to prevent SSD wear.
        # With tmpfs, all data is in RAM, so exclusions are no longer needed.
        #
        # --exclude '*/IndexedDB'          - LevelDB LSM-tree database (1.1GB). Continuous compaction writes cause SSD write amplification.
        # --exclude '*/WebStorage'         - localStorage API storage (496MB). Synchronous writes on every page interaction.
        # --exclude '*/Service Worker'     - Progressive Web App offline cache (2.6GB). Frequent incremental updates as resources change.
        # --exclude '*/GPUCache'           - Compiled GPU shaders (12MB). Regenerated on demand by browser/driver.
        # --exclude '*/Code Cache'         - JIT-compiled JavaScript (~50MB). Regenerated by V8 engine on script execution.
        # --exclude '*/ShaderCache'        - WebGL shader cache. Regenerated when GPU programs are compiled.
        # --exclude '*/DawnWebGPUCache'    - WebGPU shader cache. Regenerated for WebGPU applications.
        # --exclude '*/DawnGraphiteCache'  - WebGPU compute cache. Regenerated for compute shaders.
        # --exclude '*/BudgetEstimates'    - Performance budget tracking (volatile). Rebuilt by browser performance APIs.
        # --exclude '*/Blob Storage'       - Large binary blob storage (usually cache). Rebuilt by web applications.
        # --exclude '*/Cache'              - General HTTP cache. Rebuilt as resources are fetched.
        # --exclude '*/Application Cache'  - Deprecated Application Cache API. Legacy PWA storage.
        # --exclude '*/Media Cache'        - Media streaming cache. Rebuilt as audio/video is played.
        #
        # REFERENCE: If storing browser data on SSD again, consider re-adding these exclusions
        # to protect SSD endurance. The write-heavy components above can generate 10-30x
        # write amplification through LSM-tree compaction (IndexedDB) and synchronous writes (WebStorage).
        #
        rsync_output=$(run_rsync "$config_src" "$config_dst" "")

        # Parse and log metrics with separate cache name for filtering
        parse_rsync_stats "$rsync_output" "ecc-config" "$direction" "$op_start_ms"
    else
        log_debug "Thorium config directory not found, skipping config sync"
    fi
}

# Run rsync to sync /var/cache directory
# Args:
#   $1 - direction: "load" (SSD→tmpfs) or "save" (tmpfs→SSD) - used for logging only
#   $2 - src: Source directory path
#   $3 - dst: Destination directory path
#   $4 - extra_excludes: Additional rsync exclude patterns (optional)
# Note: The direction parameter is only for log output; actual sync direction is determined by src/dst order
sync_var_cache() {
    local direction=$1
    local src=$2
    local dst=$3
    local extra_excludes=${4:-}
    local rsync_output
    local op_start_ms=$(date +%s%3N)

    log_info "Syncing /var/cache (${direction})..."
    rsync_output=$(run_rsync "$src" "$dst" "$extra_excludes")

    # Parse and log metrics
    parse_rsync_stats "$rsync_output" "var-cache" "$direction" "$op_start_ms"
}

# Run rsync to sync /var/tmp directory
# Args:
#   $1 - direction: "load" (SSD→tmpfs) or "save" (tmpfs→SSD) - used for logging only
#   $2 - src: Source directory path
#   $3 - dst: Destination directory path
# Note: The direction parameter is only for log output; actual sync direction is determined by src/dst order
sync_var_tmp() {
    local direction=$1
    local src=$2
    local dst=$3
    local rsync_output
    local op_start_ms=$(date +%s%3N)

    log_info "Syncing /var/tmp (${direction})..."
    rsync_output=$(run_rsync "$src" "$dst" "--exclude 'flatpak-cache-*' --exclude 'systemd-private-*'")

    # Parse and log metrics
    parse_rsync_stats "$rsync_output" "var-tmp" "$direction" "$op_start_ms"
}

# ============================================================================
# FILE TRANSFER DISPLAY
# ============================================================================

# Show categorized file list from last save operation
# Parses rsync --itemize-changes log and groups files by: NEW, MOD, DEL
# Args:
#   $1 - scope: "user" or "system"
show_files_transferred() {
    local scope=$1
    local files_log

    if [[ $scope == "user" ]]; then
        files_log="$PERSISTENT/${CACHE_USER}-cache/.shadowcache-files.log"
    else
        files_log="$PERSISTENT/.shadowcache-files.log"
    fi

    if [[ ! -f $files_log ]]; then
        log_error "No file transfer log found for $scope scope"
        log_error "Run ${scope}-save first to generate the log."
        return 1
    fi

    log_info "Files transferred (last $scope save):"
    echo ""

    # Parse rsync itemize log and categorize
    # Rsync itemize format: 11-character code + filename
    # Key prefixes:
    #   *deleting      - file deleted on sender
    #   >f+++++++++    - new file created (starts with >, contains +)
    #   .f..t......    - existing file modified (starts with ., has t)
    # LESSON: Use index() for string matching (not regex) to avoid escaping
    # awk patterns /^*deleting/ fail because * is a regex quantifier (zero-or-more)
    # index($0, "*deleting") does literal substring search - no escaping needed
    awk '
    BEGIN { created=0; updated=0; deleted=0; other=0 }
    index($0, "*deleting") {
        deleted++
        print "[DEL] " substr($0, 10)
        next
    }
    /^>/ {
        # Check if this is a new file (contains + in the change indicators)
        if (index($0, "+") > 0) {
            created++
            print "[NEW] " substr($0, 12)
            next
        }
    }
    /^f/ {
        # Modified file (starts with f, not a deletion)
        updated++
        print "[MOD] " substr($0, 12)
        next
    }
    /.*/ {
        # Any other line with content
        if (NF > 1) {
            other++
            # Extract filename (skip first 11 chars for itemize code)
            if (length($0) > 12) {
                print "[?]  " substr($0, 12)
            }
        }
    }
    END {
        print ""
        print "Summary: " created " created, " updated " updated, " deleted " deleted"
        if (other > 0) {
            print "         " other " other"
        }
    }
    ' "$files_log"
}

# ============================================================================
# STATUS HELPER FUNCTIONS
# ============================================================================

# Show systemd service and timer status
# Args:
#   $1 - service_name: The systemd service name (e.g., shadowcache-user@ecc.service)
#   $2 - timer_name: The systemd timer name (e.g., shadowcache-user@ecc.timer)
#   $3 - is_user: "true" for user service, "false" for system service
#
# LESSONS LEARNED - Systemd Timer Status Display Pitfalls:
# ===========================================================
# 1. Unbound Variable Error:
#    - next_trigger must be initialized in ALL code paths before use
#    - Bug: next_trigger was only set in OnCalendar branches, not monotonic fallback
#    - Fix: Initialize next_trigger="" in the else branch (monotonic timers have no next elapse)
#
# 2. Conditional Display Logic Bug:
#    - Original: Wrapped "Next:" display inside "if last_trigger exists" block
#    - Problem: Newly restarted timers have empty last_trigger, so "Next:" was hidden
#    - Fix: Separate the conditions - show "Last:" if available, show "Next:" independently
#
# 3. Multiple OnCalendar Parsing:
#    - TimersCalendar output format: "{ OnCalendar=*-*-* HH:MM:SS ; ... }\n{ ... }"
#    - Extract times with grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' and sort for clean display
#    - Remove :00 seconds with sed for cleaner output
#
# 4. systemd-analyze calendar Validation:
#    - ALWAYS validate OnCalendar syntax before using: systemd-analyze calendar "*-*-* HH:MM:SS"
#    - Comma-separated times in single OnCalendar= line FAIL when wrapping midnight
#    - Use separate OnCalendar= lines for each time instead
show_systemd_status() {
    local service_name=$1
    local timer_name=$2
    local is_user=$3

    local systemctl_cmd="systemctl"
    if [[ $is_user == "true" ]]; then
        systemctl_cmd="systemctl --user"
    fi

    echo "  Systemd:"
    # Check service status using systemctl show (always exits 0, outputs actual state)
    local service_active
    service_active=$($systemctl_cmd show "$service_name" --property=ActiveState --value 2>/dev/null || echo "unknown")
    echo "    Service: $service_active"

    # Check timer status and interval
    # LESSON: Declare all local variables upfront to avoid unbound variable errors
    local timer_active timer_interval timer_info last_trigger next_trigger oncalendar_times
    timer_active=$($systemctl_cmd is-active "$timer_name" 2>/dev/null) || timer_active="inactive"

    # Get timer interval - try OnCalendar first, then fallback to monotonic timers
    timer_info=$($systemctl_cmd show "$timer_name" --property=TimersCalendar --value 2>/dev/null)

    # Check for hourly OnCalendar pattern: *-*-* *:00/N:00 (every N hours)
    if [[ $timer_info =~ .*:00/([0-9]+):00 ]]; then
        # OnCalendar format: *-*-* *:00/2:00 = every 2 hours
        timer_interval="${BASH_REMATCH[1]}h"
        # Get next trigger time from NextElapseUSecRealtime
        next_trigger=$($systemctl_cmd show "$timer_name" --property=NextElapseUSecRealtime --value 2>/dev/null || echo "")
    elif [[ $timer_info =~ OnCalendar ]]; then
        # Generic OnCalendar format - extract all times for display
        # LESSON: Multiple OnCalendar entries appear as separate { } blocks in TimersCalendar
        # Extract HH:MM:SS patterns and deduplicate with sort -u
        oncalendar_times=$(grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' <<< "$timer_info" | sed 's/:00$//g' | sort -u | tr '\n' ' ' | sed 's/ $//')
        if [[ -n "$oncalendar_times" ]]; then
            timer_interval="$oncalendar_times"
        else
            timer_interval="OnCalendar"
        fi
        next_trigger=$($systemctl_cmd show "$timer_name" --property=NextElapseUSecRealtime --value 2>/dev/null || echo "")
    else
        # Fallback to monotonic timers (OnUnitActiveSec, OnBootSec)
        timer_info=$($systemctl_cmd show "$timer_name" --property=TimersMonotonic --value 2>/dev/null)
        if [[ $timer_info =~ OnUnitActiveUSec=([0-9]+[a-z]+) ]]; then
            timer_interval="${BASH_REMATCH[1]}"
        elif [[ $timer_info =~ OnBootUSec=([0-9]+[a-z]+) ]]; then
            timer_interval="${BASH_REMATCH[1]}"
        fi
        # LESSON: Monotonic timers don't have NextElapseUSecRealtime - must initialize to empty
        # Without this, referencing next_trigger later causes "unbound variable" error
        next_trigger=""
    fi

    # Get last trigger time for calculating next execution
    # LESSON: LastTriggerUSec is empty for newly restarted timers - handle gracefully
    last_trigger=$($systemctl_cmd show "$timer_name" --property=LastTriggerUSec --value 2>/dev/null || echo "")

    if [[ $timer_active == "active" && -n "$timer_interval" ]]; then
        echo "    Timer: $timer_active (every: $timer_interval)"
        # Show last trigger if available
        if [[ -n "$last_trigger" && "$last_trigger" != "n/a" ]]; then
            # Parse the last trigger time and format it nicely
            # Format: "Sat 2026-01-31 22:37:34 -03"
            local last_trigger_short
            last_trigger_short=$(echo "$last_trigger" | sed 's/ [A-Z][a-z][a-z] //' | cut -d' ' -f1-3)
            echo "      Last: $last_trigger_short"
        fi
        # Show next execution if available (OnCalendar) or relative (monotonic)
        if [[ -n "$next_trigger" && "$next_trigger" != "n/a" ]]; then
            local next_short
            next_short=$(echo "$next_trigger" | sed 's/ [A-Z][a-z][a-z] //' | cut -d' ' -f1-3)
            echo "      Next: $next_short"
        elif [[ -n "$last_trigger" && "$last_trigger" != "n/a" ]]; then
            # Only show relative next if we have a last trigger
            echo "      Next: ~$timer_interval from last"
        fi
    elif [[ $timer_active == "inactive" && -n "$timer_interval" ]]; then
        echo "    Timer: $timer_active (every: $timer_interval)"
    elif [[ $timer_active == "inactive" ]]; then
        echo "    Timer: $timer_active"
    else
        echo "    Timer: $timer_active"
    fi
}

# Show journald logs for a shadowcache service
# Args:
#   $1 - scope: "user" or "system"
#   $2 - service_name: Full systemd service name
#   $3 - is_user: "true" for user scope, "false" for system scope
#   $4..N - journalctl options (e.g., --since, --lines, -f, --no-pager)
show_logs() {
    local scope=$1
    local service_name=$2
    local is_user=$3
    shift 3

    local journalctl_cmd="journalctl"
    if [[ $is_user == "true" ]]; then
        journalctl_cmd="journalctl --user"
    fi

    $journalctl_cmd -u "$service_name" "$@"
}

show_user_status() {
    echo "User Cache (tmpfs): ${SHELLBASE_CACHE_DIR}"

    if [[ -f $STATEFILE ]]; then
        # shellcheck source=/dev/null
        source "$STATEFILE"
        echo "  Last Sync: ${LAST_SYNC:-unknown}"
        echo "  Operation: ${LAST_OPERATION:-unknown}"
    fi

    if mountpoint -q "$SHELLBASE_CACHE_DIR"; then
        df -h "$SHELLBASE_CACHE_DIR" 2>/dev/null | tail -1 | awk '{printf "  Used: %s/%s (%s) [RAM]\n", $3, $2, $5}'
    else
        # Not mounted or not tmpfs - just show path
        echo "  (not available)"
    fi

    # Show config persistent storage status (NEW for Thorium write tracking)
    echo ""
    echo "User Config: $HOME/.config"
    if [[ -d "$PERSISTENT/${CACHE_USER}-config" ]]; then
        local config_size
        config_size=$(du -sh "$PERSISTENT/${CACHE_USER}-config" 2>/dev/null | awk '{print $1}')
        echo "  Persistent: $config_size [SSD]"
    fi

    # Show important bind-mounted caches (on SSD, not in tmpfs)
    # These are excluded from rsync but still appear in ~/.cache
    local bind_mounts=(
        "kopia:Kopia backup repository"
        "ms-playwright:Playwright test browsers"
        "puppeteer:Puppeteer test browsers"
        "prisma-python:Prisma Python binaries"
        "uv/archive-v0:UV wheel archives"
    )

    local first_bind=true
    for mount_spec in "${bind_mounts[@]}"; do
        local cache_dir="${mount_spec%%:*}"
        local description="${mount_spec#*:}"
        local cache_path="${SHELLBASE_CACHE_DIR}/${cache_dir}"

        if [[ -d "$cache_path" ]]; then
            # Check if it's a bind mount
            if findmnt -n "$cache_path" >/dev/null 2>&1; then
                local size
                size=$(du -sh "$cache_path" 2>/dev/null | awk '{print $1}')
                if [[ $first_bind == true ]]; then
                    echo "  Bind mounts (SSD):"
                    first_bind=false
                fi

                # Special handling for kopia to show its breakdown
                if [[ "$cache_dir" == "kopia" ]]; then
                    # Get sizes of kopia components
                    local cli_logs_size content_logs_size repo_data_size repo_dir
                    cli_logs_size=""
                    content_logs_size=""
                    repo_data_size=""
                    repo_dir=""

                    # Get individual component sizes from the mounted path
                    cli_logs_size=$(du -sh "${cache_path}/cli-logs" 2>/dev/null | awk '{print $1}')
                    content_logs_size=$(du -sh "${cache_path}/content-logs" 2>/dev/null | awk '{print $1}')

                    # Find the repository data directory (looks like a hash)
                    # Exclude known directories (cli-logs, content-logs, ., ..)
                    for d in "$cache_path"/*/; do
                        local dirname
                        dirname=$(basename "$d")
                        # Skip known tmpfs directories
                        if [[ "$dirname" == "cli-logs" || "$dirname" == "content-logs" ]]; then
                            continue
                        fi
                        # Use the first remaining directory (should be the repo)
                        repo_dir="$dirname"
                        break
                    done

                    if [[ -n "$repo_dir" ]]; then
                        repo_data_size=$(du -sh "${cache_path}/${repo_dir}" 2>/dev/null | awk '{print $1}')
                    fi

                    # Display kopia breakdown
                    printf "    %-20s %s\n" "kopia:" "(SSD storage | RAM logs)"
                    if [[ -n "$repo_data_size" ]]; then
                        printf "    %-20s repo: %s [SSD]\n" "" "$repo_data_size"
                    fi
                    # For RAM logs, show usage/total (percent) like system cache
                    # Use the mounted path (~/.cache/kopia/...) not the backing path
                    local cli_logs_mount="${cache_path}/cli-logs"
                    local content_logs_mount="${cache_path}/content-logs"
                    if [[ -d "$cli_logs_mount" ]]; then
                        local cli_used cli_total cli_percent cli_used_bytes cli_total_bytes
                        # Get actual used size from du (in bytes) - use mounted path
                        cli_used_bytes=$(du -sb "$cli_logs_mount" 2>/dev/null | awk '{print $1}')
                        # Get total size from df (in bytes) - use backing path for df
                        cli_total_bytes=$(df -B1 "${PERSISTENT}/ecc-cache/kopia/cli-logs" 2>/dev/null | tail -1 | awk '{print $2}')
                        # Calculate percent
                        if [[ $cli_total_bytes -gt 0 ]]; then
                            cli_percent=$((cli_used_bytes * 100 / cli_total_bytes))
                        else
                            cli_percent=0
                        fi
                        # Format sizes in MB
                        cli_used=$((cli_used_bytes / 1024 / 1024))
                        cli_total=$((cli_total_bytes / 1024 / 1024))
                        printf "    %-20s cli-logs: %sM/%sM (%s%%) [RAM]\n" "" "$cli_used" "$cli_total" "$cli_percent"
                    fi
                    if [[ -d "$content_logs_mount" ]]; then
                        local content_used content_total content_percent content_used_bytes content_total_bytes
                        # Get actual used size from du (in bytes) - use mounted path
                        content_used_bytes=$(du -sb "$content_logs_mount" 2>/dev/null | awk '{print $1}')
                        # Get total size from df (in bytes) - use backing path for df
                        content_total_bytes=$(df -B1 "${PERSISTENT}/ecc-cache/kopia/content-logs" 2>/dev/null | tail -1 | awk '{print $2}')
                        # Calculate percent
                        if [[ $content_total_bytes -gt 0 ]]; then
                            content_percent=$((content_used_bytes * 100 / content_total_bytes))
                        else
                            content_percent=0
                        fi
                        # Format sizes in MB
                        content_used=$((content_used_bytes / 1024 / 1024))
                        content_total=$((content_total_bytes / 1024 / 1024))
                        printf "    %-20s content-logs: %sM/%sM (%s%%) [RAM]\n" "" "$content_used" "$content_total" "$content_percent"
                    fi
                else
                    printf "    %-20s %s [SSD]\n" "${cache_dir}:" "$size"
                fi
            fi
        fi
    done

    # Show systemd service/timer status
    show_systemd_status "shadowcache-user@${SHELLBASE_USER}.service" "shadowcache-user@${SHELLBASE_USER}.timer" "true"
}

show_system_status() {
    echo "System Cache (tmpfs): /var/cache, /var/tmp"
    if [[ -f $STATEFILE ]]; then
        # shellcheck source=/dev/null
        source "$STATEFILE"
        echo "  Last Sync: ${LAST_SYNC:-unknown}"
        echo "  Operation: ${LAST_OPERATION:-unknown}"
    fi
    echo "  /var/cache: $(df -h /var/cache 2>/dev/null | tail -1 | awk '{printf "%s/%s (%s)", $3, $2, $5}') [RAM]"
    echo "  /var/tmp:   $(df -h /var/tmp 2>/dev/null | tail -1 | awk '{printf "%s/%s (%s)", $3, $2, $5}') [RAM]"

    # Show systemd service/timer status
    show_systemd_status "shadowcache-system.service" "shadowcache-system.timer" "false"
}

# ============================================================================
# COMMAND HANDLERS
# ============================================================================

# ----------------------------------------------------------------------------
# User service commands (run as user, handle ~/.cache/)
# ----------------------------------------------------------------------------

# Load user cache from persistent storage to runtime locations
#
# DIRECTION: Persistent storage (SSD) → Runtime locations
#   ~/.cache:    /volumes/APM-cache/ecc-cache/ → ~/.cache/ (tmpfs - RAM)
#   ~/.config:   /volumes/APM-cache/ecc-config/thorium/ → ~/.config/thorium/ (root SSD)
#
# WHEN TO USE: On boot (via systemd service) to restore data from previous session
#
# LESSON: Notice the src/dst order for rsync:
#   src="$PERSISTENT/${CACHE_USER}-cache/"  - reads from persistent SSD
#   dst="${SHELLBASE_CACHE_DIR}/"           - writes to tmpfs (RAM)
# This is the REVERSE of user-save - we're loading data INTO runtime.
#
cmd_user_load() {
    set_scope "user"
    acquire_lock

    log_info "Loading user cache..."
    SYNC_START_TIME=$(date +%s)

    # Pre-flight validation
    if ! validate_persistent_mount; then
        release_lock
        exit 1
    fi

    # LESSON: src/dst order determines ACTUAL direction
    # "load" is just a label - rsync copies FROM src TO dst
    sync_user_cache "load" \
        "$PERSISTENT"/${CACHE_USER}-cache/ \
        "${SHELLBASE_CACHE_DIR}/"

    local end_time
    end_time=$(date +%s)
    local -i duration=$((end_time - SYNC_START_TIME))

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] User load would complete in ${duration}s"
        save_state "user-load" "dry-run" "0"
    else
        log_info "User load complete (${duration}s)"
        save_state "user-load" "success" "$TOTAL_BYTES_TRANSFERRED"
    fi

    release_lock
}

# Save user cache from runtime locations to persistent storage
#
# DIRECTION: Runtime locations → Persistent storage (SSD)
#   ~/.cache:    ~/.cache/ (tmpfs - RAM) → /volumes/APM-cache/ecc-cache/
#   ~/.config:   ~/.config/thorium/ (root SSD) → /volumes/APM-cache/ecc-config/thorium/
#
# WHEN TO USE: On shutdown (via systemd service) or periodically (every 4 hours via timer)
#              to protect volatile RAM data from power loss/reboot
#
# LESSON: Notice the src/dst order for rsync:
#   src="${SHELLBASE_CACHE_DIR}/"           - reads from tmpfs (RAM)
#   dst="$PERSISTENT/${CACHE_USER}-cache/"  - writes to persistent SSD
# This is the REVERSE of user-load - we're saving data FROM runtime.
#
cmd_user_save() {
    set_scope "user"
    acquire_lock

    log_info "Saving user cache..."
    SYNC_START_TIME=$(date +%s)

    # Pre-flight validation
    if ! validate_persistent_mount; then
        release_lock
        exit 1
    fi

    # LESSON: src/dst order determines ACTUAL direction
    # "save" is just a label - rsync copies FROM src TO dst
    sync_user_cache "save" \
        "${SHELLBASE_CACHE_DIR}/" \
        "$PERSISTENT"/${CACHE_USER}-cache/

    local end_time
    end_time=$(date +%s)
    local -i duration=$((end_time - SYNC_START_TIME))

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] User save would complete in ${duration}s"
        save_state "user-save" "dry-run" "0"
    else
        log_info "User save complete (${duration}s)"
        save_state "user-save" "success" "$TOTAL_BYTES_TRANSFERRED"
    fi

    release_lock
}

cmd_user_status() {
    set_scope "user"
    log_info "User cache status report"
    show_user_status
}

cmd_user_validate() {
    set_scope "user"
    log_info "Validating user cache prerequisites..."
    local all_ok=true

    check_rsync_available || all_ok=false
    validate_persistent_mount || all_ok=false
    check_bind_mounts || all_ok=false

    if [[ ! -d ${SHELLBASE_CACHE_DIR} ]]; then
        log_error "Cache directory not found: ${SHELLBASE_CACHE_DIR}"
        all_ok=false
    else
        log_debug "Cache directory: ${SHELLBASE_CACHE_DIR}"
    fi

    if command -v flock >/dev/null 2>&1; then
        log_debug "flock available (for lock management)"
    else
        log_warn "flock not found (lock management disabled)"
    fi

    echo ""
    if [[ $all_ok == true ]]; then
        log_info "✓ User validation passed"
        return 0
    else
        log_error "✗ User validation failed"
        return 1
    fi
}

cmd_user_log() {
    local service_name="shadowcache-user@${SHELLBASE_USER}.service"
    log_info "User cache logs: $service_name"
    show_logs "user" "$service_name" "true" "$@"
}

cmd_user_files() {
    set_scope "user"
    show_files_transferred "user"
}

# ----------------------------------------------------------------------------
# System service commands (run as root, handle /var/cache/ and /var/tmp/)
# ----------------------------------------------------------------------------

# Load system cache from persistent storage to runtime tmpfs
#
# DIRECTION: Persistent storage (SSD) → Runtime tmpfs (RAM)
#   /var/cache:  /volumes/APM-cache/var-cache/ → /var/cache/ (tmpfs - RAM)
#   /var/tmp:    /volumes/APM-cache/var-tmp/ → /var/tmp/ (tmpfs - RAM)
#
# WHEN TO USE: On boot (via systemd service) to restore system cache data
#
cmd_system_load() {
    set_scope "system"
    acquire_lock

    log_info "Loading system cache..."
    SYNC_START_TIME=$(date +%s)

    # Pre-flight validation
    if ! validate_persistent_mount; then
        release_lock
        exit 1
    fi

    sync_var_cache "load" \
        "$PERSISTENT"/var-cache/ \
        /var/cache/

    sync_var_tmp "load" \
        "$PERSISTENT"/var-tmp/ \
        /var/tmp/

    local end_time
    end_time=$(date +%s)
    local -i duration=$((end_time - SYNC_START_TIME))

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] System load would complete in ${duration}s"
        save_state "system-load" "dry-run" "0"
    else
        log_info "System load complete (${duration}s)"
        save_state "system-load" "success" "$TOTAL_BYTES_TRANSFERRED"
    fi

    release_lock
}

# Save system cache from runtime tmpfs to persistent storage
#
# DIRECTION: Runtime tmpfs (RAM) → Persistent storage (SSD)
#   /var/cache:  /var/cache/ (tmpfs - RAM) → /volumes/APM-cache/var-cache/
#   /var/tmp:    /var/tmp/ (tmpfs - RAM) → /volumes/APM-cache/var-tmp/
#
# WHEN TO USE: On shutdown (via systemd service) or periodically (every 6 hours via timer)
#              to protect volatile RAM data from power loss/reboot
#
cmd_system_save() {
    set_scope "system"
    acquire_lock

    log_info "Saving system cache..."
    SYNC_START_TIME=$(date +%s)

    # Pre-flight validation
    if ! validate_persistent_mount; then
        release_lock
        exit 1
    fi

    sync_var_cache "save" \
        /var/cache/ \
        "$PERSISTENT"/var-cache/ \
        "--exclude apt/archives"

    sync_var_tmp "save" \
        /var/tmp/ \
        "$PERSISTENT"/var-tmp/

    local end_time
    end_time=$(date +%s)
    local -i duration=$((end_time - SYNC_START_TIME))

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] System save would complete in ${duration}s"
        save_state "system-save" "dry-run" "0"
    else
        log_info "System save complete (${duration}s)"
        save_state "system-save" "success" "$TOTAL_BYTES_TRANSFERRED"
    fi

    release_lock
}

cmd_system_status() {
    set_scope "system"
    log_info "System cache status report"
    show_system_status
}

cmd_system_validate() {
    set_scope "system"
    log_info "Validating system cache prerequisites..."
    local all_ok=true

    check_rsync_available || all_ok=false
    validate_persistent_mount || all_ok=false

    # Check /var/cache and /var/tmp are accessible
    if [[ ! -d /var/cache ]]; then
        log_error "/var/cache not found"
        all_ok=false
    else
        log_debug "System cache directory: /var/cache"
    fi

    if [[ ! -d /var/tmp ]]; then
        log_error "/var/tmp not found"
        all_ok=false
    else
        log_debug "System tmp directory: /var/tmp"
    fi

    if command -v flock >/dev/null 2>&1; then
        log_debug "flock available (for lock management)"
    else
        log_warn "flock not found (lock management disabled)"
    fi

    echo ""
    if [[ $all_ok == true ]]; then
        log_info "✓ System validation passed"
        return 0
    else
        log_error "✗ System validation failed"
        return 1
    fi
}

cmd_system_log() {
    local service_name="shadowcache-system.service"
    log_info "System cache logs: $service_name"
    show_logs "system" "$service_name" "false" "$@"
}

cmd_system_files() {
    set_scope "system"
    show_files_transferred "system"
}

cmd_load() {
    acquire_lock

    log_info "Loading persisted data into tmpfs..."
    SYNC_START_TIME=$(date +%s)

    # Pre-flight validation
    if ! validate_persistent_mount; then
        release_lock
        exit 1
    fi

    sync_user_cache "load" \
        "$PERSISTENT"/${CACHE_USER}-cache/ \
        "${SHELLBASE_CACHE_DIR}/"

    sync_var_cache "load" \
        "$PERSISTENT"/var-cache/ \
        /var/cache/

    sync_var_tmp "load" \
        "$PERSISTENT"/var-tmp/ \
        /var/tmp/

    local end_time
    end_time=$(date +%s)
    local -i duration=$((end_time - SYNC_START_TIME))

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Load would complete in ${duration}s"
        save_state "load" "dry-run" "0"
    else
        log_info "Load complete (${duration}s)"
        save_state "load" "success" "$TOTAL_BYTES_TRANSFERRED"
    fi

    release_lock
}

cmd_save() {
    acquire_lock

    log_info "Saving tmpfs data into persistent storage..."
    SYNC_START_TIME=$(date +%s)

    # Pre-flight validation
    if ! validate_persistent_mount; then
        release_lock
        exit 1
    fi

    sync_user_cache "save" \
        "${SHELLBASE_CACHE_DIR}/" \
        "$PERSISTENT"/${CACHE_USER}-cache/

    sync_var_cache "save" \
        /var/cache/ \
        "$PERSISTENT"/var-cache/ \
        "--exclude apt/archives"

    sync_var_tmp "save" \
        /var/tmp/ \
        "$PERSISTENT"/var-tmp/

    local end_time
    end_time=$(date +%s)
    local -i duration=$((end_time - SYNC_START_TIME))

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Save would complete in ${duration}s"
        save_state "save" "dry-run" "0"
    else
        log_info "Save complete (${duration}s)"
        save_state "save" "success" "$TOTAL_BYTES_TRANSFERRED"
    fi

    release_lock
}

cmd_status() {
    log_info "Shadowcache status report"
    echo ""

    # Load and display state
    if [[ -f $STATEFILE ]]; then
        # shellcheck source=/dev/null
        source "$STATEFILE"
        echo "Last Sync:"
        echo "  Time:      ${LAST_SYNC:-unknown}"
        echo "  Operation: ${LAST_OPERATION:-unknown}"
        echo "  Status:    ${LAST_STATUS:-unknown}"
        echo "  Bytes:     ${LAST_BYTES:-unknown}"
        echo "  PID:       ${LAST_PID:-unknown}"
    else
        echo "No sync history found (state file missing)"
    fi
    echo ""

    # Mount status
    echo "Mount Status:"
    if mountpoint -q "$PERSISTENT"; then
        echo "  Persistent: ✓ $PERSISTENT"
        df -h "$PERSISTENT" 2>/dev/null | tail -1 | awk '{printf "    Used: %s/%s (%s)\n", $3, $2, $5}'
    else
        echo "  Persistent: ✗ $PERSISTENT (not mounted)"
    fi

    if [[ -d ${SHELLBASE_CACHE_DIR} ]]; then
        local fs_type
        fs_type=$(df --output=fstype "${SHELLBASE_CACHE_DIR}" 2>/dev/null | tail -1 || echo "unknown")
        echo "  Cache:      ✓ ${SHELLBASE_CACHE_DIR} (${fs_type})"
        df -h "${SHELLBASE_CACHE_DIR}" 2>/dev/null | tail -1 | awk '{printf "    Used: %s/%s (%s)\n", $3, $2, $5}'
    else
        echo "  Cache:      ✗ ${SHELLBASE_CACHE_DIR} (not found)"
    fi
    echo ""

    # Lock status
    echo "Lock Status:"
    if [[ -f $LOCKFILE ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCKFILE" 2>/dev/null || echo "unknown")
        if kill -0 "$lock_pid" 2>/dev/null; then
            echo "  ⚠ Lock held by PID: $lock_pid"
        else
            echo "  ⚠ Stale lock file (PID $lock_pid not running)"
        fi
    else
        echo "  ✓ No lock active"
    fi
}

cmd_validate() {
    log_info "Validating shadowcache prerequisites..."
    local all_ok=true

    check_rsync_available || all_ok=false
    validate_persistent_mount || all_ok=false
    check_bind_mounts || all_ok=false

    if [[ ! -d ${SHELLBASE_CACHE_DIR} ]]; then
        log_error "Cache directory not found: ${SHELLBASE_CACHE_DIR}"
        all_ok=false
    else
        log_debug "Cache directory: ${SHELLBASE_CACHE_DIR}"
    fi

    if command -v flock >/dev/null 2>&1; then
        log_debug "flock available (for lock management)"
    else
        log_warn "flock not found (lock management disabled)"
    fi

    echo ""
    if [[ $all_ok == true ]]; then
        log_info "✓ All validations passed"
        return 0
    else
        log_error "✗ Some validations failed"
        return 1
    fi
}

# Show write statistics from a metrics log file
# Args:
#   $1 - metrics_log: Path to the CSV metrics file
#   $2 - title: Optional title for the output (default: "Shadowcache Write Statistics")
#   $3 - filter_cache: Optional cache name to filter (e.g., "ecc-cache", "ecc-config")
show_metrics_stats() {
    local metrics_log=$1
    local title=${2:-"Shadowcache Write Statistics"}
    local filter_cache=${3:-""}

    if [[ ! -f $metrics_log ]]; then
        log_error "No metrics data found at: $metrics_log"
        return 1
    fi

    log_info "$title"
    echo ""

    # Calculate statistics using awk
    # Dynamically shows whatever cache types are in the metrics file
    # If filter_cache is set, only show that specific cache
    awk -F',' -v filter="$filter_cache" '
    BEGIN {
        total_writes = 0; total_literal = 0; total_count = 0
        first_timestamp = ""; last_timestamp = ""
    }
    NR > 1 {
        timestamp = $1; cache = $2; op = $3
        total_bytes = $4; literal_bytes = $5; matched_bytes = $6
        file_count = $7; duration_ms = $8

        # Skip if filter is set and cache does not match
        if (filter != "" && cache != filter) next

        # Track first and last timestamps
        if (first_timestamp == "") first_timestamp = timestamp
        last_timestamp = timestamp

        # Estimate SSD writes: literal * 0.85 (BTRFS zstd:5 compression)
        ssd_writes = int(literal_bytes * 85 / 100)

        # Accumulate per-cache statistics (using cache name as array index)
        cache_total[cache] += ssd_writes
        cache_literal[cache] += literal_bytes
        cache_count[cache]++

        total_writes += ssd_writes
        total_literal += literal_bytes
        total_count++
    }
    END {
        # Format bytes helper (inlined for mawk compatibility)
        # Usage: _fmt_val = <bytes>; then call format logic
        # Result stored in _fmt_result

        # Print per-cache statistics
        for (cache in cache_total) {
            if (cache_count[cache] == 0) continue

            _fmt_val = cache_total[cache]
            if (_fmt_val >= 1073741824) _fmt_result = sprintf("%.2f GB", _fmt_val/1073741824)
            else if (_fmt_val >= 1048576) _fmt_result = sprintf("%.2f MB", _fmt_val/1048576)
            else if (_fmt_val >= 1024) _fmt_result = sprintf("%.2f KB", _fmt_val/1024)
            else _fmt_result = _fmt_val " B"
            _fmt_total = _fmt_result

            _fmt_val = cache_literal[cache]
            if (_fmt_val >= 1073741824) _fmt_result = sprintf("%.2f GB", _fmt_val/1073741824)
            else if (_fmt_val >= 1048576) _fmt_result = sprintf("%.2f MB", _fmt_val/1048576)
            else if (_fmt_val >= 1024) _fmt_result = sprintf("%.2f KB", _fmt_val/1024)
            else _fmt_result = _fmt_val " B"
            _fmt_literal = _fmt_result

            print cache ":"
            print "  Estimated SSD writes: " _fmt_total " (from " _fmt_literal " transferred)"
            print "  Operations:           " cache_count[cache]

            _fmt_val = cache_total[cache] / cache_count[cache]
            if (_fmt_val >= 1073741824) _fmt_result = sprintf("%.2f GB", _fmt_val/1073741824)
            else if (_fmt_val >= 1048576) _fmt_result = sprintf("%.2f MB", _fmt_val/1048576)
            else if (_fmt_val >= 1024) _fmt_result = sprintf("%.2f KB", _fmt_val/1024)
            else _fmt_result = _fmt_val " B"
            print "  Average per operation: " _fmt_result
            print ""
        }

        # Print combined totals
        if (total_count > 0) {
            _fmt_val = total_writes
            if (_fmt_val >= 1073741824) _fmt_result = sprintf("%.2f GB", _fmt_val/1073741824)
            else if (_fmt_val >= 1048576) _fmt_result = sprintf("%.2f MB", _fmt_val/1048576)
            else if (_fmt_val >= 1024) _fmt_result = sprintf("%.2f KB", _fmt_val/1024)
            else _fmt_result = _fmt_val " B"

            print "Total:"
            print "  Estimated SSD writes: " _fmt_result " (from " \
                (total_literal >= 1073741824 ? sprintf("%.2f GB", total_literal/1073741824) : \
                 total_literal >= 1048576 ? sprintf("%.2f MB", total_literal/1048576) : \
                 total_literal >= 1024 ? sprintf("%.2f KB", total_literal/1024) : \
                 total_literal " B") \
                " transferred)"
            print "  Operations:           " total_count
            print "  Confidence interval:  85% ±5%"
            print ""
        }

        # Print time range
        if (first_timestamp != "" && last_timestamp != "") {
            gsub(/T/, " ", first_timestamp)
            gsub(/T/, " ", last_timestamp)
            gsub(/\+.*/, "", first_timestamp)
            gsub(/\+.*/, "", last_timestamp)
            print "Data range:"
            print "  First entry: " first_timestamp
            print "  Last entry:  " last_timestamp
            print ""
        }

        print "Note: Estimates based on rsync literal data with BTRFS zstd:5 compression."
        print "      Actual SSD writes may vary due to compression ratio variance (80-90%)."
    }
    ' "$metrics_log"
}

# Show user cache write statistics
# Usage: user-stats [--filter=cache_name]
cmd_user_stats() {
    set_scope "user"
    local user_metrics_log="$PERSISTENT/${CACHE_USER}-cache/.shadowcache-metrics.csv"
    local filter_cache=""

    # Parse arguments for --filter option
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --filter=*)
                filter_cache="${1#*=}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ ! -f $user_metrics_log ]]; then
        log_error "No user metrics data found at: $user_metrics_log"
        log_error "Run user-save or user-load operations first to generate metrics."
        return 1
    fi

    show_metrics_stats "$user_metrics_log" "User Cache Write Statistics" "$filter_cache"
}

# Show system cache write statistics
# Usage: system-stats [--filter=cache_name]
cmd_system_stats() {
    set_scope "system"
    local system_metrics_log="$PERSISTENT/.shadowcache-metrics.csv"
    local filter_cache=""

    # Parse arguments for --filter option
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --filter=*)
                filter_cache="${1#*=}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ ! -f $system_metrics_log ]]; then
        log_error "No system metrics data found at: $system_metrics_log"
        log_error "Run system-save or system-load operations first to generate metrics."
        return 1
    fi

    show_metrics_stats "$system_metrics_log" "System Cache Write Statistics" "$filter_cache"
}

# Show write statistics from metrics log (legacy command - shows both scopes)
# Displays historical SSD write data with confidence intervals
# Usage: stats [--filter=cache_name]
cmd_stats() {
    local user_metrics_log="$PERSISTENT/${CACHE_USER}-cache/.shadowcache-metrics.csv"
    local system_metrics_log="$PERSISTENT/.shadowcache-metrics.csv"
    local user_found=false
    local system_found=false
    local filter_cache=""

    # Parse arguments for --filter option
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --filter=*)
                filter_cache="${1#*=}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check which metrics files exist
    [[ -f $user_metrics_log ]] && user_found=true
    [[ -f $system_metrics_log ]] && system_found=true

    if [[ $user_found == false && $system_found == false ]]; then
        # No metrics found - report both locations
        log_error "No metrics data found. Run sync operations first."
        log_error "User metrics location: $user_metrics_log"
        log_error "System metrics location: $system_metrics_log"
        return 1
    fi

    # Show user stats if available
    if [[ $user_found == true ]]; then
        show_metrics_stats "$user_metrics_log" "User Cache Write Statistics" "$filter_cache"
        if [[ $system_found == true ]]; then
            echo ""
            echo "========================================"
            echo ""
        fi
    fi

    # Show system stats if available
    if [[ $system_found == true ]]; then
        show_metrics_stats "$system_metrics_log" "System Cache Write Statistics" "$filter_cache"
    fi
}

cmd_log() {
    echo "=== User Cache Logs ==="
    cmd_user_log "$@"
    echo ""
    echo "=== System Cache Logs ==="
    cmd_system_log "$@"
}

cmd_files() {
    echo "=== User Cache Files ==="
    cmd_user_files
    echo ""
    echo "=== System Cache Files ==="
    cmd_system_files
}

# ============================================================================
# MAIN
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  # Split commands (independent services)
  user-load [--dry-run]     Load user cache (~/.cache) from persistent storage
  user-save [--dry-run]     Save user cache to persistent storage
  user-status               Show user cache status
  user-validate             Verify user cache prerequisites
  user-log [opts]           Show user cache logs (journald)
  user-stats [--filter=N]   Show user cache SSD write statistics
                            Filter: ecc-cache, ecc-config (e.g., --filter=ecc-config)
  user-files                Show files transferred in last user save

  system-load [--dry-run]   Load system cache (/var/cache, /var/tmp)
  system-save [--dry-run]   Save system cache to persistent storage
  system-status             Show system cache status
  system-validate           Verify system cache prerequisites
  system-log [opts]         Show system cache logs (requires root)
  system-stats [--filter=N] Show system cache SSD write statistics
                            Filter: var-cache, var-tmp (e.g., --filter=var-cache)
  system-files              Show files transferred in last system save

  # Legacy commands (backward compatible - runs both user and system)
  load [--dry-run]           Load all caches from persistent storage
  save [--dry-run]           Save all caches to persistent storage
  status                    Show status for all caches
  validate                  Verify all prerequisites
  stats [--filter=N]        Show SSD write statistics with confidence intervals
                            Filter by cache_name (e.g., --filter=ecc-config)
  log [opts]                Show all cache logs
  files                     Show files transferred (both scopes)

Options:
  --dry-run            Show what would be synced without actually doing it
  --verbose, -v        Enable detailed debug output
  --help, -h           Show this help message

Journalctl options (for log commands):
  [opts] are passed to journalctl, e.g.:
    --since <time>   Show entries since specified time (e.g., "1 hour ago", today)
    --lines <N>/-n   Number of lines to show
    -f/--follow      Follow log output
    -e               Jump to end of pager
    --no-pager       Do not pipe output into a pager

Examples:
  $(basename "$0") user-load               # Load user cache only
  $(basename "$0") system-status           # Show system cache status
  $(basename "$0") load                    # Load all caches (legacy)
  $(basename "$0") save --dry-run          # Preview save operation
  $(basename "$0") validate                # Verify system is ready
  $(basename "$0") user-log --since "1 hour ago"    # User logs from last hour
  $(basename "$0") system-log -f                    # Follow system logs
  $(basename "$0") log --since today                # All logs from today

EOF
}

main() {
    # Parse options first (before command)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Not an option, stop parsing
                break
                ;;
        esac
    done

    # Route command
    local command=${1:-}
    shift || true

    case "$command" in
        # New split commands
        user-load)
            cmd_user_load
            ;;
        user-save)
            cmd_user_save
            ;;
        user-status)
            cmd_user_status
            ;;
        user-validate)
            cmd_user_validate
            ;;
        user-log)
            cmd_user_log "$@"
            ;;
        user-stats)
            cmd_user_stats "$@"
            ;;
        user-files)
            cmd_user_files
            ;;
        system-load)
            cmd_system_load
            ;;
        system-save)
            cmd_system_save
            ;;
        system-status)
            cmd_system_status
            ;;
        system-validate)
            cmd_system_validate
            ;;
        system-log)
            cmd_system_log "$@"
            ;;
        system-stats)
            cmd_system_stats "$@"
            ;;
        system-files)
            cmd_system_files
            ;;

        # Legacy commands (backward compatible - run both user and system)
        load)
            cmd_user_load
            cmd_system_load
            ;;
        save)
            cmd_user_save
            cmd_system_save
            ;;
        status)
            echo "=== User Cache ==="
            cmd_user_status
            echo ""
            echo "=== System Cache ==="
            cmd_system_status
            echo 'Run "kopia repository status" for Kopia status'
            ;;
        validate)
            local user_valid system_valid
            cmd_user_validate && user_valid=true || user_valid=false
            cmd_system_validate && system_valid=true || system_valid=false
            if [[ $user_valid == true && $system_valid == true ]]; then
                log_info "✓ All validations passed"
                exit 0
            else
                log_error "✗ Some validations failed"
                exit 1
            fi
            ;;
        stats)
            cmd_stats "$@"
            ;;
        log)
            cmd_log "$@"
            ;;
        files)
            cmd_files
            ;;
        "")
            log_error "No command specified"
            echo ""
            show_usage
            exit 1
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Trap to ensure lock is always released
trap release_lock EXIT INT TERM

main "$@"
exit 0
