# 19-apps.sh: Application-specific aliases and functions
# jq: jqlog for parsing JSON logs
# gh: GitHub helpers (last-fail, quality, annotations, repo-health)
# kopia: Backup tool alias
# kitty: Terminal emulator helpers (effective-config, clear-cache)
# ssh: kitty kitten ssh integration
# claude: Multiple Claude Code configuration aliases

# jq

# Parse JSON logs from stdin
jqlog() {
  grep --line-buffered -E '^{' | while read -r LINE; do echo -E "$LINE" \
    | jq -r '.level + " " + .loggerName + "\t" + .message'; done
}

# Application aliases

# GitHub (gh) helper functions
#
# These functions extend the GitHub CLI (gh) with additional capabilities for
# workflow debugging, code quality analysis, and repository health checks.
#
# NOTE: Some functions overlap and could be unified in the future:
# - gh.annotations and gh.quality-annotations serve similar purposes
# - gh.quality and gh.quality-full both fetch CodeQL findings via different APIs

# gh.last-fail: Retrieve and display the most recent failed GitHub Actions workflow
#
# USAGE:
#   gh.last-fail           # Show failed logs in terminal
#   gh.last-fail -w        # Open in browser
#   gh.last-fail -u        # Print URL only
#   gh.last-fail -x        # Output as XML (LLM-friendly)
#   gh.last-fail -h        # Show help
gh.last-fail() {
    # 0. Fast Help Check
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        cat << EOF
Usage: gh.last-fail [flag]

Retrieves the most recent failed GitHub Actions workflow run for the current
repository's 'origin' remote.

Flags:
  (none)       Fetch and display the failed logs in the terminal.
  -w, --web    Open the workflow run summary in your default browser.
  -u, --url    Print the URL of the workflow run.
  -x, --xml    Output metadata and logs in an LLM-friendly XML format.
  -h, --help   Show this help message.
EOF
        return 0
    fi

    local repo
    # 1. Get the 'origin' remote URL safely
    repo=$(git remote get-url origin 2>/dev/null)

    if [ -z "$repo" ]; then
        echo "Error: Not a git repository or no 'origin' remote found."
        return 1
    fi

    # 2. Find the ID of the last failure
    local run_id
    run_id=$(gh run list -R "$repo" --status failure --limit 1 --json databaseId -q ".[0].databaseId")

    if [ -z "$run_id" ]; then
        echo "No recent failed runs found for $repo"
        return 0
    fi

    # 3. Handle arguments
    if [[ "$1" == "--web" || "$1" == "-w" ]]; then
        echo "Opening run #$run_id in browser..."
        gh run view "$run_id" --web -R "$repo"

    elif [[ "$1" == "--url" || "$1" == "-u" ]]; then
        # Extract and print ONLY the URL
        gh run view "$run_id" -R "$repo" --json url -q ".url"

    elif [[ "$1" == "--xml" || "$1" == "-x" ]]; then
        # Fetch URL for metadata
        local url
        url=$(gh run view "$run_id" -R "$repo" --json url -q ".url")

        # Output XML structure with CDATA protection for logs
        echo "<workflow_failure id=\"$run_id\" repository=\"$repo\">"
        echo "  <url>$url</url>"
        echo "  <logs>"
        echo "    <![CDATA["
        gh run view "$run_id" --log-failed -R "$repo"
        echo "    ]]>"
        echo "  </logs>"
        echo "</workflow_failure>"

    else
        echo "Fetching failed logs for run #$run_id..."
        gh run view "$run_id" --log-failed -R "$repo"
    fi
}

# gh.quality: Fetch CodeQL code scanning alerts (Standard Findings)
#
# Uses the code-scanning/alerts API filtered to CodeQL tool results.
# Aggregates alerts by rule ID and outputs in XML format.
#
# COMPARE: gh.quality-full uses SARIF download for richer metadata
#
# USAGE:
#   gh.quality    # Outputs XML with rule_id, count, severity, locations
gh.quality() {
    local repo_path
    
    # 1. Get Repo Info
    repo_url=$(git remote get-url origin 2>/dev/null)
    if [ -z "$repo_url" ]; then
        echo "Error: Not a git repository or no 'origin' remote found."
        return 1
    fi
    repo_path=$(echo "$repo_url" | sed -E 's/.*github.com[:/](.*)(\.git)?/\1/' | sed 's/\.git$//')

    echo "Fetching Code Quality (Standard Findings) for $repo_path..." >&2

    # 2. API Call specifically for CodeQL
    # - tool_name=CodeQL: Filters out third-party tools
    # - per_page=100: Maximizes fetch per request
    # - state=open: Matches the 'Standard findings' view
    # - jq: AGGREGATES the raw alerts by Rule Name to match the UI
    
    gh api "repos/$repo_path/code-scanning/alerts?tool_name=CodeQL&state=open&per_page=100" --paginate \
        --jq '
        # Group by the Rule ID (e.g., py/statement-no-effect)
        group_by(.rule.id)[] 
        | {
            rule_id: .[0].rule.id, 
            description: .[0].rule.description, 
            severity: .[0].rule.severity, 
            count: length, 
            locations: (map(.most_recent_instance.location | "\(.path):\(.start_line)") | unique)
          } 
        | 
        # Format as XML-like blocks
        "<quality_rule id=\"\(.rule_id)\" count=\"\(.count)\" severity=\"\(.severity)\">
  <description><![CDATA[\(.description)]]></description>
  <locations>
\(.locations | map("    <loc>" + . + "</loc>") | join("\n"))
  </locations>
</quality_rule>"'
}

# gh.annotations: Fetch check annotations from latest default branch commit
#
# Retrieves annotations from GitHub Check Runs (e.g., linting errors from CI).
# Queries the default branch's HEAD commit for check runs with annotations.
#
# NOTE: Similar to gh.quality-annotations - these could be unified
#
# USAGE:
#   gh.annotations    # Outputs XML with annotation details
gh.annotations() {
    local repo_path
    local default_branch
    local head_sha
    local checks_json
    local annotations_url
    local tmp_anno

    # 1. Get Repo Info
    repo_url=$(git remote get-url origin 2>/dev/null)
    if [ -z "$repo_url" ]; then echo "Error: Not a git repo."; return 1; fi
    repo_path=$(echo "$repo_url" | sed -E 's/.*github.com[:/](.*)(\.git)?/\1/' | sed 's/\.git$//')
    default_branch=$(gh repo view "$repo_path" --json defaultBranchRef -q ".defaultBranchRef.name")

    echo "Fetching Check Annotations for $repo_path (ref: $default_branch)..." >&2

    # 2. Get the SHA of the latest commit on default branch
    head_sha=$(gh api "repos/$repo_path/commits/$default_branch" --jq .sha)
    echo "HEAD SHA: ${head_sha:0:7}" >&2

    # 3. List Check Runs for this commit and find those with annotations
    # We look for any check run that has a non-zero annotation count
    checks_json=$(gh api "repos/$repo_path/commits/$head_sha/check-runs" \
        --jq '.check_runs[] | select(.output.annotations_count > 0)')

    if [ -z "$checks_json" ]; then
        echo "No annotations found on the latest commit."
        return 0
    fi

    echo "<repository name=\"$repo_path\" ref=\"$head_sha\">"

    # 4. Iterate over each Check Run
    tmp_anno=$(mktemp)
    echo "$checks_json" | jq -c '.' | while read -r check; do
        local name
        name=$(echo "$check" | jq -r .name)
        annotations_url=$(echo "$check" | jq -r .output.annotations_url)

        echo "  "

        # Download the annotations
        gh api "$annotations_url" > "$tmp_anno"

        # Format as XML
        cat "$tmp_anno" | jq -r --arg tool "$name" '
            .[] |
            "<quality_annotation tool=\"\($tool)\" level=\"\(.annotation_level)\">
    <message><![CDATA[\(.message // .title)]]></message>
    <location>
      <file>\(.path)</file>
      <line>\(.start_line)</line>
    </location>
  </quality_annotation>"
        '
    done

    echo "</repository>"
    rm -f "$tmp_anno"
}

# gh.quality-annotations: Fetch quality annotations from latest default branch commit
#
# Similar to gh.annotations but uses pagination and includes end_line information.
# Outputs in a slightly different XML format (<annotation> vs <quality_annotation>).
#
# NOTE: Overlaps with gh.annotations - these could be unified with flag options
#
# USAGE:
#   gh.quality-annotations    # Outputs XML with annotation details including end_line
gh.quality-annotations() {
    local repo_path
    local default_branch
    local head_sha
    local checks_json
    local annotations_url

    # 1. Get Repo & Branch
    repo_url=$(git remote get-url origin 2>/dev/null)
    if [ -z "$repo_url" ]; then echo "Error: Not a git repo."; return 1; fi
    repo_path=$(echo "$repo_url" | sed -E 's/.*github.com[:/](.*)(\.git)?/\1/' | sed 's/\.git$//')
    default_branch=$(gh repo view "$repo_path" --json defaultBranchRef -q ".defaultBranchRef.name")

    echo "Fetching Quality Annotations for $repo_path (ref: $default_branch)..." >&2

    # 2. Get HEAD SHA
    head_sha=$(gh api "repos/$repo_path/commits/$default_branch" --jq .sha)

    # 3. Find Check Runs
    # We ignore checks with 0 annotations to save API calls
    checks_json=$(gh api "repos/$repo_path/commits/$head_sha/check-runs" \
        --jq '.check_runs[] | select(.output.annotations_count > 0)')

    if [ -z "$checks_json" ]; then
        echo "No annotations found on branch '$default_branch'."
        return 0
    fi

    echo "<repository name=\"$repo_path\" ref=\"$head_sha\">"

    # 4. Iterate checks
    echo "$checks_json" | jq -c '.' | while read -r check; do
        local name
        local count
        name=$(echo "$check" | jq -r .name)
        count=$(echo "$check" | jq -r .output.annotations_count)
        annotations_url=$(echo "$check" | jq -r .output.annotations_url)

        echo "  "

        # 5. Fetch Annotations (Pipe to jq to handle --arg correctly)
        # Note: We use -r to output raw strings (the XML) without quotes
        gh api "$annotations_url?per_page=100" --paginate | \
        jq -r --arg tool "$name" '.[] |
          "<annotation tool=\"\($tool)\" level=\"\(.annotation_level)\">
            <message><![CDATA[\(.message // .title)]]></message>
            <location>
              <file>\(.path)</file>
              <line>\(.start_line)</line>
              <end_line>\(.end_line)</end_line>
            </location>
          </annotation>"'
    done

    echo "</repository>"
}

# gh.quality-full: Fetch full CodeQL SARIF analysis with rich metadata
#
# Downloads the complete SARIF file from the latest CodeQL analysis on the
# default branch. Includes additional metadata like precision scores that
# aren't available via the alerts API.
#
# COMPARE: gh.quality uses the simpler alerts API (faster, less metadata)
#
# USAGE:
#   gh.quality-full    # Outputs XML with enriched rule metadata from SARIF
gh.quality-full() {
    local repo_path
    local default_branch
    local analysis_id
    local tmp_sarif

    # 1. Get Repo & Branch
    repo_url=$(git remote get-url origin 2>/dev/null)
    if [ -z "$repo_url" ]; then
        echo "Error: Not a git repository."
        return 1
    fi
    repo_path=$(echo "$repo_url" | sed -E 's/.*github.com[:/](.*)(\.git)?/\1/' | sed 's/\.git$//')
    default_branch=$(gh repo view "$repo_path" --json defaultBranchRef -q ".defaultBranchRef.name")

    echo "Fetching CodeQL Analysis ID for $repo_path (ref: $default_branch)..." >&2

    # 2. Get the latest CodeQL Analysis ID
    # We sort by created_at desc to ensure we get the absolute newest one
    analysis_id=$(gh api "repos/$repo_path/code-scanning/analyses?tool_name=CodeQL&ref=refs/heads/$default_branch&sort=created&direction=desc" \
        --jq '.[0].id' 2>/dev/null)

    if [ -z "$analysis_id" ] || [ "$analysis_id" == "null" ]; then
        echo "Error: No CodeQL analysis found. Code Scanning might not be enabled."
        return 1
    fi

    echo "Downloading SARIF for Analysis ID: $analysis_id..." >&2

    # 3. Download to a temp file first (Safe Mode)
    tmp_sarif=$(mktemp)
    gh api "repos/$repo_path/code-scanning/analyses/$analysis_id" \
        -H "Accept: application/sarif+json" > "$tmp_sarif"

    # 4. Validation: Check if it's an error message or valid SARIF
    if grep -q '"runs":' "$tmp_sarif"; then
        # It looks like valid SARIF
        cat "$tmp_sarif" | jq -r '
            .runs[0] as $run |
            ($run.results // []) | group_by(.ruleId)[] |
            {
                ruleId: .[0].ruleId,
                count: length,
                metadata: ($run.tool.driver.rules[] | select(.id == .[0].ruleId)),
                locations: (map(.locations[0].physicalLocation | "\(.artifactLocation.uri):\(.region.startLine)") | unique)
            } |
            "<quality_rule id=\"\(.ruleId)\" count=\"\(.count)\" severity=\"\(.metadata.properties.precision // "unknown")\">
  <name>\(.metadata.shortDescription.text // .metadata.name)</name>
  <description><![CDATA[\(.metadata.fullDescription.text // .metadata.shortDescription.text)]]></description>
  <locations>
\(.locations | map("    <loc>" + . + "</loc>") | join("\n"))
  </locations>
</quality_rule>"'
    else
        # It is likely an API error message
        echo "Error: Failed to retrieve SARIF data."
        echo "API Response:"
        cat "$tmp_sarif"
    fi

    # Cleanup
    rm "$tmp_sarif"
}

# gh.repo-health: Aggregate ALL repository security and quality findings
#
# Comprehensive health check that combines:
# - Code Scanning alerts (quality + security findings from all tools)
# - Dependabot alerts (vulnerable dependencies)
# - Secret Scanning alerts (leaked credentials)
#
# USAGE:
#   gh.repo-health     # Outputs unified XML with all alert types
#   gh.repo-health -w  # Open Security Overview dashboard in browser
#   gh.repo-health -h  # Show help
gh.repo-health() {
    # 0. Help / Usage
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        cat << EOF
Usage: gh.repo-health [flag]

Aggregates ALL findings (Code Quality, Security, and Dependencies) from the
repository's default branch into a unified XML format.

Flags:
  -w, --web    Open the Security Overview dashboard in browser.
  -h, --help   Show this help message.
EOF
        return 0
    fi

    local repo_path

    # 1. Get Repo Info
    repo_url=$(git remote get-url origin 2>/dev/null)

    if [ -z "$repo_url" ]; then
        echo "Error: Not a git repository or no 'origin' remote found."
        return 1
    fi

    # Extract OWNER/REPO
    repo_path=$(echo "$repo_url" | sed -E 's/.*github.com[:/](.*)(\.git)?/\1/' | sed 's/\.git$//')

    if [[ "$1" == "--web" || "$1" == "-w" ]]; then
        echo "Opening Security Dashboard for $repo_path..."
        gh browse --repo "$repo_path" security
        return 0
    fi

    echo "Fetching repo health report for $repo_path (default branch)..." >&2

    # 2. Generate XML Output
    echo "<repository name=\"$repo_path\">"

    # --- A. CODE SCANNING (Standard Findings: Quality & Security) ---
    # Using generic <alert type="code-scanning">
    gh api "repos/$repo_path/code-scanning/alerts?state=open" --paginate \
        --jq '.[] |
  "<alert type=\"code-scanning\">
    <tool>\(.tool.name)</tool>
    <severity>\(.rule.severity)</severity>
    <rule_id>\(.rule.id)</rule_id>
    <location>
      <file>\(.most_recent_instance.location.path)</file>
      <line>\(.most_recent_instance.location.start_line)</line>
    </location>
    <description><![CDATA[\(.rule.description)]]></description>
  </alert>"' 2>/dev/null || echo "  "

    # --- B. DEPENDABOT (Vulnerable Libraries) ---
    # Using generic <alert type="dependabot">
    gh api "repos/$repo_path/dependabot/alerts?state=open" --paginate \
        --jq '.[] |
  "<alert type=\"dependabot\">
    <severity>\(.security_advisory.severity)</severity>
    <package>\(.dependency.package.name)</package>
    <ecosystem>\(.dependency.package.ecosystem)</ecosystem>
    <summary><![CDATA[\(.security_advisory.summary)]]></summary>
    <cve_id>\(.security_advisory.cve_id)</cve_id>
  </alert>"' 2>/dev/null || echo "  "

    # --- C. SECRET SCANNING (Leaked Credentials) ---
    # Using generic <alert type="secret-scanning">
    gh api "repos/$repo_path/secret-scanning/alerts?state=open" --paginate \
        --jq '.[] |
  "<alert type=\"secret-scanning\">
    <secret_type>\(.secret_type_display_name)</secret_type>
    <location>
      <file>\(.locations[0].path)</file>
    </location>
    <description><![CDATA[Active secret detected]]></description>
  </alert>"' 2>/dev/null || echo "  "

    echo "</repository>"
}

# Add kitty installed via official installer to PATH
path_prepend "$HOME/.local/kitty.app/bin"

# kitty: Display effective configuration from running kitty process
kitty.effective-config() {
  local KITTY_PID=${1:-$(pgrep -x kitty | head -1)}

  if [ -z "$KITTY_PID" ]; then
    echo "Error: No kitty process found" >&2
    return 1
  fi

  local EFFECTIVE_CONFIG_DIR="$HOME/.cache/kitty/effective-config"
  local EFFECTIVE_CONFIG_FILE="$EFFECTIVE_CONFIG_DIR/$KITTY_PID"

  if [ -f "$EFFECTIVE_CONFIG_FILE" ]; then
    cat "$EFFECTIVE_CONFIG_FILE"
    echo ""
    echo "=== Kitty Effective Configuration ==="
    echo "Kitty PID: $KITTY_PID"
    echo "Config file: $EFFECTIVE_CONFIG_FILE"
  else
    echo "Error: Effective config file not found at $EFFECTIVE_CONFIG_FILE" >&2
    return 1
  fi
}

# kitty: Clear cached color themes and state
#
# BACKGROUND:
#   When you kill kitty or when ~/.cache is full, kitty's cache can get corrupted,
# and colors defines in ~/.cache/kitty/rgba can override colors set in kitty.conf,
# even after restart. This function clears that cache.
#
# USE CASES:
#   - Colors in kitty.conf not taking effect (grey background instead of your color)
#   - Troubleshooting color issues
#
# WHAT GETS CLEARED:
#   - ~/.cache/kitty/rgba/*     - Cached color themes (persistent across sessions)
#   - ~/.cache/kitty/main.json   - Window size/state (optional, with --all flag)
#
# USAGE:
#   kitty.clear-cache          # Clear rgba cache (colors)
#   kitty.clear-cache --all    # Clear all cache including window state
#
# AFTER RUNNING:
#   Restart kitty for changes to take effect. Colors from kitty.conf will apply.
#
# REFERENCES:
#   - https://www.reddit.com/r/KittyTerminal/comments/1oei90r/
#   - https://github.com/kovidgoyal/kitty/discussions/6550
kitty.clear-cache() {
  local RGBA_DIR="$HOME/.cache/kitty/rgba"
  local MAIN_JSON="$HOME/.cache/kitty/main.json"
  local CLEAR_ALL=false
  local FILES_CLEARED=0

  # Parse arguments
  case "$1" in
    --all|-a)
      CLEAR_ALL=true
      ;;
  esac

  echo "=== Clearing Kitty Cache ==="
  echo ""

  # Clear rgba cache (color themes)
  if [ -d "$RGBA_DIR" ]; then
    local RGBA_COUNT=$(find "$RGBA_DIR" -type f ! -name ".lock" 2>/dev/null | wc -l)
    if [ "$RGBA_COUNT" -gt 0 ]; then
      find "$RGBA_DIR" -type f ! -name ".lock" -delete 2>/dev/null
      echo "✓ Cleared $RGBA_COUNT cached theme(s) from: $RGBA_DIR"
      FILES_CLEARED=$((FILES_CLEARED + RGBA_COUNT))
    else
      echo "ℹ No cached themes found in: $RGBA_DIR"
    fi
  else
    echo "ℹ RGBA cache directory not found: $RGBA_DIR"
  fi

  # Clear main.json (window state) if --all flag
  if [ "$CLEAR_ALL" = true ] && [ -f "$MAIN_JSON" ]; then
    rm -f "$MAIN_JSON"
    echo "✓ Cleared window state: $MAIN_JSON"
    FILES_CLEARED=$((FILES_CLEARED + 1))
  fi

  echo ""
  if [ "$FILES_CLEARED" -gt 0 ]; then
    echo "=== Summary ==="
    echo "Files cleared: $FILES_CLEARED"
    echo ""
    echo "⚠ RESTART KITTY for changes to take effect"
    echo ""
    echo "After restart, kitty will use colors from:"
    echo "  ~/.config/kitty/kitty.conf"
  else
    echo "No cache files found to clear."
    echo ""
    echo "Current kitty configuration should already be active."
  fi

  return 0
}

alias kopia='kopia --config-file=/home/ecc/.var/app/io.kopia.KopiaUI/config/kopia/repository.config'
alias ssh='kitty +kitten ssh'

# Claude Code aliases for different configurations
alias claude.glm='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-glm.json'
alias claude.ccp-snitch='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-ccproxy-snitch.json'
alias claude.avdm='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-vandamme.json'

