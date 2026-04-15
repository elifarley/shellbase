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
#   -v, --verbose        Print API URLs to stderr.
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
#   sonar-issues.sh                              # CWD project, default filters
#   sonar-issues.sh --pr                          # auto-detect PR via gh
#   sonar-issues.sh myorg_myproj --pr 42 -f plan  # actionable triage list
#   sonar-issues.sh -f md > findings.md           # paste into PR
#   sonar-issues.sh -f json | jq '.[] | select(.count > 3)'
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
die() { printf '%berror:%b %s\n' "$C_RED" "$C_RST" "$*" >&2; exit "${2:-1}"; }
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
    -v|--verbose)  VERBOSE=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; break ;;
    -*)            die "unknown option: $1" 1 ;;
    *)             PROJECT_KEY="$1"; shift ;;
  esac
done

# ---------- validation ----------
# WHY `: "${VAR:?msg}"` idiom: the `:` is the no-op builtin; bash evaluates the
# parameter expansion for its side effect. `:?` aborts the script with `msg`
# on stderr and a non-zero exit if VAR is unset OR empty. Cleanest fail-fast
# for required env vars — no `if [ -z … ]` boilerplate, no double-message risk.
: "${SONAR_HOST_URL:?SONAR_HOST_URL not set (e.g. https://sonarqube.example.com)}"
: "${SONAR_TOKEN:?SONAR_TOKEN not set}"

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
