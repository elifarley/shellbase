#!/bin/bash
# test-system-env.sh: Test system environment configuration
#
# This script verifies that the shellbase system environment is properly
# configured and all required variables are set.
#
# Usage: test-system-env.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
pass=0
fail=0
warn=0

# Test functions
test_pass() {
  echo -e "${GREEN}[OK]${NC} $1"
  pass=$((pass + 1))
}

test_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  fail=$((fail + 1))
}

test_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  warn=$((warn + 1))
}

echo "=== Testing Shellbase System Environment ==="
echo

# Test 1: Loader exists
echo "[1/8] Checking if loader exists..."
if [ -f "$HOME/.bashrc.d/04-system-env.sh" ]; then
  test_pass "Loader exists at ~/.bashrc.d/04-system-env.sh"
else
  test_fail "Loader not found at ~/.bashrc.d/04-system-env.sh"
fi

# Test 2: Template exists
echo "[2/8] Checking if template exists..."
if [ -f "$HOME/IdeaProjects/shellbase/etc/default/shellbase" ]; then
  test_pass "Template exists at \$SHELLBASE_REPO_DIR/etc/default/shellbase"
else
  test_warn "Template not found at \$SHELLBASE_REPO_DIR/etc/default/shellbase (may not be installed yet)"
fi

# Test 3: Source the loader and check variables
echo "[3/8] Loading system environment..."
if [ -f "$HOME/.bashrc.d/04-system-env.sh" ]; then
  # Source in a subshell to avoid polluting current environment
  if bash -c "source ~/.bashrc.d/04-system-env.sh && [ -n \"\$SHELLBASE_SYSTEM_ENV_LOADED\" ]"; then
    test_pass "Loader sourced successfully"
  else
    test_fail "Loader failed to source"
  fi
else
  test_fail "Cannot load - loader not found"
fi

# Test 4: Check variables are set
echo "[4/8] Checking variables..."
check_vars=(
  "SHELLBASE_USER"
  "SHELLBASE_USER_HOME"
  "SHELLBASE_PROJECT_ROOT"
  "SHELLBASE_BIN_DIR"
  "SHELLBASE_CACHE_DIR"
  "SHELLBASE_CONFIG_DIR"
)

for var in "${check_vars[@]}"; do
  if bash -c "source ~/.bashrc.d/04-system-env.sh && [ -n \"\${$var+x}\" ]"; then
    test_pass "$var is set"
  else
    test_fail "$var is not set"
  fi
done

# Test 5: Check paths are valid directories
echo "[5/8] Checking path validity..."
path_vars=(
  "SHELLBASE_USER_HOME"
  "SHELLBASE_BIN_DIR"
  "SHELLBASE_CACHE_DIR"
  "SHELLBASE_CONFIG_DIR"
)

for var in "${path_vars[@]}"; do
  if bash -c "source ~/.bashrc.d/04-system-env.sh && [ -d \"\${$var}\" ]"; then
    test_pass "$var is a valid directory"
  else
    test_fail "$var is not a valid directory"
  fi
done

# Test 6: Check SHELLBASE_REPO_DIR
echo "[6/8] Checking repository directory..."
if bash -c "source ~/.bashrc.d/04-system-env.sh && [ -d \"\$SHELLBASE_REPO_DIR\" ]"; then
  test_pass "SHELLBASE_REPO_DIR is a valid directory"
else
  test_warn "SHELLBASE_REPO_DIR not found (may not be installed yet)"
fi

# Test 7: Check for user override
echo "[7/8] Checking user override..."
if [ -f "$HOME/.shellbase-system.env" ]; then
  test_pass "User override exists at ~/.shellbase-system.env"

  # Check if user override would be loaded
  if bash -c "source ~/.bashrc.d/04-system-env.sh && [ \"\$SHELLBASE_ENV_SOURCE\" = \"user\" ]"; then
    test_pass "User override is being used (SHELLBASE_ENV_SOURCE=user)"
  else
    test_warn "User override exists but template or defaults are being used"
  fi
else
  test_warn "User override not found (using template or defaults)"
fi

# Test 8: Check .gitignore
echo "[8/8] Checking .gitignore..."
if [ -f "$HOME/IdeaProjects/shellbase/.gitignore" ]; then
  if grep -q "\.shellbase-system.env" "$HOME/IdeaProjects/shellbase/.gitignore"; then
    test_pass ".shellbase-system.env is in .gitignore"
  else
    test_warn ".shellbase-system.env not found in .gitignore"
  fi
else
  test_warn ".gitignore not found (may not be installed yet)"
fi

# Summary
echo
echo "=== Test Summary ==="
echo -e "${GREEN}Passed: $pass${NC}"
echo -e "${YELLOW}Warnings: $warn${NC}"
echo -e "${RED}Failed: $fail${NC}"
echo

if [ $fail -eq 0 ]; then
  echo "System environment configuration is working correctly!"
  exit 0
else
  echo "Some tests failed. Please check the output above."
  exit 1
fi
