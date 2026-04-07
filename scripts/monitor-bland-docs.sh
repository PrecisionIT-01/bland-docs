#!/bin/bash

# Bland Documentation Monitoring Script
# Fetches latest docs, detects changes, commits to git, syncs to client repos, and sends webhook notification

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$REPO_ROOT/monitoring"
LAST_CHECK_FILE="$MONITORING_DIR/last-check.json"
CHANGELOG_FILE="$MONITORING_DIR/CHANGELOG.md"
SESSION_FILE="$REPO_ROOT/.latest_changes.txt"
SLACK_WEBHOOK_URL="https://hooks.slack.com/triggers/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"

MONITORED_URLS=(
  "https://docs.bland.ai/sdks/cli.md"
  "https://docs.bland.ai/llms.txt"
  "https://www.npmjs.com/package/bland-cli"
)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_info() { log "${GREEN}✓${NC} $1"; }
log_warn() { log "${YELLOW}!${NC} $1"; }
log_error() { log "${RED}✗${NC} $1"; }

send_to_webhook() {
  local diffs="$1"
  local json_payload="{\"diffs\": $(echo "$diffs" | jq -Rs .)}"
  log_info "Sending to Slack webhook..."
  curl -s -X POST "$SLACK_WEBHOOK_URL" -H "Content-Type: application/json" -d "$json_payload" &>/dev/null && log_info "Webhook sent" || log_warn "Webhook failed"
}

compute_hash() { echo -n "$1" | sha256sum | cut -d' ' -f1; }

fetch_content() {
  local url="$1"
  curl -sL --fail "$url" 2>/dev/null || { log_error "Failed to fetch $url"; return 1; }
}

update_last_check() {
  local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local last_update="$1"
  cat > "$LAST_CHECK_FILE" << EOF
{"last_check": "$current_time", "last_update": "$last_update"}
EOF
}

get_existing_hash() {
  local url="$1"
  [ ! -f "$LAST_CHECK_FILE" ] && echo "" && return
  jq -r ".hashes.\"$url\"" "$LAST_CHECK_FILE" 2>/dev/null || echo ""
}

update_changelog() {
  local message="$1"
  local date=$(date '+%Y-%m-%d')
  if [ -f "$CHANGELOG_FILE" ]; then
    awk -v date="$date" -v msg="$message" '/^## / && NR > 5 && !p { print "## " date "\n\n" msg "\n\n---\n"; p=1 } { print }' "$CHANGELOG_FILE" > /tmp/cl && mv /tmp/cl "$CHANGELOG_FILE"
  else
    echo -e "# Changelog\n\n---\n\n## $date\n\n$message\n\n---" > "$CHANGELOG_FILE"
  fi
}

sync_clients() {
  log_info "Syncing to client repos..."
  if [ -f "$SCRIPT_DIR/sync-clients.sh" ]; then
    bash "$SCRIPT_DIR/sync-clients.sh" 2>&1 | tail -5
  else
    log_warn "sync-clients.sh not found"
  fi
}

main() {
  log_info "Starting Bland documentation monitoring"
  > "$SESSION_FILE"
  
  declare -A URL_HASHES
  local changes_detected=false
  local changes_summary=""
  
  cd "$REPO_ROOT" || exit 1
  
  # Check for uncommitted changes (ignore session file)
  local status=$(git status --porcelain 2>/dev/null | grep -v "M .latest_changes.txt" | grep -v "M monitoring/")
  if [ -n "$status" ]; then
    log_warn "Uncommitted changes, skipping"
    echo "Uncommitted changes. Skipping." > "$SESSION_FILE"
    exit 0
  fi
  
  local git_head_before=$(git rev-parse HEAD 2>/dev/null || echo "")
  
  # Check each URL
  for url in "${MONITORED_URLS[@]}"; do
    log_info "Checking: $url"
    
    local content
    if ! content=$(fetch_content "$url"); then
      log_warn "Fetch failed for $url"
      continue
    fi
    
    local new_hash=$(compute_hash "$content")
    URL_HASHES["$url"]="$new_hash"
    
    local old_hash=$(get_existing_hash "$url")
    
    if [ "$old_hash" != "$new_hash" ]; then
      log_info "Change detected in $url"
      changes_detected=true
      changes_summary="${changes_summary}- $url (hash: ${old_hash:0:16}... → ${new_hash:0:16}...)\n"
    else
      log_info "No changes in $url"
    fi
  done

  if [ "$changes_detected" = true ]; then
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Update hashes file
    cat > "$LAST_CHECK_FILE" << EOF
{
  "last_check": "$timestamp",
  "hashes": {
EOF
    first=true
    for url in "${MONITORED_URLS[@]}"; do
      [ "$first" = true ] && first=false || echo "," >> "$LAST_CHECK_FILE"
      echo "    \"$url\": \"${URL_HASHES[$url]}\"" >> "$LAST_CHECK_FILE"
    done
    echo -e "\n  }\n}" >> "$LAST_CHECK_FILE"
    
    update_changelog "Changes detected:\n\n$changes_summary"
    
    git add "$LAST_CHECK_FILE" "$CHANGELOG_FILE" "$REPO_ROOT"/*.md 2>/dev/null || true
    git add "$REPO_ROOT"/*/*.md 2>/dev/null || true
    git add clients.json 2>/dev/null || true
    
    local changes_to_commit=$(git diff --cached --stat 2>/dev/null || echo "No changes")
    
    git commit -m "docs: update tracking after detecting changes" &>/dev/null || log_warn "Nothing to commit"
    
    local git_head_after=$(git rev-parse HEAD 2>/dev/null || echo "")
    
    if git remote -v &>/dev/null; then
      git push &>/dev/null && log_info "Pushed to remote" || log_warn "Push failed"
    fi
    
    # Sync to all client repos
    local sync_output=$(sync_clients 2>&1)
    
    # Build notification
    local changed_files_list=""
    if [ "$git_head_after" != "$git_head_before" ]; then
      changed_files_list=$(git diff --name-only "$git_head_before".."$git_head_after" 2>/dev/null | sed 's/^/- /' || echo "- No list")
    fi
    
    local webhook_msg="📄 Bland Documentation Changes Detected

${changes_summary}

📊 Changes pushed:
${changes_to_commit}

📂 Files:
${changed_files_list}

🔗 https://github.com/PrecisionIT-01/bland-docs/commit/${git_head_after}
📅 $(date '+%Y-%m-%d %H:%M:%S')

---
Client repos synced automatically.
Docs: https://github.com/orgs/Bland-Applied-Solutions/repositories"
    
    echo "$webhook_msg" > "$SESSION_FILE"
    send_to_webhook "$webhook_msg"
    
    log_info "Done! Changes detected, pushed, and synced."
  else
    update_last_check "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    log_info "No changes detected"
    
    local no_changes="✅ No changes detected in Bland documentation.

$(date '+%Y-%m-%d %H:%M:%S') - Monitoring complete.

All client repos up to date."
    
    echo "$no_changes" > "$SESSION_FILE"
    send_to_webhook "$no_changes"
  fi
}

main "$@"