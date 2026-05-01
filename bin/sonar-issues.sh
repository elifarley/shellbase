#!/bin/bash
# sonar-issues.sh — Fetch, group, and triage SonarQube issues for a project or PR.
#
# Designed for *triage*, not browsing: fetches all matching issues (paginated),
# then groups them so you can fix root causes instead of symptoms. A wall of
# 14 findings usually collapses to 4-5 rule clusters; one design fix per
# cluster typically beats fixing 14 individual lines.
#
# Usage: sonar-issues.sh [OPTIONS] [PROJECT_KEY]
#
# OPTIONS:
#   -p, --pr [NUM]       PR number. With no NUM, auto-detects via `gh pr view`.
#   -b, --branch NAME    Branch name (alternative to --pr).
#   -s, --status LIST    Comma-separated; default: OPEN,CONFIRMED,REOPENED.
#                        Pass 'all' to disable status filter.
#   -S, --severity LIST  BLOCKER,CRITICAL,MAJOR,MINOR,INFO  (comma-separated).
#   -T, --type LIST      BUG,VULNERABILITY,CODE_SMELL       (comma-separated).
#   -g, --group-by FLD   rule (default) | file | dir | severity | type | author
#   -f, --format FMT     summary (default) | plan | md | csv | json | raw
#   -l, --limit N        Page size (default 500, SonarQube hard max).
#       --hotspots       Fetch Security Hotspots instead of Issues.
#   -G, --gate           Prepend Quality Gate status (pass/fail conditions with
#                        actual values vs thresholds). Shows duplication %,
#                        coverage %, issue count — metrics absent from the
#                        issues endpoint. Automatically drills into failing
#                        metrics: shows which files are duplicated and which
#                        blocks are paired, or which files lack coverage.
#                        Composes with any --format.
#   -v, --verbose        Print API URLs to stderr.
#       --explain [RULE] Print canonical advice for a Sonar rule key
#                        (S125, java:S125, S1134, S1135). With no RULE,
#                        lists every rule with recorded advice. Pure
#                        docs lookup — no API call, no project key, no
#                        Sonar credentials required. See RULE GUIDANCE.
#   -h, --help           Show this help.
#
# ENVIRONMENT:
#   SONAR_HOST_URL       SonarQube base URL (no trailing slash).
#   SONAR_TOKEN          API token. Sent as HTTP Basic auth (token in user field).
#   SONAR_PROJECT_KEY    Default project key (CLI arg overrides).
#
# AUTO-DISCOVERY (when PROJECT_KEY arg + env are both empty):
#   Reads `sonar.projectKey` from ./sonar-project.properties in CWD.
#
# KEY RESOLUTION:
#   Short keys (e.g., "finpsti-dict" from sonar-project.properties) are
#   automatically resolved to the full org-prefixed form (e.g.,
#   "buildersbank_finpsti-dict") that SonarQube requires internally.
#   Just `cd` into your repo — you never need to know the full key.
#
# OUTPUT FORMATS:
#   summary  Compact human-readable counts grouped by --group-by.
#   plan     Actionable fix plan: one entry per rule cluster with sample
#            file:line locations and a recommended action verb.
#   md       Markdown table — paste straight into a PR comment.
#   csv      CSV with header — feed into a spreadsheet.
#   json     Compact JSON of grouped data — feed into downstream tooling.
#   raw      Pretty JSON of every raw issue (no grouping).
#
# EXAMPLES:
#   sonar-issues.sh --pr --gate -f plan           # recommended: full triage
#   sonar-issues.sh --pr                          # auto-detect PR via gh
#   sonar-issues.sh                              # CWD project, default filters
#   sonar-issues.sh myorg_myproj --pr 42 -f plan  # explicit key + PR
#   sonar-issues.sh -f md > findings.md           # paste into PR
#   sonar-issues.sh -f json | jq '.[] | select(.count > 3)'
#
# TOKEN SETUP:
#   1. SonarQube → My Account → Security → Generate Token (type: User Token).
#   2. Minimum permissions (sufficient for --gate + issue queries):
#        "Execute Analysis" on target projects.
#   3. For full --gate drilldown (file-level duplication + coverage detail):
#        also grant "Browse" on target projects
#        (Project Settings → Permissions → Browse).
#
# RULE GUIDANCE:
#   This script ships a small registry of canonical advice for Sonar
#   rules with non-obvious handling — false-positive-prone rules, rules
#   the registry recommends disabling, etc. Query it with --explain:
#     sonar-issues.sh --explain S125    # advice for java:S125
#     sonar-issues.sh --explain S1134   # FIXME / TODO recommendation
#     sonar-issues.sh --explain         # list all rules with advice
#   Designed for both humans ("what was that suppression syntax again?")
#   and agents ("how should I handle this rule?"). Extend by adding a
#   `_explain_<KEY>` function plus one case clause — both grep-able from
#   `_explain_` so the next contributor can find the convention without
#   reading docs.
#
# EXIT CODES:
#   0  Success (issues found OR none — both are valid outcomes).
#   1  Usage error (bad flag, missing project key).
#   2  API or auth error.

set -e
set -u
set -o pipefail

# ---------- defaults ----------
PR=""
BRANCH=""
STATUSES="OPEN,CONFIRMED,REOPENED"
SEVERITIES=""
TYPES=""
GROUP_BY="rule"
FORMAT="summary"
PAGE_SIZE=500
ENDPOINT="issues/search"   # vs hotspots/search
VERBOSE=0
SHOW_GATE=0                # --gate: prepend Quality Gate conditions before issues
EXPLAIN=""                 # --explain: rule-key lookup mode (bypasses API + env)
PROJECT_KEY="${SONAR_PROJECT_KEY:-}"

# ---------- colors (TTY only) ----------
if [ -t 1 ]; then
  C_BOLD='\033[1m'; C_DIM='\033[2m'; C_RED='\033[0;31m'
  C_YEL='\033[0;33m'; C_CYA='\033[0;36m'; C_RST='\033[0m'
else
  C_BOLD=''; C_DIM=''; C_RED=''; C_YEL=''; C_CYA=''; C_RST=''
fi

# ---------- helpers ----------
# WHY `%b` for colors (not embedded `${C_RED}…` in format strings): shellcheck
# SC2059 flags the latter as a tainted-format-string risk, and rightly so —
# if any color var ever held `%s`, printf would consume the next arg out of
# order. `%b` interprets ANSI escapes from a data argument, keeping the
# format string a constant. Boring, safe, and the formatter knows what's data.
#
# GOTCHA: use "$1" (not "$*") for the message. This function takes TWO args
# with distinct semantics (message + optional exit code); $* would join them
# with IFS-spaces, so `die "msg" 1` would print "msg 1" — the exit code
# bleeding into the displayed text. Lifted-from-classic-shell trap: the
# `die() { echo "$*"; exit 1; }` idiom is fine only when the function takes
# a single semantic concept. Add a second positional arg, switch to "$1".
die() { printf '%berror:%b %s\n' "$C_RED" "$C_RST" "$1" >&2; exit "${2:-1}"; }
note() {
  if [ "$VERBOSE" = 1 ]; then
    printf '%b%s%b\n' "$C_DIM" "$*" "$C_RST" >&2
  fi
}
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

# WHY 5..1 spacing (not 100..1 or arbitrary): these weights feed the leverage
# sort below as `weight * 1000 + count`. The 1000 multiplier guarantees
# severity strictly dominates count up to 999 issues per cluster — a single
# BLOCKER (5000) always outranks 999 MINORs (1999). If you ever expect
# >999 issues per cluster, raise the multiplier to keep the invariant.
severity_weight() {
  case "$1" in
    BLOCKER)  echo 5 ;;
    CRITICAL) echo 4 ;;
    MAJOR)    echo 3 ;;
    MINOR)    echo 2 ;;
    INFO)     echo 1 ;;
    *)        echo 0 ;;
  esac
}

severity_color() {
  case "$1" in
    BLOCKER|CRITICAL) printf "%b" "$C_RED" ;;
    MAJOR)            printf "%b" "$C_YEL" ;;
    MINOR|INFO)       printf "%b" "$C_DIM" ;;
    *)                printf "" ;;
  esac
}

# ---------- rule registry (--explain) ----------
# WHY function-per-rule (not an associative array of strings): each entry
# is multi-line prose with sub-sections (When it triggers / Why it
# misfires / Canonical fix). Heredocs handle that cleanly; quoted array
# values would force escape-sequence noise. Adding a rule = write a
# `_explain_<KEY>` function + add one clause to the dispatcher's case —
# both grep-able from `_explain_` so the convention is self-discovering.
#
# WHY canonical keys carry the `java:` prefix (not bare `S125`): Sonar
# rule keys are language-namespaced — java:S125, csharpsquid:S125 and
# python:S125 are three different rules with different remediations.
# Storing the qualified key keeps us right when polyglot rules are added.
# The dispatcher accepts shorthand (S125, s125, java:S125, Java:s125)
# and normalizes by uppercasing then prepending `java:` — Java is the
# only analyzer this registry currently covers.

_explain_section() { printf '\n  %b%s%b\n' "$C_BOLD" "$1" "$C_RST"; }

_explain_S125() {
  printf '%bjava:S125%b — CommentedOutCodeLine\n' "$C_BOLD" "$C_RST"
  _explain_section "When it triggers:"
  cat <<'EOF'
    Sonar interprets lines containing Java tokens (operators, keywords,
    semicolons) inside comments as commented-out code that should be
    deleted.
EOF
  _explain_section "Why it often misfires:"
  cat <<'EOF'
    Explanatory comments — Javadoc snippets, illustrative pseudocode,
    TODO context, before/after examples — frequently look like code to
    the heuristic. The signal-to-noise ratio is poor in practice.
EOF
  _explain_section "Canonical fix (preferred → fallback):"
  cat <<'EOF'
    1. @SuppressWarnings("java:S125") on the enclosing declaration
       (class / method / field). One annotation silences the whole
       scope, is grep-able for periodic audit, documents intent at the
       unit boundary, and is visible to IDE inspections.
    2. //NOSONAR at the end of an individual line. Use only when an
       annotation would be overkill (truly one-off). Drawback: doesn't
       name the rule being silenced, so future readers can't tell what
       was disabled or why.
EOF
}

# S1134 (FIXME) and S1135 (TODO) share the same recommendation, so the
# dispatcher routes both keys to one explanation.
_explain_S1134_S1135() {
  printf '%bjava:S1134 / java:S1135%b — FIXME / TODO tag detection\n' \
    "$C_BOLD" "$C_RST"
  _explain_section "Recommendation: keep these markers in code."
  cat <<'EOF'
    FIXME and TODO are how a developer (or an agent) hands context to
    the next person who touches the code. They are trivially grep-able
    and easier to act on than the absence of a marker — almost always
    better to keep than to drop. Sonar treats them as code smells; the
    recommendation here is to disable the rules at the Quality Profile
    level rather than suppress them per-occurrence.
EOF
  _explain_section "Canonical fix (in order):"
  cat <<'EOF'
    1. (Org/team admin, one-time) Disable java:S1134 and java:S1135 in
       the active SonarQube Quality Profile:
         Quality Profiles → <profile> → search S1134 / S1135 →
         Activation → Deactivate.
       Applies to every project sharing the profile — most durable fix,
       removes the warnings everywhere with no per-occurrence noise.
    2. (Per-occurrence, until the profile change is in place)
       @SuppressWarnings({"java:S1134","java:S1135"}) on the enclosing
       declaration, OR //NOSONAR at the end of the marker line.
EOF
}

_explain_unknown() {
  local rule="$1"
  printf '%b%s%b — no canonical advice recorded yet.\n\n' \
    "$C_BOLD" "$rule" "$C_RST"
  printf '  Look it up in SonarQube:\n'
  if [ -n "${SONAR_HOST_URL:-}" ]; then
    printf '    %s/coding_rules?open=%s\n' "$SONAR_HOST_URL" "$rule"
  else
    printf '    <SONAR_HOST_URL>/coding_rules?open=%s\n' "$rule"
  fi
  printf '\n  To add canonical advice, edit the rule registry in:\n'
  printf '    %s\n' "$0"
  printf '  (write a _explain_<KEY> function + add one case clause to explain_rule).\n'
}

_explain_list() {
  printf '%bSonar rules with canonical advice:%b\n\n' "$C_BOLD" "$C_RST"
  cat <<'EOF'
  java:S125    CommentedOutCodeLine — false-positive prone
  java:S1134   FIXME tag (recommendation: keep)
  java:S1135   TODO tag  (recommendation: keep)

  Use `--explain RULE` for canonical guidance.
  RULE may be the bare key (S125), lowercase (s125), or fully
  qualified (java:S125) — all are normalized.
EOF
}

# Normalize input → canonical `java:S<NNN>` then dispatch.
explain_rule() {
  local raw="$1" normalized

  if [ "$raw" = "list" ]; then
    _explain_list
    return 0
  fi

  # Uppercase first, then ensure the `java:` prefix. Two-step keeps the
  # case-fold and the prefix-fixup orthogonal — easier to extend if a
  # second analyzer (e.g. `python:`) is ever supported.
  normalized=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]')
  case "$normalized" in
    JAVA:*) normalized="java:${normalized#JAVA:}" ;;
    S*)     normalized="java:${normalized}" ;;
  esac

  case "$normalized" in
    java:S125)             _explain_S125 ;;
    java:S1134|java:S1135) _explain_S1134_S1135 ;;
    *)                     _explain_unknown "$normalized" ;;
  esac
}

# ---------- arg parsing ----------
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--pr)
      shift
      # GOTCHA: --pr accepts an OPTIONAL value (rare for getopt-style parsers).
      # `${1#-}` strips a leading dash; if the result equals $1, the next arg
      # does NOT start with `-` and is therefore the PR number. Otherwise it's
      # the next flag (or missing) and we fall through to auto-detect mode.
      # POSIX-portable — works without `getopts -:` extensions.
      if [ $# -gt 0 ] && [ "${1#-}" = "$1" ] && [ -n "$1" ]; then
        PR="$1"; shift
      else
        PR="auto"
      fi ;;
    -b|--branch)   BRANCH="$2"; shift 2 ;;
    -s|--status)   STATUSES="$2"; shift 2 ;;
    -S|--severity) SEVERITIES="$2"; shift 2 ;;
    -T|--type)     TYPES="$2"; shift 2 ;;
    -g|--group-by) GROUP_BY="$2"; shift 2 ;;
    -f|--format)   FORMAT="$2"; shift 2 ;;
    -l|--limit)    PAGE_SIZE="$2"; shift 2 ;;
    --hotspots)    ENDPOINT="hotspots/search"; shift ;;
    -G|--gate)     SHOW_GATE=1; shift ;;
    -v|--verbose)  VERBOSE=1; shift ;;
    --explain)
      shift
      # Same optional-value idiom as --pr (see comment there): the next
      # arg is the value unless it starts with `-` or is missing/empty;
      # bare `--explain` (no value) becomes the sentinel "list" so the
      # dispatcher prints the rule index.
      if [ $# -gt 0 ] && [ "${1#-}" = "$1" ] && [ -n "$1" ]; then
        EXPLAIN="$1"; shift
      else
        EXPLAIN="list"
      fi ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; break ;;
    -*)            die "unknown option: $1" 1 ;;
    *)             PROJECT_KEY="$1"; shift ;;
  esac
done

# ---------- --explain short-circuit ----------
# WHY this lives BEFORE env validation: --explain is a pure documentation
# lookup — no API calls, no project key, no Sonar credentials needed. Run
# and exit before the `:?` checks below so it works in any directory and
# from any shell, including for someone who hasn't set up Sonar at all
# yet (e.g. a new joiner reading the source to learn how the org handles
# rule X). Putting this AFTER validation would silently force every
# --explain call to require SONAR_HOST_URL + SONAR_TOKEN, defeating the
# point of a docs lookup.
if [ -n "$EXPLAIN" ]; then
  explain_rule "$EXPLAIN"
  exit 0
fi

# ---------- validation ----------
# WHY `: "${VAR:?msg}"` idiom: the `:` is the no-op builtin; bash evaluates the
# parameter expansion for its side effect. `:?` aborts the script with `msg`
# on stderr and a non-zero exit if VAR is unset OR empty. Cleanest fail-fast
# for required env vars — no `if [ -z … ]` boilerplate, no double-message risk.
: "${SONAR_HOST_URL:?SONAR_HOST_URL not set (e.g. https://sonarqube.example.com)}"
# WHY inline the URL: when this fires, the user has no token at all — they need
# to know WHERE to create one, not just THAT they need one. $SONAR_HOST_URL is
# already validated above, so the expansion is safe.
: "${SONAR_TOKEN:?SONAR_TOKEN not set — generate at ${SONAR_HOST_URL}/account/security (see --help TOKEN SETUP)}"

# Project key auto-discovery from sonar-project.properties.
if [ -z "$PROJECT_KEY" ] && [ -f sonar-project.properties ]; then
  PROJECT_KEY=$(awk -F= '/^sonar\.projectKey=/{print $2; exit}' sonar-project.properties | tr -d ' ')
  note "auto-detected project key from sonar-project.properties: $PROJECT_KEY"
fi
[ -n "$PROJECT_KEY" ] || die "PROJECT_KEY required (arg, \$SONAR_PROJECT_KEY, or sonar-project.properties)" 1

# PR auto-detection via gh.
if [ "$PR" = "auto" ]; then
  command -v gh >/dev/null 2>&1 || die "--pr (without number) needs the 'gh' CLI" 1
  PR=$(gh pr view --json number --jq .number 2>/dev/null) || \
    die "could not auto-detect PR from current branch (no PR open?)" 1
  note "auto-detected PR: #$PR"
fi

# INVARIANT: at most one of {pullRequest, branch} is sent to SonarQube.
# Sonar models a PR and a branch as DIFFERENT codebases (different scopes,
# different new-code definitions). Sending both yields silent precedence
# behavior that varies by Sonar version — rejecting here surfaces the bug
# at call site instead of producing mysteriously empty results.
if [ -n "$PR" ] && [ -n "$BRANCH" ]; then
  die "--pr and --branch are mutually exclusive" 1
fi

case "$GROUP_BY" in rule|file|dir|severity|type|author) ;; *)
  die "invalid --group-by '$GROUP_BY' (rule|file|dir|severity|type|author)" 1 ;;
esac
case "$FORMAT" in summary|plan|md|csv|json|raw) ;; *)
  die "invalid --format '$FORMAT' (summary|plan|md|csv|json|raw)" 1 ;;
esac

# ---------- project key resolution ----------
# WORKAROUND: SonarQube's API endpoints disagree on which project key formats
# they accept. The issues/search endpoint (componentKeys param) sometimes
# tolerates short keys like "finpsti-dict", but qualitygates/project_status
# (projectKey param) REQUIRES the full org-prefixed key like
# "buildersbank_finpsti-dict". In practice, some Sonar instances also reject
# short keys on issues/search, making all operations silently return 0 results.
#
# This early-resolve step canonicalizes PROJECT_KEY BEFORE any API calls, so
# all endpoints (issues, hotspots, qualitygates) use the same validated key.
# Discovered 2026-04 on SonarQube CE 10.x.
#
# DECISION: probe with api/components/show (lightweight, single-component
# lookup) rather than jumping straight to search. If the key is already valid,
# this is one cheap call and we skip resolution entirely. The search fallback
# only fires for short/ambiguous keys.
# DECISION: probe via qualitygates (not components/show) because components/show
# may return "Insufficient privileges" even for valid keys — the token's
# permissions for component browsing can differ from analysis permissions.
# qualitygates/project_status is the authoritative endpoint we actually need,
# so probing against it tests exactly what matters.
_probe_key() {
  local key="$1"
  local query="projectKey=${key}"
  # WHY include PR/branch in probe: a key can exist in Sonar but have no data
  # for this specific PR. Including the scope catches both "key not found" AND
  # "PR not found in this project" — both mean this candidate is wrong.
  [ -n "$PR" ]     && query+="&pullRequest=${PR}"
  [ -n "$BRANCH" ] && query+="&branch=${BRANCH}"
  local url="${SONAR_HOST_URL}/api/qualitygates/project_status?${query}"
  note "probing project key: $key"
  local body
  body=$(curl -sS -u "${SONAR_TOKEN}:" "$url" 2>/dev/null) || return 1
  echo "$body" | jq -e '.projectStatus.status' >/dev/null 2>&1
}

_resolve_project_key() {
  # Fast path: key already valid (full org-prefixed form, or Sonar version
  # that resolves short keys). Skip the search entirely.
  if _probe_key "$PROJECT_KEY"; then
    return 0
  fi

  note "key '${PROJECT_KEY}' not found — attempting auto-resolution via component search"

  local search_url="${SONAR_HOST_URL}/api/components/search?qualifiers=TRK&q=${PROJECT_KEY}"
  note "GET $search_url"
  local search_body
  search_body=$(curl -sS -u "${SONAR_TOKEN}:" "$search_url") || \
    die "Component search failed (curl error)" 2

  # WHY exact match on BOTH .name and .key: the search API is substring-based,
  # so querying "finpsti-dict" also returns "finpsti-dict-out-api" etc.
  # Matching .name handles the short-key case (sonar-project.properties value).
  # Matching .key handles the full-key case (user passes "buildersbank_finpsti-dict"
  # but the probe failed due to missing PR scope or permissions).
  local candidates
  candidates=$(echo "$search_body" | \
    jq -r --arg q "$PROJECT_KEY" '[.components[] | select(.name == $q or .key == $q) | .key] | unique | .[]')

  if [ -z "$candidates" ]; then
    die "No SonarQube project found matching '${PROJECT_KEY}'. Verify the project exists." 2
  fi

  local count
  count=$(echo "$candidates" | wc -l)

  if [ "$count" -eq 1 ]; then
    # Unambiguous: single exact match.
    PROJECT_KEY="$candidates"
    note "resolved project key: $PROJECT_KEY"
    return 0
  fi

  # Multiple candidates — need a tiebreaker.
  # DECISION: try each candidate against the qualitygates API with PR/branch
  # scope. Only the correct project will have a matching PR. This is more
  # reliable than heuristics like "key contains short name as suffix" because
  # org naming conventions vary (underscores, colons, dots).
  if [ -n "$PR" ] || [ -n "$BRANCH" ]; then
    local candidate
    while IFS= read -r candidate; do
      local query="projectKey=${candidate}"
      [ -n "$PR" ]     && query+="&pullRequest=${PR}"
      [ -n "$BRANCH" ] && query+="&branch=${BRANCH}"
      local url="${SONAR_HOST_URL}/api/qualitygates/project_status?${query}"
      note "trying candidate: $candidate"
      local body
      body=$(curl -sS -u "${SONAR_TOKEN}:" "$url" 2>/dev/null) || continue
      if echo "$body" | jq -e '.projectStatus.status' >/dev/null 2>&1; then
        PROJECT_KEY="$candidate"
        note "resolved project key: $PROJECT_KEY (matched PR/branch scope)"
        return 0
      fi
    done <<< "$candidates"
  fi

  # No PR/branch to tiebreak — fall back to the candidate whose key ends with
  # the short name. This handles the common "org_project" and "org:project"
  # patterns without hardcoding a specific separator.
  local candidate
  while IFS= read -r candidate; do
    # WHY case/esac glob (not grep/regex): pure bash, no subprocess, and the
    # *SHORT_KEY pattern matches both "buildersbank_finpsti-dict" and
    # "tech.finaya:finpsti-dict" for short key "finpsti-dict".
    case "$candidate" in
      *"$PROJECT_KEY") PROJECT_KEY="$candidate"
                       note "resolved project key: $PROJECT_KEY (suffix match)"
                       return 0 ;;
    esac
  done <<< "$candidates"

  # Last resort: use the first candidate and warn.
  PROJECT_KEY=$(echo "$candidates" | head -1)
  note "WARNING: multiple matches, using first candidate: $PROJECT_KEY"
}

_resolve_project_key

# ---------- Quality Gate (--gate / -G) ----------
# WHY a separate function (not baked into fetch_all): Quality Gate status lives
# at a different API endpoint (qualitygates/project_status) and has completely
# different semantics — it returns pass/fail conditions with metric values and
# thresholds, not individual issues. Mixing it into the issue pipeline would
# couple unrelated data flows. Instead, --gate is an additive flag that
# prepends gate status BEFORE the normal issue output. This means it composes
# freely with any --format: `--gate -f plan` shows gate conditions + fix plan.
#
# WHY this is invaluable for triage: the issues endpoint shows WHAT's wrong,
# but the Quality Gate shows WHETHER the PR is blocked and by which metrics.
# Duplication % and coverage % only appear in the gate — they aren't "issues"
# at all. Without --gate, you'd need to open the SonarQube web UI or manually
# curl the qualitygates API to find out why a PR is red.
# PROJECT_KEY is already canonicalized by _resolve_project_key above.
# fetch_gate just makes the API call — no resolution needed.
fetch_gate() {
  local query="projectKey=${PROJECT_KEY}"
  [ -n "$PR" ]     && query+="&pullRequest=${PR}"
  [ -n "$BRANCH" ] && query+="&branch=${BRANCH}"

  local url="${SONAR_HOST_URL}/api/qualitygates/project_status?${query}"
  note "GET $url"
  local body
  body=$(curl -sS --fail-with-body -u "${SONAR_TOKEN}:" "$url") || \
    die "Quality Gate API failed. Body: $body" 2

  if echo "$body" | jq -e '.errors' >/dev/null 2>&1; then
    die "Quality Gate API error: $body" 2
  fi
  echo "$body"
}

# Color-code a gate condition status.
gate_status_color() {
  case "$1" in
    OK)    printf "%b" "$C_CYA" ;;
    ERROR) printf "%b" "$C_RED" ;;
    WARN)  printf "%b" "$C_YEL" ;;
    *)     printf "" ;;
  esac
}

# Human-readable metric names. SonarQube returns machine keys like
# "new_duplicated_lines_density" — triage output should speak human.
# Only map the common Quality Gate metrics; unknown keys pass through.
metric_label() {
  case "$1" in
    new_duplicated_lines_density) echo "Duplicated Lines (new code)" ;;
    new_coverage)                 echo "Coverage (new code)" ;;
    new_violations)               echo "Issues (new code)" ;;
    new_reliability_rating)       echo "Reliability Rating (new code)" ;;
    new_security_rating)          echo "Security Rating (new code)" ;;
    new_maintainability_rating)   echo "Maintainability Rating (new code)" ;;
    new_security_hotspots_reviewed) echo "Security Hotspots Reviewed (new code)" ;;
    *)                            echo "$1" ;;
  esac
}

# Human-readable comparators ("GT" → ">", "LT" → "<").
comparator_symbol() {
  case "$1" in
    GT) echo ">" ;; LT) echo "<" ;; EQ) echo "=" ;; NE) echo "≠" ;;
    *)  echo "$1" ;;
  esac
}

format_gate() {
  local gate_json="$1"
  local status
  status=$(echo "$gate_json" | jq -r '.projectStatus.status')

  local status_color
  status_color=$(gate_status_color "$status")
  printf '\n%b━━ Quality Gate: %b%s%b ━━%b\n\n' \
    "$C_BOLD" "$status_color" "$status" "$C_RST" "$C_RST"

  # Iterate conditions and show each metric with its actual vs threshold.
  # WHY jq -c piped to read (not jq -r with tab delimiters): condition
  # values can be floating-point or integer, and some metrics have no
  # errorThreshold. Passing compact JSON per line and extracting fields
  # individually is more robust than tab-splitting heterogeneous types.
  echo "$gate_json" | jq -c '.projectStatus.conditions[]' | while IFS= read -r cond; do
    local cond_status metric actual threshold comparator label symbol color
    cond_status=$(echo "$cond" | jq -r '.status')
    metric=$(echo "$cond" | jq -r '.metricKey')
    actual=$(echo "$cond" | jq -r '.actualValue')
    threshold=$(echo "$cond" | jq -r '.errorThreshold')
    comparator=$(echo "$cond" | jq -r '.comparator')

    label=$(metric_label "$metric")
    symbol=$(comparator_symbol "$comparator")
    color=$(gate_status_color "$cond_status")

    # Format: ✓/✗ icon + metric label + actual value + threshold.
    # WHY include the threshold: knowing "5.17% > 3%" is far more actionable
    # than just "5.17% FAIL" — you know exactly how far you need to reduce.
    local icon="✓"
    [ "$cond_status" != "OK" ] && icon="✗"
    printf '  %b%s  %-40s  %s  (threshold: %s %s)%b\n' \
      "$color" "$icon" "$label" "$actual" "$symbol" "$threshold" "$C_RST"
  done
  echo
}

# ---------- Quality Gate drilldown (auto on failure) ----------
# WHY auto-drilldown (not a separate flag): if you asked --gate and a metric
# failed, you obviously want to know WHY — which files, which blocks. Adding
# a --gate-detail flag would mean every triage invocation becomes
# `--gate --gate-detail` — pointless ceremony. The extra API calls only fire
# on failing conditions, so passing gates add zero overhead.

# Generic fetcher for the measures/component_tree API.
# Returns components sorted descending by $sort_metric so the worst offenders
# appear first. Caller picks the metrics and display logic.
#
# WHY no --fail-with-body / no die: drilldowns are best-effort enhancements.
# We return the raw response (including error JSON like "Insufficient privileges")
# so the caller can show a helpful fallback instead of aborting the script.
# Compare with fetch_gate / fetch_all which ARE critical path and rightly die.
fetch_component_tree() {
  local metrics="$1" sort_metric="$2" max_results="${3:-10}"
  local query="component=${PROJECT_KEY}&metricKeys=${metrics}"
  query+="&s=metric&metricSort=${sort_metric}&metricSortFilter=withMeasuresOnly&asc=false"
  query+="&ps=${max_results}"
  [ -n "$PR" ]     && query+="&pullRequest=${PR}"
  [ -n "$BRANCH" ] && query+="&branch=${BRANCH}"

  local url="${SONAR_HOST_URL}/api/measures/component_tree?${query}"
  note "GET $url"
  curl -sS -u "${SONAR_TOKEN}:" "$url" 2>/dev/null || echo "{}"
}

# Fetch block-level duplication pairs for a single component.
# Returns the raw duplications/show JSON — caller parses the block pairs.
# Same best-effort pattern as fetch_component_tree (no die on error).
fetch_duplications() {
  local component_key="$1"
  local query="key=${component_key}"
  [ -n "$PR" ]     && query+="&pullRequest=${PR}"
  [ -n "$BRANCH" ] && query+="&branch=${BRANCH}"

  local url="${SONAR_HOST_URL}/api/duplications/show?${query}"
  note "GET $url"
  curl -sS -u "${SONAR_TOKEN}:" "$url" 2>/dev/null || echo "{}"
}

# Build a SonarQube web UI URL for manual inspection when APIs fail.
# Deterministic URL construction — works for any Sonar CE/EE instance.
_sonar_web_url() {
  local metric="$1" scope=""
  [ -n "$PR" ]     && scope="&pullRequest=${PR}"
  [ -n "$BRANCH" ] && scope="&branch=${BRANCH}"
  printf '%s/component_measures?id=%s%s&metric=%s' \
    "$SONAR_HOST_URL" "$PROJECT_KEY" "$scope" "$metric"
}

drilldown_duplication() {
  local tree_json
  tree_json=$(fetch_component_tree \
    "duplicated_blocks,duplicated_lines,duplicated_lines_density" \
    "duplicated_lines_density" 10)

  # Best-effort: if the API returned an error (typically "Insufficient
  # privileges" — the token needs Browse permission on the project), show
  # a clickable web URL so the user can inspect duplication in the Sonar UI.
  if echo "$tree_json" | jq -e '.errors' >/dev/null 2>&1; then
    printf '  %bDuplication drilldown unavailable%b (token lacks Browse permission)\n' "$C_DIM" "$C_RST"
    printf '  %bGrant at: Project Settings → Permissions → Browse%b\n' "$C_DIM" "$C_RST"
    printf '  View in SonarQube: %s\n\n' "$(_sonar_web_url new_duplicated_lines_density)"
    return 0
  fi

  local count
  count=$(echo "$tree_json" | jq '.components | length // 0' 2>/dev/null)
  [ "${count:-0}" -eq 0 ] && return 0

  printf '  %bDuplication drilldown (top offenders):%b\n' "$C_BOLD" "$C_RST"

  # WHY `head -5` (not all components): each component triggers a
  # duplications/show API call. Capping at 5 keeps the drilldown fast while
  # still surfacing the worst offenders. The component_tree is already sorted
  # by density descending, so the first 5 are the most impactful to fix.
  echo "$tree_json" | jq -c '.components[]' | head -5 | while IFS= read -r comp; do
    local comp_key name dup_lines dup_blocks
    comp_key=$(echo "$comp" | jq -r '.key')
    name=$(echo "$comp" | jq -r '.key | sub("^[^:]+:"; "")')
    dup_lines=$(echo "$comp" | jq -r '[.measures[] | select(.metric == "duplicated_lines") | .value] | first // "0"')
    dup_blocks=$(echo "$comp" | jq -r '[.measures[] | select(.metric == "duplicated_blocks") | .value] | first // "0"')

    [ "$dup_lines" = "0" ] && continue

    printf '    %b%s%b   %s dup line(s), %s block(s)\n' \
      "$C_CYA" "$name" "$C_RST" "$dup_lines" "$dup_blocks"

    # Fetch paired-block details for this file (also best-effort — if Browse
    # was granted for component_tree, duplications/show usually works too,
    # but if it doesn't, the file-level summary above is still useful).
    local dup_json
    dup_json=$(fetch_duplications "$comp_key")
    echo "$dup_json" | jq -e '.errors' >/dev/null 2>&1 && continue

    # Parse duplication groups: for each group, find the block belonging to this
    # component (self) and show the other side(s) as "self range ≈ other range".
    # WHY sort -u at the end: the duplications API can return the same pair from
    # both directions (A≈B and B≈A); dedup keeps output clean.
    echo "$dup_json" | jq -c --arg self "$comp_key" '
      (.files // {}) as $files |
      (.duplications // [])[]? | .blocks as $all_blocks |
      ($all_blocks | to_entries | map(select(($files[.value._ref].key // "") == $self)) | .[0]) as $self_entry |
      if $self_entry then
        $all_blocks | to_entries | map(select(.key != $self_entry.key)) | .[] |
        {
          self_from:  $self_entry.value.from,
          self_to:    ($self_entry.value.from + $self_entry.value.size - 1),
          other_file: (($files[.value._ref].key // "?") | sub("^[^:]+:"; "")),
          other_from: .value.from,
          other_to:   (.value.from + .value.size - 1)
        }
      else empty end
    ' 2>/dev/null | sort -u | while IFS= read -r pair; do
      local sf st of ofrom ot
      sf=$(echo "$pair" | jq -r '.self_from')
      st=$(echo "$pair" | jq -r '.self_to')
      of=$(echo "$pair" | jq -r '.other_file')
      ofrom=$(echo "$pair" | jq -r '.other_from')
      ot=$(echo "$pair" | jq -r '.other_to')
      printf '      %bL%s–%s  ≈  %s L%s–%s%b\n' \
        "$C_DIM" "$sf" "$st" "$of" "$ofrom" "$ot" "$C_RST"
    done
  done
  echo
}

drilldown_coverage() {
  local tree_json
  tree_json=$(fetch_component_tree \
    "uncovered_lines,line_coverage,lines_to_cover" \
    "uncovered_lines" 10)

  if echo "$tree_json" | jq -e '.errors' >/dev/null 2>&1; then
    printf '  %bCoverage drilldown unavailable%b (token lacks Browse permission)\n' "$C_DIM" "$C_RST"
    printf '  %bGrant at: Project Settings → Permissions → Browse%b\n' "$C_DIM" "$C_RST"
    printf '  View in SonarQube: %s\n\n' "$(_sonar_web_url new_coverage)"
    return 0
  fi

  local count
  count=$(echo "$tree_json" | jq '.components | length // 0' 2>/dev/null)
  [ "${count:-0}" -eq 0 ] && return 0

  printf '  %bCoverage drilldown (most uncovered):%b\n' "$C_BOLD" "$C_RST"

  echo "$tree_json" | jq -c '.components[]' | while IFS= read -r comp; do
    local name uncovered coverage to_cover
    name=$(echo "$comp" | jq -r '.key | sub("^[^:]+:"; "")')
    uncovered=$(echo "$comp" | jq -r '[.measures[] | select(.metric == "uncovered_lines") | .value] | first // "0"')
    coverage=$(echo "$comp" | jq -r '[.measures[] | select(.metric == "line_coverage") | .value] | first // "—"')
    to_cover=$(echo "$comp" | jq -r '[.measures[] | select(.metric == "lines_to_cover") | .value] | first // "—"')

    [ "$uncovered" = "0" ] && continue

    printf '    %b%s%b   %s uncovered of %s  (%s%% covered)\n' \
      "$C_CYA" "$name" "$C_RST" "$uncovered" "$to_cover" "$coverage"
  done
  echo
}

# Orchestrator: inspect each failing gate condition and auto-drill where a
# detail API exists. Metrics without a drilldown are silently skipped — the
# gate line already showed the value vs threshold; there's nothing more to add.
drilldown_gate_failures() {
  local gate_json="$1"

  local fail_count
  fail_count=$(echo "$gate_json" | jq '[.projectStatus.conditions[] | select(.status != "OK")] | length')
  [ "$fail_count" -eq 0 ] && return 0

  echo "$gate_json" | jq -r '.projectStatus.conditions[] | select(.status != "OK") | .metricKey' | \
  while IFS= read -r metric; do
    case "$metric" in
      new_duplicated_lines_density) drilldown_duplication ;;
      new_coverage)                 drilldown_coverage ;;
      # Future: add more metric drilldowns here as the need arises.
    esac
  done
}

# ---------- fetch (paginated) ----------
# DECISION: accumulate per page into a temp file (not `jq -s` over all bodies).
# Trade-off: one extra `jq` invocation per page, but (a) memory stays bounded
# at ~one page, (b) we can break early on first short page without wasting
# work, (c) failures show partial state. For a tool that's typically run
# against PRs (10–100 issues), this is invisible. For project-wide runs
# (10k cap), the difference is a few hundred ms — worth the safety.
fetch_all() {
  local page=1 total=0 fetched=0 tmp body
  # GOTCHA: `trap 'rm -f "$tmp"' EXIT` fires once at script end, even on die().
  # Don't reset the trap inside loops or the temp file leaks on early exit.
  tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT

  # WHY 'all' as a sentinel: SonarQube has no "all statuses" filter — the API
  # default IS the wide-open behavior. We just omit the param. The sentinel
  # gives callers a discoverable way to override our restrictive default.
  local query="componentKeys=${PROJECT_KEY}&ps=${PAGE_SIZE}"
  [ -n "$PR" ]                && query+="&pullRequest=${PR}"
  [ -n "$BRANCH" ]            && query+="&branch=${BRANCH}"
  [ "$STATUSES" != "all" ] && [ -n "$STATUSES" ] && query+="&statuses=${STATUSES}"
  [ -n "$SEVERITIES" ]        && query+="&severities=${SEVERITIES}"
  [ -n "$TYPES" ]             && query+="&types=${TYPES}"

  echo "[]" > "$tmp"
  while :; do
    local url="${SONAR_HOST_URL}/api/${ENDPOINT}?${query}&p=${page}"
    note "GET $url"
    # WHY --fail-with-body (not plain --fail): bare --fail discards the body
    # on 4xx/5xx, so you see only "HTTP error 401" with no clue. With
    # --fail-with-body, curl exits non-zero AND keeps the body, letting us
    # show SonarQube's actual error JSON ({"errors":[{"msg":"..."}]}).
    # Available since curl 7.76 (2021).
    #
    # WHY -u "${SONAR_TOKEN}:" : SonarQube uses HTTP Basic auth with the
    # token in the USERNAME field and an empty password. Counter-intuitive —
    # most APIs put tokens in `Authorization: Bearer`. Sonar predates that
    # convention. The trailing `:` is required (delimits empty password).
    body=$(curl -sS --fail-with-body -u "${SONAR_TOKEN}:" "$url") || \
      die "API call failed (HTTP error). Body: $body" 2

    # GOTCHA: issues/search returns `.issues`; hotspots/search returns
    # `.hotspots`. Same outer envelope (.paging.total etc), different key
    # for the actual records. Normalize before merging.
    local key=".issues"
    [ "$ENDPOINT" = "hotspots/search" ] && key=".hotspots"

    total=$(echo "$body" | jq -r '.paging.total // .total // 0')
    local count
    count=$(echo "$body" | jq "$key | length")
    fetched=$((fetched + count))

    # Append this page's items to the accumulator.
    jq --argjson new "$(echo "$body" | jq "$key")" '. + $new' "$tmp" > "${tmp}.new"
    mv "${tmp}.new" "$tmp"

    # Three independent termination conditions. Each guards against a
    # different failure mode of trusting just one:
    #   - count < PAGE_SIZE: normal end-of-results signal
    #   - fetched >= total: belt-and-suspenders (Sonar sometimes lies)
    #   - fetched >= 10000: WORKAROUND for the SonarQube hard cap. Past page
    #     20 (with ps=500) the API silently returns empty pages forever.
    #     Affects ALL Sonar versions through 2026-04. Mitigation for callers
    #     who actually need >10k: split the query by --severity or --type.
    [ "$count" -lt "$PAGE_SIZE" ] && break
    [ "$fetched" -ge "$total" ]   && break
    [ "$fetched" -ge 10000 ] && { note "hit SonarQube 10k cap"; break; }
    page=$((page + 1))
  done

  note "fetched $fetched / $total issues across $page page(s)"
  cat "$tmp"
}

# ---------- group + format (jq does the work) ----------
# WHY `sub("^[^:]+:"; "")`: SonarQube component IDs are formatted as
# "<projectKey>:<repo-relative-path>", e.g. "myorg_myproj:src/main/A.java".
# The projectKey prefix is identical for every issue in a given query and
# adds no information for the reader, so we strip it. Bonus: the stripped
# form matches what `git ls-files` produces, so output is grep-friendly.
group_key_for() {
  case "$1" in
    rule)     echo '.rule' ;;
    file)     echo '(.component | sub("^[^:]+:"; ""))' ;;
    dir)      echo '(.component | sub("^[^:]+:"; "") | split("/")[:-1] | join("/"))' ;;
    severity) echo '.severity' ;;
    type)     echo '.type' ;;
    author)   echo '(.author // "<unknown>")' ;;
  esac
}

# INVARIANT: every entry of GROUPED has the schema
#   { key: <str>, count: <int>, severity: <str>, types: [<str>],
#     max_weight: <int>, sample: [{ file, line, msg }, ...up to 5] }
# All format_* functions below consume this exact shape — DO NOT add fields
# without auditing the formatters, and DO NOT remove fields (the `md` and
# `csv` formats project specific paths). The jq pipeline is the contract.
#
# WHY single pipeline (not per-format jq logic): keeps the analysis in one
# place. Adding a new --format (say, `--format html`) means writing a
# renderer, never re-deriving severity/count/sample. Pure separation of
# analysis vs. presentation.
# WHY gate runs first (before fetch_all): the Quality Gate is the top-level
# verdict — it tells you WHETHER the PR is blocked before you dive into the
# individual issues. Printing it first sets context: "this PR is red because
# of duplication + 4 issues" → then the issue plan shows what those 4 are.
# PROJECT_KEY is already canonical (resolved above), so fetch_gate and
# fetch_all both use the same validated key — no propagation needed.
if [ "$SHOW_GATE" = 1 ]; then
  GATE_JSON=$(fetch_gate)
  format_gate "$GATE_JSON"
  drilldown_gate_failures "$GATE_JSON"
fi

ISSUES_JSON=$(fetch_all)

GK=$(group_key_for "$GROUP_BY")
GROUPED=$(echo "$ISSUES_JSON" | jq --argjson sevW '
  {"BLOCKER":5,"CRITICAL":4,"MAJOR":3,"MINOR":2,"INFO":1}
' '
  group_by('"$GK"')
  | map({
      key:        (.[0] | '"$GK"'),
      count:      length,
      severity:   ([.[].severity] | max_by($sevW[.] // 0)),
      types:      ([.[].type]     | unique),
      max_weight: ([.[].severity] | map($sevW[.] // 0) | max),
      sample:     ( .[:5] | map({
          file: (.component | sub("^[^:]+:"; "")),
          line: (.line // .textRange.startLine // 0),
          msg:  .message
      }))
    })
  # WHY this sort key: leverage = severity-weight * 1000 + count. The 1000
  # gap means a BLOCKER (weight 5) with 1 occurrence outranks a MINOR
  # (weight 2) with 999 occurrences. Negation makes jq sort descending.
  # If you ever need a different ranking (pure count, pure severity), do
  # NOT modify this — add a --sort flag and branch the sort_by expression.
  | sort_by(-(.max_weight * 1000 + .count))
')

format_summary() {
  local total
  total=$(echo "$ISSUES_JSON" | jq 'length')
  printf '%b%d issue(s)%b grouped by %b%s%b (sorted by severity*count)\n\n' \
    "$C_BOLD" "$total" "$C_RST" "$C_CYA" "$GROUP_BY" "$C_RST"
  echo "$GROUPED" | jq -r '.[] | "\(.count)\t\(.severity)\t\(.key)"' | \
  while IFS=$'\t' read -r count sev key; do
    color=$(severity_color "$sev")
    printf '  %3d  %b%-9s%b  %s\n' "$count" "$color" "$sev" "$C_RST" "$key"
  done
}

format_plan() {
  local total clusters
  total=$(echo "$ISSUES_JSON" | jq 'length')
  clusters=$(echo "$GROUPED" | jq 'length')
  printf '%bFix plan%b: %d issue(s) → %d %b%s%b cluster(s)\n' \
    "$C_BOLD" "$C_RST" "$total" "$clusters" "$C_CYA" "$GROUP_BY" "$C_RST"
  printf '%bOne fix per cluster typically resolves all members.%b\n\n' "$C_DIM" "$C_RST"

  # GOTCHA: `nl -s$'\t'` and `IFS=$'\t' read` go together. JSON payloads
  # contain spaces, quotes, brackets, and `:` — every other delimiter would
  # corrupt parsing. Tab is the only character JSON cannot contain raw
  # (must be escaped as \t inside strings), so tab-as-IFS is collision-proof.
  # The `\t` literal needs $'…' (ANSI-C quoting) — plain "\t" would be the
  # two characters backslash-t.
  echo "$GROUPED" | jq -c '.[]' | nl -ba -w2 -s$'\t' | while IFS=$'\t' read -r idx json; do
    key=$(echo "$json" | jq -r '.key')
    cnt=$(echo "$json" | jq -r '.count')
    sev=$(echo "$json" | jq -r '.severity')
    color=$(severity_color "$sev")
    # Trim leading whitespace from nl's right-aligned index.
    idx=$(echo "$idx" | tr -d ' ')
    printf '%b[%s]%b %b%-9s%b %b%s%b  %b(%dx)%b\n' \
      "$C_BOLD" "$idx" "$C_RST" \
      "$color"  "$sev" "$C_RST" \
      "$C_CYA"  "$key" "$C_RST" \
      "$C_DIM"  "$cnt" "$C_RST"
    echo "$json" | jq -r '.sample[] | "      \(.file):\(.line)  — \(.msg)"' | \
      while IFS= read -r row; do
        printf '%b%s%b\n' "$C_DIM" "$row" "$C_RST"
      done
    echo
  done
}

format_md() {
  local total clusters
  total=$(echo "$ISSUES_JSON" | jq 'length')
  clusters=$(echo "$GROUPED" | jq 'length')
  printf "## SonarQube triage (%d issues → %d %s clusters)\n\n" "$total" "$clusters" "$GROUP_BY"
  printf "| # | Severity | %s | Count | Sample |\n" "$GROUP_BY"
  printf "|---|----------|%s|------:|--------|\n" "$(printf -- '-%.0s' $(seq 1 $((${#GROUP_BY}+2))))"
  echo "$GROUPED" | jq -r --arg gb "$GROUP_BY" '
    to_entries[] | "| \(.key+1) | \(.value.severity) | `\(.value.key)` | \(.value.count) | \(.value.sample[0].file // "-"):\(.value.sample[0].line // 0) |"
  '
}

format_csv() {
  printf "rank,severity,%s,count,sample_file,sample_line,sample_msg\n" "$GROUP_BY"
  echo "$GROUPED" | jq -r '
    to_entries[] | [
      (.key+1), .value.severity, .value.key, .value.count,
      (.value.sample[0].file // ""), (.value.sample[0].line // 0),
      (.value.sample[0].msg  // "")
    ] | @csv
  '
}

case "$FORMAT" in
  summary) format_summary ;;
  plan)    format_plan ;;
  md)      format_md ;;
  csv)     format_csv ;;
  json)    echo "$GROUPED" | jq -c . ;;
  raw)     echo "$ISSUES_JSON" | jq . ;;
esac
