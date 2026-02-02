# Shadowcache Enhancement Plan
**Date:** 2026-01-30
**Related:** `~/src/system-investigation/03-solutions/20260130-hybrid-implementation-guide.md`

---

## Overview

Enhance `~/src/shellbase/bin/shadowcache.sh` with safety, validation, and observability features while preserving its elegant simplicity and POSIX compatibility.

---

## Current State Analysis

### Strengths of Current Implementation

1. **Clean architecture** - Simple case statement with clear load/save paths
2. **Environment variable integration** - Leverages `SHELLBASE_USER`, `SHELLBASE_CACHE_DIR`
3. **Well-documented** - Inline comments explain what's being synced
4. **Well-documented** - Inline comments explain what's being synced
5. **Appropriate exclusions** - Handles kopia bind mount, apt archives, flatpak cache

### Gaps Compared to Hybrid Implementation

| Feature | Current | Hybrid | Priority |
|---------|---------|--------|----------|
| Lock management | None | flock-based | HIGH |
| Validation (pre-flight checks) | None | Mount/path checks | HIGH |
| State tracking | None | Last sync metadata | MEDIUM |
| Dry-run mode | None | `--dry-run` flag | MEDIUM |
| Status command | None | System health report | MEDIUM |
| Validate command | None | Prerequisites check | LOW |
| Verbose mode | None | Debug output | LOW |

---

## Design Philosophy

**Elegance principle:** Add features without breaking the clean, simple structure. Each enhancement should be a self-contained function that can be easily understood and tested.

**Constraints:**
- Use `#!/bin/env bash` shebang (changed from `/bin/sh`)
- Leverage bash features where they improve clarity: `[[`, arrays, local variables
- Keep the case statement structure for command routing
- Use environment variables for configuration (already established pattern)
- Make features optional/opt-in (backward compatible)

---

## Enhancement Plan

### Phase 1: Safety Foundation (HIGH priority)

#### 1.1 Lock Management

**Problem:** Concurrent load/save operations could corrupt data or cause race conditions.

**Solution:** Add `flock`-based locking with automatic cleanup.

```sh
# Configuration
LOCKFILE="${SHADOWCACHE_LOCKFILE:-/run/lock/shadowcache.lock}"

# Functions
acquire_lock() {
    mkdir -p "$(dirname "$LOCKFILE")"
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
        echo "[!] Cannot acquire lock. Another operation may be running." >&2
        echo "[!] Lock file: $LOCKFILE" >&2
        exit 1
    fi
    echo $$ > "$LOCKFILE"
}

release_lock() {
    flock -u 200 2>/dev/null || true
    rm -f "$LOCKFILE" 2>/dev/null || true
}
```

**Integration:**
- Call `acquire_lock` at start of `load` and `save` commands
- Use `trap release_lock EXIT INT TERM` for automatic cleanup
- No changes needed to existing rsync logic

**Benefits:**
- Prevents concurrent operations
- Automatic cleanup on interrupt
- Debugging via PID in lockfile

---

#### 1.2 Pre-flight Validation

**Problem:** Script runs even when persistent storage isn't mounted, causing silent failures.

**Solution:** Add `validate_persistent_mount()` function called before sync operations.

```sh
# Configuration
PERSISTENT="${SHADOWCACHE_PERSISTENT:-/volumes/APM-cache/}"

# Functions
validate_persistent_mount() {
    if [ ! -d "$PERSISTENT" ]; then
        echo "[!] Persistent storage not found: $PERSISTENT" >&2
        return 1
    fi

    if ! mountpoint -q "$PERSISTENT"; then
        echo "[!] Persistent storage not mounted: $PERSISTENT" >&2
        return 1
    fi

    # Write test
    local test_file="$PERSISTENT/.shadowcache-write-test-$$"
    if ! touch "$test_file" 2>/dev/null; then
        echo "[!] Cannot write to persistent storage: $PERSISTENT" >&2
        return 1
    fi
    rm -f "$test_file"

    return 0
}
```

**Integration:**
- Call in `load` and `save` commands, after acquiring lock
- Exit with error if validation fails
- Optional: bypass with `--force` flag

---

### Phase 2: Observability (MEDIUM priority)

#### 2.1 State Tracking

**Problem:** No visibility into when last sync occurred, what was transferred, or whether sync succeeded.

**Solution:** Record sync metadata to a state file.

```sh
# Configuration
STATEFILE="${SHADOWCACHE_STATEFILE:-$PERSISTENT/.shadowcache-state}"

# Functions
save_state() {
    local operation="$1"
    local status="${2:-success}"
    local bytes="${3:-0}"

    cat > "$STATEFILE" <<EOF
# Shadowcache state - Generated $(date -Iseconds 2>/dev/null || date)
LAST_SYNC="$(date -Iseconds 2>/dev/null || date)"
LAST_OPERATION="$operation"
LAST_STATUS="$status"
LAST_BYTES="$bytes"
LAST_PID="$$"
EOF
}

# Parse rsync stats to extract bytes (called after each rsync)
# Returns byte count on stdout
extract_rsync_bytes() {
    # Parse from: "sent 672.31M bytes  received 1.80K bytes"
    # Or from: "total size is 672.14M"
    awk '/total size is/ {
        size=$4;
        # Convert K/M/G suffix to bytes
        if (match(size, /[0-9.]+[KMG]/i)) {
            val = tolower(size);
            gsub(/[kmg]/, "", val);
            unit = tolower(substr(size, length(size)));
            if (unit == "k") print val * 1024;
            else if (unit == "m") print val * 1024 * 1024;
            else if (unit == "g") print val * 1024 * 1024 * 1024;
            else print val;
        }
    }'
}
```

**Integration:**
- Call `save_state` at end of `load`/`save` commands
- Capture rsync output, parse for byte count
- State file readable by other tools for monitoring

---

#### 2.2 Status Command

**Problem:** No easy way to see system health, last sync info, or verify mounts.

**Solution:** Add `status` subcommand that reports current state.

```sh
cmd_status() {
    echo "=== Shadowcache Status ==="
    echo ""

    # Load and display state
    if [ -f "$STATEFILE" ]; then
        . "$STATEFILE"
        echo "Last Sync:"
        echo "  Time:     ${LAST_SYNC:-unknown}"
        echo "  Operation: ${LAST_OPERATION:-unknown}"
        echo "  Status:    ${LAST_STATUS:-unknown}"
        echo "  Bytes:     ${LAST_BYTES:-unknown}"
        echo "  PID:       ${LAST_PID:-unknown}"
    else
        echo "No sync history (state file missing)"
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

    if mountpoint -q "${SHELLBASE_CACHE_DIR}"; then
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
    if [ -f "$LOCKFILE" ]; then
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
```

**Integration:**
- Add `status)` case to main command router
- Reads state file, checks mounts, reports lock status
- No side effects (read-only)

---

#### 2.3 Validate Command

**Problem:** No way to check if system is ready for shadowcache operations without actually running them.

**Solution:** Add `validate` subcommand that runs all pre-flight checks.

```sh
cmd_validate() {
    local all_ok=true

    echo "=== Shadowcache Validation ==="
    echo ""

    # Check rsync
    if command -v rsync >/dev/null 2>&1; then
        echo "✓ rsync available: $(rsync --version 2>/dev/null | head -1)"
    else
        echo "✗ rsync not found"
        all_ok=false
    fi

    # Check persistent mount
    if validate_persistent_mount 2>/dev/null; then
        echo "✓ Persistent mount: $PERSISTENT"
    else
        echo "✗ Persistent mount failed"
        all_ok=false
    fi

    # Check cache directory
    if [ -d "${SHELLBASE_CACHE_DIR}" ]; then
        echo "✓ Cache directory: ${SHELLBASE_CACHE_DIR}"
    else
        echo "✗ Cache directory not found: ${SHELLBASE_CACHE_DIR}"
        all_ok=false
    fi

    # Check for flock
    if command -v flock >/dev/null 2>&1; then
        echo "✓ flock available (for lock management)"
    else
        echo "⚠ flock not found (lock management disabled)"
    fi

    echo ""
    if [ "$all_ok" = true ]; then
        echo "✓ All validations passed"
        return 0
    else
        echo "✗ Some validations failed"
        return 1
    fi
}
```

---

### Phase 3: Usability (LOW priority)

#### 3.1 Dry-run Mode

**Problem:** Can't preview what would be synced without actually doing it.

**Solution:** Add `--dry-run` flag that passes `--dry-run` to rsync.

```sh
# Configuration
DRY_RUN=false

# Parse arguments
case "$1" in
    --dry-run)
        DRY_RUN=true
        shift
        ;;
esac

# Build rsync command
RSYNC_OPTS="${RSYNC_OPTS:-} -ah --delete --stats"
if [ "$DRY_RUN" = true ]; then
    RSYNC_OPTS="$RSYNC_OPTS --dry-run"
    echo "[DRY-RUN] Previewing sync operation..."
fi

# Use $RSYNC_OPTS in all rsync calls
```

**Integration:**
- Parse `--dry-run` before main case statement
- Flag applies to all rsync operations
- Clear output prefix to indicate dry-run mode

---

#### 3.2 Verbose Mode

**Problem:** Limited visibility into what's happening during sync.

**Solution:** Add `--verbose` flag that enables rsync progress and debug output.

```sh
# Configuration
VERBOSE=false

# Parse arguments (before main case)
case "$1" in
    --verbose|-v)
        VERBOSE=true
        shift
        ;;
esac

# Logging function
log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo "[D] $*" >&2
    fi
}

# Enable rsync progress if verbose
if [ "$VERBOSE" = true ]; then
    RSYNC_OPTS="$RSYNC_OPTS -v --progress"
fi
```

---

## Implementation Order

### Recommended rollout:

1. **Lock management** - Critical safety feature, no breaking changes
2. **Pre-flight validation** - Prevents silent failures
3. **Status command** - Adds observability without changing behavior
4. **State tracking** - Records history, useful for debugging
5. **Validate command** - Completes the observability picture
6. **Dry-run mode** - Quality-of-life for testing
7. **Verbose mode** - Nice-to-have for debugging

---

## Proposed Structure

```bash
#!/bin/env bash

# ============================================================================
# CONFIGURATION
# ============================================================================

# Use shellbase environment variables with fallbacks
: "${SHELLBASE_USER:=$(id -un)}"
: "${SHELLBASE_CACHE_DIR:=$HOME/.cache}"

# Shadowcache-specific configuration
PERSISTENT="${SHADOWCACHE_PERSISTENT:-/volumes/APM-cache/}"
CACHE_USER="${SHELLBASE_USER}"
LOCKFILE="${SHADOWCACHE_LOCKFILE:-/run/lock/shadowcache.lock}"
STATEFILE="${SHADOWCACHE_STATEFILE:-$PERSISTENT/.shadowcache-state}"

# Rsync options (base)
RSYNC_BASE_OPTS="-ah --delete --stats"

# Flags (set via argument parsing)
DRY_RUN=false
VERBOSE=false

# ============================================================================
# GLOBAL STATE
# ============================================================================

declare -g SYNC_START_TIME=""
declare -gi TOTAL_BYTES_TRANSFERRED=0
declare -gi OPERATION_COUNT=0

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

log_metric() {
    local metric=$1
    local value=$2
    echo "[M] ${metric}=${value}" >&2
}

# ============================================================================
# LOCK MANAGEMENT
# ============================================================================

acquire_lock() {
    log_debug "Attempting to acquire lock: $LOCKFILE"

    # Create lockfile directory if it doesn't exist
    mkdir -p "$(dirname "$LOCKFILE")"

    # Use flock for exclusive lock (file descriptor 200)
    exec 200>"$LOCKFILE"

    if ! flock -n 200; then
        log_error "Cannot acquire lock. Another shadowcache operation may be running."
        log_error "Lock file: $LOCKFILE"
        log_error "If you're sure no other instance is running, remove the lock file:"
        log_error "  sudo rm -f $LOCKFILE"
        exit 1
    fi

    # Store PID for debugging
    echo $$ > "$LOCKFILE"
    log_debug "Lock acquired (PID: $$)"
}

release_lock() {
    log_debug "Releasing lock"
    flock -u 200 2>/dev/null || true
    rm -f "$LOCKFILE" 2>/dev/null || true
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

    # Check if we can write to it
    local test_file="$PERSISTENT/.shadowcache-write-test-$$"
    if ! touch "$test_file" 2>/dev/null; then
        log_error "Cannot write to persistent storage: $PERSISTENT"
        rm -f "$test_file"
        return 1
    fi
    rm -f "$test_file"

    log_debug "Persistent mount OK"
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
# SYNC OPERATIONS
# ============================================================================

run_rsync() {
    local src=$1
    local dst=$2
    local extra_excludes=${3:-}
    local rsync_cmd

    # Build rsync command
    rsync_cmd="rsync $RSYNC_BASE_OPTS"

    if [[ $DRY_RUN == true ]]; then
        rsync_cmd="$rsync_cmd --dry-run"
        log_info "[DRY-RUN] Would sync: $src -> $dst"
    else
        log_debug "Syncing: $src -> $dst"
    fi

    # Add excludes and run
    # shellcheck disable=SC2086
    eval $rsync_cmd $extra_excludes "$src" "$dst"
}

sync_user_cache() {
    local direction=$1
    local src=$2
    local dst=$3

    log_info "Syncing user cache (${direction})..."
    run_rsync "$src" "$dst" "--exclude kopia"
}

sync_var_cache() {
    local direction=$1
    local src=$2
    local dst=$3
    local extra_excludes=${4:-}

    log_info "Syncing /var/cache (${direction})..."
    run_rsync "$src" "$dst" "$extra_excludes"
}

sync_var_tmp() {
    local direction=$1
    local src=$2
    local dst=$3

    log_info "Syncing /var/tmp (${direction})..."
    run_rsync "$src" "$dst" "--exclude 'flatpak-cache-*' --exclude 'systemd-private-*'"
}

# ============================================================================
# COMMAND HANDLERS
# ============================================================================

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
    local duration=$((end_time - SYNC_START_TIME))

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
    local duration=$((end_time - SYNC_START_TIME))

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
        echo "  Time:     ${LAST_SYNC:-unknown}"
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
        df -h "$PERSISTENT" | tail -1 | awk '{printf "    Used: %s/%s (%s)\n", $3, $2, $5}'
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

    if [[ $all_ok == true ]]; then
        log_info "✓ All validations passed"
        return 0
    else
        log_error "✗ Some validations failed"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  load [--dry-run]     Load cache from persistent storage to tmpfs
  save [--dry-run]     Save cache from tmpfs to persistent storage
  status               Show system health and last sync info
  validate             Verify all mounts and paths are ready

Options:
  --dry-run            Show what would be synced without actually doing it
  --verbose, -v        Enable detailed debug output
  --help, -h           Show this help message

Examples:
  $0 load                    # Load cache from persistent storage
  $0 save --dry-run          # Preview save operation
  $0 status                  # Show current status
  $0 validate                # Verify system is ready

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
        load)
            cmd_load
            ;;
        save)
            cmd_save
            ;;
        status)
            cmd_status
            ;;
        validate)
            cmd_validate
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
```

---

## Backward Compatibility

All enhancements are **additive** - no existing behavior changes:

- Existing `load`/`save` commands work identically
- Environment variables override defaults (already established pattern)
- New commands (`status`, `validate`) don't affect existing workflows
- New flags (`--dry-run`, `--verbose`) are optional
- Lock creation is automatic (no user action required)

**Note:** Shebang changes from `#!/bin/sh` to `#!/bin/env bash`. This is a compatible upgrade since bash is a superset of POSIX sh and is virtually guaranteed to be available on any modern Linux system.

---

## Bash-Specific Improvements

Using bash enables cleaner, more robust code:

### `[[` vs `[`

```bash
# POSIX sh
if [ "$VERBOSE" = true ]; then
    ...
fi

# Bash (more robust)
if [[ $VERBOSE == true ]]; then
    ...
fi
```

Benefits:
- No quoting required for variables
- `==` instead of `=` for string comparison (more intuitive)
- Handles empty strings and special characters better
- Supports pattern matching with `=~`

### Arrays

```bash
# Parse rsync stats
local rsync_output=()
mapfile -t rsync_output < <(rsync ...)

# Or collect excludes
local excludes=(
    "kopia"
    "ms-playwright"
    "puppeteer"
)

local exclude_args=""
for excl in "${excludes[@]}"; do
    exclude_args+="--exclude $excl "
done
```

### Integer declaration

```bash
# Global counters with type safety
declare -gi TOTAL_BYTES_TRANSFERRED=0
declare -gi OPERATION_COUNT=0

# Local variables
local -i duration=$((end_time - start_time))
```

### `declare -g` for globals

```bash
# Explicit global variables (useful in functions)
declare -g SYNC_START_TIME=""
declare -gi TOTAL_BYTES_TRANSFERRED=0
```

### `source` vs `.`

```bash
# Bash (more explicit)
source "$STATEFILE"

# Both work, but `source` is clearer than `.`
```

---

## Testing Strategy

```sh
# Test basic operations
shadowcache.sh validate    # Should pass
shadowcache.sh status      # Should show current state
shadowcache.sh --dry-run save   # Preview save
shadowcache.sh save        # Actual save

# Test lock behavior
shadowcache.sh save &
shadowcache.sh save        # Should fail (lock held)

# Test validation failures
sudo umount /volumes/APM-cache
shadowcache.sh save        # Should fail with clear message

# Test state tracking
shadowcache.sh save
cat /volumes/APM-cache/.shadowcache-state  # Should show metadata
```

---

## Related Documentation

- `~/src/system-investigation/03-solutions/20260130-hybrid-implementation-guide.md` - Hybrid solution reference
- `~/src/system-investigation/02-analysis/20260130-shadowcache-mechanism.md` - How shadowcache works
- `~/src/system-investigation/03-solutions/scripts/shadowcache-hybrid.sh` - Enhanced implementation reference
- `~/src/shellbase/etc/systemd/system/README.md` - Systemd integration
- `~/src/shellbase/CLAUDE.md` - Shellbase architecture

---

## Metadata

**Created:** 2026-01-30
**Author:** System investigation
**Status:** Planning phase
**Priority:** HIGH for lock management and validation
