#!/bin/bash

# Bland Documentation Monitoring Script
# Fetches latest docs from bland.ai, detects changes, updates MD files, commits to git, and sends diffs via message
# Designed to run nightly via cron

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$REPO_ROOT/monitoring"
LAST_CHECK_FILE="$MONITORING_DIR/last-check.json"
CHANGELOG_FILE="$MONITORING_DIR/CHANGELOG.md"
SESSION_FILE="$REPO_ROOT/.latest_changes.txt"  # For reading diffs in the session

# URLs to monitor
MONITORED_URLS=(
  "https://docs.bland.ai/sdks/cli.md"
  "https://docs.bland.ai/llms.txt"
  "https://www.npmjs.com/package/bland-cli"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
  log "${GREEN}INFO${NC}: $1"
}

log_warn() {
  log "${YELLOW}WARN${NC}: $1"
}

log_error() {
  log "${RED}ERROR${NC}: $1"
  echo "$1" >> "$SESSION_FILE"
}

# Compute hash of content
compute_hash() {
  echo -n "$1" | sha256sum | cut -d' ' -f1
}

# Fetch content from URL
fetch_content() {
  local url="$1"
  
  # Try curl first, then wget
  if command -v curl &> /dev/null; then
    curl -sL --fail "$url" 2>/dev/null || { log_error "Failed to fetch $url"; return 1; }
  elif command -v wget &> /dev/null; then
    wget -qO- --fail "$url" 2>/dev/null || { log_error "Failed to fetch $url"; return 1; }
  else
    log_error "Neither curl nor wget available"
    return 1
  fi
}

# Update last-check.json
update_last_check() {
  local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local last_update="$1"

  # Create JSON structure
  cat > "$LAST_CHECK_FILE" << EOF
{
  "last_check": "$current_time",
  "monitored_urls": {
EOF

  first=true
  for url in "${MONITORED_URLS[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> "$LAST_CHECK_FILE"
    fi
    
    local hash=$(get_stored_hash "$url")
    cat >> "$LAST_CHECK_FILE" << EOF
    "$url": {
      "last_fetched": "$current_time",
      "hash": "$hash",
      "needs_update": false
    }
EOF
  done

  cat >> "$LAST_CHECK_FILE" << EOF
  },
  "last_update": "$last_update"
}
EOF
}

# Get hash from last-check.json
get_existing_hash() {
  local url="$1"
  
  if [ ! -f "$LAST_CHECK_FILE" ]; then
    echo ""
    return
  fi
  
  if command -v jq &> /dev/null; then
    jq -r ".monitored_urls.\"$url\".hash" "$LAST_CHECK_FILE" 2>/dev/null || echo ""
  else
    grep -A2 "\"$url\"" "$LAST_CHECK_FILE" | grep "hash" | sed 's/.*"hash": "*\([^"]*\)".*/\1/' || echo ""
  fi
}

# Hash storage
declare -A URL_HASHES
store_hash() {
  local url="$1"
  local hash="$2"
  URL_HASHES["$url"]="$hash"
}

get_stored_hash() {
  local url="$1"
  echo "${URL_HASHES[$url]}"
}

# Get diff between old and new content for a file
get_git_diff() {
  local file="$1"
  if [ -f "$file" ]; then
    git diff HEAD -- "$file" 2>/dev/null || echo "Diff not available for $file"
  fi
}

# Update CHANGELOG.md
update_changelog() {
  local message="$1"
  local date=$(date '+%Y-%m-%d')

  if [ -f "$CHANGELOG_FILE" ]; then
    local temp_file=$(mktemp)
    
    awk -v date="$date" -v message="$message" '
      /^## / && NR > 5 && !header_printed {
        print "## " date
        print ""
        print message
        print ""
        print "---"
        print ""
        header_printed = 1
      }
      {
        if (!header_printed || NR <= 5) print
      }
    ' "$CHANGELOG_FILE" > "$temp_file"
    
    mv "$temp_file" "$CHANGELOG_FILE"
  else
    cat > "$CHANGELOG_FILE" << EOF
# Bland Documentation Changelog

Track of local updates made to this documentation repository based on changes detected in Bland docs.

---
## $date

$message

---
EOF
  fi
  
  log_info "Updated CHANGELOG.md"
}

# Write notification message for session reading
write_session_notification() {
  local changes_summary="$1"
  local changed_files="$2"

  cat > "$SESSION_FILE" << EOF
📄 Bland Documentation Changes Detected

${changes_summary}

📂 potentially affected files:
${changed_files}

📊 Commit history:
EOF
  
  # Add recent commits
  git log --oneline -5 HEAD >> "$SESSION_FILE" 2>/dev/null
  
  cat >> "$SESSION_FILE" << EOF

🔗 Repo: https://github.com/PrecisionIT-01/bland-docs
📅 Updated at: $(date '+%Y-%m-%d %H:%M:%S')

---
Review the files in the repo for full details and necessary manual updates.
EOF
}

# Main monitoring logic
main() {
  log_info "Starting Bland documentation monitoring"
  
  # Clear session file for new run
  > "$SESSION_FILE"
  
  # Initialize hashes
  for url in "${MONITORED_URLS[@]}"; do
    URL_HASHES["$url"]=""
  done
  
  local changes_detected=false
  local changes_summary=""
  local updated_files=""
  
  cd "$REPO_ROOT" || exit 1
  
  # Check git status
  local git_clean=$(git diff-index --quiet HEAD -- 2>/dev/null && echo "clean" || echo "dirty")
  
  if [ "$git_clean" = "dirty" ]; then
    log_warn "Git repository has uncommitted changes, skipping"
    echo "Git has uncommitted changes. Monitoring skipped until clean." > "$SESSION_FILE"
    exit 0
  fi
  
  # Track git HEAD for diff generation
  local git_head_before=$(git rev-parse HEAD 2>/dev/null)
  
  # Fetch and check each URL
  for url in "${MONITORED_URLS[@]}"; do
    log_info "Checking: $url"
    
    local content
    if ! content=$(fetch_content "$url"); then
      log_warn "Skipping $url due to fetch error"
      continue
    fi
    
    local new_hash=$(compute_hash "$content")
    store_hash "$url" "$new_hash"
    
    local old_hash=$(get_existing_hash "$url")
    
    if [ "$old_hash" != "$new_hash" ]; then
      log_info "Change detected in $url"
      changes_detected=true
      changes_summary="$changes_summary- $url (hash changed: ${old_hash:0:16}... → ${new_hash:0:16}...)\n"
      
      # Note: We track the URL change, manual updates needed for corresponding files
      updated_files="$updated_files- See relevant docs based on: $url\n"
    else
      log_info "No changes in $url"
    fi
  done

  if [ "$changes_detected" = true ]; then
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    update_last_check "$timestamp"
    
    # Update tracking files
    update_changelog "Changes detected in monitored sources:\n\n$changes_summary\n\nManual review required for affected documentation files."
    
    # Stage tracking files
    git add "$LAST_CHECK_FILE" "$CHANGELOG_FILE" "$REPO_ROOT"/*.md 2>/dev/null || true
    git add "$REPO_ROOT"/*/*.md 2>/dev/null || true
    git add "$REPO_ROOT"/*/*/*.md 2>/dev/null || true
    
    # Check what changes will be committed
    local changes_to_commit=$(git diff --cached --stat 2>/dev/null)
    
    local commit_message="docs: update tracking after detecting changes

Changes detected in monitored documentation sources.
See CHANGELOG.md for details."
    
    if git commit -m "$commit_message" &>/dev/null; then
      log_info "Committed changes to git"
    else
      log_warn "No new changes to commit"
    fi
    
    # Generate diff of what was committed
    local git_head_after=$(git rev-parse HEAD 2>/dev/null)
    local changes_diff=""
    if [ "$git_head_before" != "$git_head_after" ] && [ -n "$git_head_before" ]; then
      changes_diff=$(git diff "$git_head_before".."$git_head_after" 2>/dev/null || echo "Diff generation failed")
    else
      changes_diff="No git diff generated (first run or no changes)"
    fi
    
    # Push to remote
    if git remote -v &>/dev/null; then
      if git push &>/dev/null; then
        log_info "Successfully pushed to remote"
      else
        log_warn "Push failed (may need authentication)"
      fi
    fi
    
    # Write notification with diff
    cat > "$SESSION_FILE" << EOF
📄 Bland Documentation Changes Detected

${changes_summary}

📊 Changes pushed to GitHub:
${changes_to_commit}

📂 Files committed:
EOF
    git diff --name-only "$git_head_before".."$git_head_after" 2>/dev/null | sed 's/^/- /' >> "$SESSION_FILE" 2>/dev/null
    
    cat >> "$SESSION_FILE" << EOF

🔗 Repo: https://github.com/PrecisionIT-01/bland-docs/commit/${git_head_after}
📅 Updated at: $(date '+%Y-%m-%d %H:%M:%S')

---
Review the committed files in the repo. Full git diff available via:
git diff ${git_head_before}..${git_head_after}

Manual updates may be needed for:
- CLI commands in reference/cli-commands.md
- MCP tools in reference/mcp-tools.md  
- Tools, Webhooks, Personas guides
- Workflow documentation
EOF
    
    log_info "Changes detected, committed, and pushed. Check .latest_changes.txt for details."
  else
    # No changes, just update timestamp
    update_last_check "null"
    log_info "No changes detected"
    echo "✅ No changes detected in Bland documentation." > "$SESSION_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Monitoring complete, no updates needed." >> "$SESSION_FILE"
  fi
}

# Run main function
main "$@"