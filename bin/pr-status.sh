#!/usr/bin/env bash
# pr-status — Show CI checks, latest bot comments, and review state for a PR.
#
# Designed for polling loops and quick triage: one command shows everything
# you need to know about a PR's CI/review state without opening a browser.
#
# Usage: pr-status [OPTIONS] [PR_NUMBER]
#
# OPTIONS:
#   -R, --repo OWNER/REPO   GitHub repo (default: auto-detect from CWD via gh)
#   -h, --help              Show this help
#
# ARGUMENTS:
#   PR_NUMBER               PR number (default: auto-detect current branch's PR)
#
# AUTO-DETECTION:
#   - Repo: uses `gh repo view` on CWD to resolve OWNER/REPO
#   - PR: uses `gh pr view` on CWD to find the current branch's open PR
#   - Merge state: reads `mergeable` + `mergeStateStatus` from the PR
#     to flag conflicts against the base branch (BLOCKED verdict).
#
# EXAMPLES:
#   pr-status                          # current branch's PR, auto-detect repo
#   pr-status 81                       # PR #81 on auto-detected repo
#   pr-status -R buildersbank/finpsti-dict 81  # explicit repo + PR
#   pr-status --repo owner/repo        # current branch's PR on explicit repo

set -euo pipefail

usage() {
    sed -n '2,/^[^#]/{ /^#/s/^# \?//p; }' "$0"
    exit "${1:-0}"
}

repo=""
pr=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -R|--repo) repo="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        -*)        echo "Unknown option: $1" >&2; usage 1 ;;
        *)         pr="$1"; shift ;;
    esac
done

# Auto-detect repo from CWD
if [[ -z "$repo" ]]; then
    repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null) || {
        echo "Error: could not detect repo from CWD. Use -R OWNER/REPO." >&2
        exit 1
    }
fi

# Build gh pr view command
gh_args=(pr view --json statusCheckRollup,reviews,comments,mergeable,mergeStateStatus --repo "$repo")
if [[ -n "$pr" ]]; then
    gh_args+=("$pr")
fi

gh "${gh_args[@]}" 2>&1 | python3 -c "
import json, sys

d = json.load(sys.stdin)

# --- Checks ---
checks = d.get('statusCheckRollup', [])
if checks:
    print('=== CHECKS ===')
    for c in checks:
        name = c.get('name', '?')
        status = c.get('status', '?')
        conclusion = c.get('conclusion', '—') or '—'
        # Color: green for SUCCESS, red for FAILURE, yellow for in-progress/queued
        if conclusion == 'SUCCESS':
            icon = '✓'
        elif conclusion == 'FAILURE':
            icon = '✗'
        elif status in ('IN_PROGRESS', 'QUEUED'):
            icon = '⏳'
        else:
            icon = '·'
        print(f'  {icon} {name:45s} {status:12s} {conclusion}')
    print()

# --- Bot comments (SonarQube, etc) ---
bot_comments = {}
for c in d.get('comments', []):
    author = c['author']['login']
    # Keep only the latest comment per bot
    bot_comments[author] = c

if bot_comments:
    print('=== BOT COMMENTS (latest per bot) ===')
    for author, c in bot_comments.items():
        lines = c['body'].split('\n')
        # Show first non-empty meaningful line
        summary = next((l.strip() for l in lines if l.strip() and not l.strip().startswith('**Project')), lines[0])
        # Truncate long lines
        if len(summary) > 100:
            summary = summary[:97] + '...'
        print(f'  {author:30s} {c[\"createdAt\"][:16]}  {summary}')
    print()

# --- Reviews ---
reviews = d.get('reviews', [])
if reviews:
    # Deduplicate: keep latest review per author
    latest = {}
    for r in reviews:
        author = r['author']['login']
        latest[author] = r
    print('=== REVIEWS (latest per reviewer) ===')
    for author, r in latest.items():
        state = r['state']
        if state == 'APPROVED':
            icon = '✓'
        elif state == 'CHANGES_REQUESTED':
            icon = '✗'
        else:
            icon = '·'
        print(f'  {icon} {author:30s} {state:20s} ({r[\"submittedAt\"][:16]})')
    print()

# --- Merge state ---
# GitHub computes 'mergeable' lazily: a freshly pushed PR returns UNKNOWN for
# a few seconds until the server evaluates the merge-base. We surface UNKNOWN
# as-is rather than retrying — this tool is for quick triage, not polling.
# (Avoid backticks in comments — the whole block lives inside a double-quoted
# here-doc, so \`foo\` would trigger shell command substitution.)
mergeable = d.get('mergeable')         # MERGEABLE | CONFLICTING | UNKNOWN
mstate    = d.get('mergeStateStatus')  # CLEAN | DIRTY | BEHIND | BLOCKED | HAS_HOOKS | UNSTABLE | UNKNOWN
if mergeable or mstate:
    if mergeable == 'CONFLICTING':
        icon = '✗'
    elif mergeable == 'MERGEABLE' and mstate in ('CLEAN', 'HAS_HOOKS', 'UNSTABLE'):
        icon = '✓'
    elif mstate in ('BEHIND', 'BLOCKED', 'DIRTY'):
        icon = '⚠'
    else:  # UNKNOWN or unexpected combination
        icon = '·'
    print('=== MERGE STATE ===')
    print(f'  {icon} mergeable={mergeable}  state={mstate}')
    print()

# --- Summary line ---
all_done = all(c.get('status') == 'COMPLETED' for c in checks)
all_pass = all(c.get('conclusion') in ('SUCCESS', 'NEUTRAL', 'SKIPPED') for c in checks)
approved = any(r['state'] == 'APPROVED' for r in reviews)
changes_req = any(r['state'] == 'CHANGES_REQUESTED' for r in (latest.values() if reviews else []))

# Conflicts short-circuit the green verdict: developer intervention is needed
# regardless of check/review outcome. BEHIND/BLOCKED mstates are intentionally
# NOT treated as BLOCKED here — they usually resolve via rebase or admin
# action, and surfacing them as blockers would create false-negative noise.
if mergeable == 'CONFLICTING':
    print('=== BLOCKED: merge conflicts with base branch ===')
elif all_done and all_pass and approved and not changes_req:
    print('=== READY TO MERGE ===')
elif all_done and not all_pass:
    failed = [c['name'] for c in checks if c.get('conclusion') == 'FAILURE']
    print(f'=== BLOCKED: {len(failed)} check(s) failed: {\", \".join(failed)} ===')
elif not all_done:
    pending = [c['name'] for c in checks if c.get('status') != 'COMPLETED']
    print(f'=== PENDING: {len(pending)} check(s) running: {\", \".join(pending)} ===')
"
