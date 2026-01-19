# Fix IntelliJ Stale Lock Removal Script

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix `intellij-rm-stale-locks.sh` to work with both old (`IdeaIC*`) and new (`IntelliJIdea*`) JetBrains directory naming conventions.

**Architecture:** Replace hardcoded `IdeaIC*` glob pattern with a flexible loop that matches any JetBrains directory containing a `.lock` file.

**Tech Stack:** POSIX shell script (bash), follows codebase philosophy of using `[` over `[[` for portability.

---

### Task 1: Implement the future-proof lock removal script

**Files:**
- Modify: `/home/ecc/bin/intellij-rm-stale-locks.sh`

**Step 1: Replace the script content**

The new implementation uses a glob loop to match any JetBrains directory:

```bash
jetbrains_config=~/.var/app/com.jetbrains.IntelliJ-IDEA-Community/config/JetBrains
for lock in "$jetbrains_config"/*/.lock; do
  [ -f "$lock" ] && rm -fv "$lock"
done
echo flatpak run com.jetbrains.IntelliJ-IDEA-Community
```

**Why this works:**
- `"$jetbrains_config"/*/.lock` expands to all `.lock` files in any subdirectory
- `[ -f "$lock" ]` guards against no matches (glob returns pattern literal when no files exist)
- `rm -fv` removes verbosely, showing what was deleted
- Final `echo` reminds user how to start IntelliJ

**Step 2: Verify the script is executable**

Run: `ls -l /home/ecc/bin/intellij-rm-stale-locks.sh`
Expected: `-rwxr-xr-x` or similar with `x` bit set

If not executable: `chmod +x /home/ecc/bin/intellij-rm-stale-locks.sh`

**Step 3: Create test setup to verify the fix works**

Create mock directories to test both old and new patterns:

```bash
# Create test directories
test_root=/tmp/jetbrains-test
rm -rf "$test_root"
mkdir -p "$test_root/IdeaIC2024.3"
mkdir -p "$test_root/IntelliJIdea2025.3"

# Create lock files
touch "$test_root/IdeaIC2024.3/.lock"
touch "$test_root/IntelliJIdea2025.3/.lock"

# Verify they exist
ls -la "$test_root"/*/.lock
```

Expected: Two `.lock` files listed

**Step 4: Test the script logic with dry-run**

Test the core logic without modifying the real script:

```bash
# Test the loop logic
jetbrains_config="$test_root"
for lock in "$jetbrains_config"/*/.lock; do
  [ -f "$lock" ] && echo "Would remove: $lock"
done
```

Expected output:
```
Would remove: /tmp/jetbrains-test/IdeaIC2024.3/.lock
Would remove: /tmp/jetbrains-test/IntelliJIdea2025.3/.lock
```

**Step 5: Verify both lock files are found**

```bash
# Count lock files found
count=0
jetbrains_config="$test_root"
for lock in "$jetbrains_config"/*/.lock; do
  [ -f "$lock" ] && count=$((count + 1))
done
echo "Found $count lock file(s)"
```

Expected: `Found 2 lock file(s)`

**Step 6: Test the actual removal logic**

```bash
# Run the removal logic
jetbrains_config="$test_root"
for lock in "$jetbrains_config"/*/.lock; do
  [ -f "$lock" ] && rm -fv "$lock"
done

# Verify files are gone
ls "$test_root"/*/.lock 2>&1
```

Expected: `No such file or directory` errors (proving files were deleted)

**Step 7: Clean up test directory**

```bash
rm -rf /tmp/jetbrains-test
```

**Step 8: Manual verification (optional, if IntelliJ lock exists)**

If you have an actual stale lock to test:

```bash
# Run the actual script
~/bin/intellij-rm-stale-locks.sh
```

Expected: Either "removed '.../.lock'" message or no output (no locks found), followed by the flatpak reminder.

**Step 9: Commit**

```bash
cd /home/ecc/IdeaProjects/shellbase
hug add bin/intellij-rm-stale-locks.sh
hug commit -m "fix(intellij): support new IntelliJIdea* directory pattern

JetBrains changed directory naming from IdeaIC* to IntelliJIdea*
in version 2025.3. Replace hardcoded glob with flexible loop
that matches any JetBrains subdirectory containing .lock file.

Refs #plan-2025-01-17"
```

---

### Summary

The script now handles both directory patterns:
- **Old:** `IdeaIC2024.3`, `IdeaIC2025.2`
- **New:** `IntelliJIdea2025.3`, `IntelliJIdea2026.1`
- **Future:** Any JetBrains directory naming convention
