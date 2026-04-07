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
}

# Compute hash of content
compute_hash() {
  echo -n "$1" | sha256sum | cut -d' ' -f1
}

# Fetch content from URL
fetch_content() {
  local url="$1"
  
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

# Write notification message
write_session_notification() {
  local changes_summary="$1"
  local changed_files="$2"
  local git_head_after="$3"
  local git_head_before="$4"
  local changes_diff="$5"
  local changes_to_commit="$6"

  cat > "$SESSION_FILE" << EOF
📄 Bland Documentation Changes Detected

${changes_summary}

📊 Changes committed and pushed:
${changes_to_commit}

📂 Files changed:
EOF
  
  if [ -n "$git_head_before" ] && [ "$git_head_after" != "$git_head_before" ]; then
    git diff --name-only "$git_head_before".."$git_head_after" 2>/dev/null | sed 's/^/- /' >> "$SESSION_FILE" 2>/dev/null || echo "- No file list available" >> "$SESSION_FILE"
  else
    echo "- No file diff available" >> "$SESSION_FILE"
  fi
  
  cat >> "$SESSION_FILE" << EOF

🔗 Commit: https://github.com/PrecisionIT-01/bland-docs/commit/${git_head_after}
📅 Updated: $(date '+%Y-%m-%d %H:%M:%S')

---
Manual review may be needed for:
- reference/cli-commands.md (CLI commands)
- reference/mcp-tools.md (MCP tools)
- reference/tools.md
- reference/webhooks.md
- reference/personas.md
- workflows/troubleshooting.md
- workflows/testing.md

Full diff (last 100 lines):
EOF
  
  echo "$changes_diff" | head -100 >> "$SESSION_FILE"
  
  echo "" >> "$SESSION_FILE"
  echo "~~ More diff available: git diff ${git_head_before}..${git_head_after}" >> "$SESSION_FILE"
}

# Check if only expected files are changed
check_allowed_changes() {
  local status_output=$(git status --porcelain 2>/dev/null)
  
  # If no uncommitted changes, allow
  [ -z "$status_output" ] && return 0
  
  # Check if only .latest_changes.txt or tracking files are modified
  local unexpected=$(echo "$status_output" | grep -v "M .latest_changes.txt" | grep -v "M monitoring/" || echo "")
  
  [ -z "$unexpected" ]
}

# Main monitoring logic
main() {
  log_info "Starting Bland documentation monitoring"
  
  # Clear session file
  > "$SESSION_FILE"
  
  for url in "${MONITORED_URLS[@]}"; do
    URL_HASHES["$url"]=""
  done
  
  local changes_detected=false
  local changes_summary=""
  local updated_files_text=""
  
  cd "$REPO_ROOT" || exit 1
  
  # If only .latest_changes.txt is modified, that's OK (from previous run)
  if ! check_allowed_changes; then
    log_warn "Repository has unexpected uncommitted changes, skipping"
    echo "🚫 Repository has uncommitted changes. Monitoring skipped." > "$SESSION_FILE"
    echo "$(git status --short)" >> "$SESSION_FILE" 2>/dev/null
    exit 0
  fi
  
  # Track git HEAD before changes
  local git_head_before=$(git rev-parse HEAD 2>/dev/null || echo "")
  
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
      changes_summary="$changes_summary- $url (hash: ${old_hash:0:16}... → ${new_hash:0:16}...)\n"
      
      case "$url" in
        *cli.md*)
          updated_files_text="${updated_files_text}- reference/cli-commands.md\n- reference/mcp-tools.md\n"
          ;;
        *llms.txt*)
          updated_files_text="${updated_files_text}- README.md\n"
          ;;
      esac
    else
      log_info "No changes in $url"
    fi
  done

  if [ "$changes_detected" = true ]; then
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    update_last_check "$timestamp"
    
    update_changelog "Changes detected:\n\n$changes_summary\n\nFiles that may need review:\n\n$updated_files_text"
    
    git add "$LAST_CHECK_FILE" "$CHANGELOG_FILE" "$REPO_ROOT"/*.md 2>/dev/null || true
    git add "$REPO_ROOT"/*/*.md 2>/dev/null || true
    git add "$REPO_ROOT"/*/*/*.md 2>/dev/null || true
    
    local changes_to_commit=$(git diff --cached --stat 2>/dev/null || echo "No changes")
    
    git commit -m "docs: update tracking after detecting changes" &>/dev/null || log_warn "No new changes to commit"
    
    local git_head_after=$(git rev-parse HEAD 2>/dev/null || echo "")
    
    local changes_diff=""
    if [ -n "$git_head_before" ] && [ "$git_head_after" != "$git_head_before" ]; then
      changes_diff=$(git diff "$git_head_before".."$git_head_after" 2>/dev/null || echo "Diff failed")
    else
      changes_diff="Diff not available"
    fi
    
    if git remote -v &>/dev/null; then
      if git push &>/dev/null; then
        log_info "Successfully pushed to remote"
      else
        log_warn "Push failed"
      fi
    fi
    
    write_session_notification "$changes_summary" "$updated_files_text" "$git_head_after" "$git_head_before" "$changes_diff" "$changes_to_commit"
    
    log_info "Changes detected, committed, pushed. Check .latest_changes.txt"
  else
    update_last_check "null"
    log_info "No changes detected"
    cat > "$SESSION_FILE" << EOF
✅ No changes detected in Bland documentation.

$(date '+%Y-%m-%d %H:%M:%S') - Monitoring complete, no updates needed.

Monitored:
- https://docs.bland.ai/sdks/cli.md
- https://docs.bland.ai/llms.txt
- https://www.npmjs.com/package/bland-cli
EOF
  fi
}

main "$@"