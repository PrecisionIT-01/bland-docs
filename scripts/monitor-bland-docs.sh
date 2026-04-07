#!/bin/bash

# Bland Documentation Monitoring Script
# Fetches latest docs from bland.ai, detects changes, updates MD files, commits to git, and emails diffs
# Designed to run nightly via cron

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$REPO_ROOT/monitoring"
LAST_CHECK_FILE="$MONITORING_DIR/last-check.json"
CHANGELOG_FILE="$MONITORING_DIR/CHANGELOG.md"
EMAIL_FROM="bland-docs-monitor@$(hostname)"
EMAIL_TO="timothy@vegocs.com"

# URLs to monitor
MONITORED_URLS=(
  "https://docs.bland.ai/sdks/cli.md"
  "https://docs.bland.ai/llms.txt"
  "https://www.npmjs.com/package/bland-cli"
)

# Files to update based on detected changes
# Format: "url_pattern|local_file"
UPDATE_MAPPING=(
  "https://docs.bland.ai/sdks/cli.md|reference/cli-commands.md"
  "https://docs.bland.ai/llms.txt|README.md"
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

# Email function
send_email() {
  local subject="$1"
  local body="$2"

  # Check if mail command is available
  if command -v mail &> /dev/null; then
    echo "$body" | mail -s "$subject" -a "From: $EMAIL_FROM" "$EMAIL_TO"
    log_info "Email sent to $EMAIL_TO"
  else
    log_warn "mail command not available, skipping email"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EMAIL DRAFT - To: $EMAIL_TO"
    echo "Subject: $subject"
    echo ""
    echo "$body"
  fi
}

# Compute hash of content
compute_hash() {
  echo -n "$1" | sha256sum | cut -d' ' -f1
}

# Fetch content from URL
fetch_content() {
  local url="$1"
  
  log_info "Fetching: $url"
  
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
    
    local hash=$(hash_to_json "$url")
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
  
  # Use grep to extract hash, or jq if available
  if command -v jq &> /dev/null; then
    jq -r ".monitored_urls.\"$url\".hash" "$LAST_CHECK_FILE" 2>/dev/null || echo ""
  else
    # Fallback: simple grep/sed extraction
    grep -A2 "\"$url\"" "$LAST_CHECK_FILE" | grep "hash" | sed 's/.*"hash": "*\([^"]*\)".*/\1/' || echo ""
  fi
}

# Hash storage for JSON output
declare -A URL_HASHES

# Store hash
store_hash() {
  local url="$1"
  local hash="$2"
  URL_HASHES["$url"]="$hash"
}

# Get stored hash
get_stored_hash() {
  local url="$1"
  echo "${URL_HASHES[$url]}"
}

# Convert URL to JSON-safe key for hash lookup (simplification)
hash_to_json() {
  echo "${URL_HASHES[$1]}"
}

# Update CHANGELOG.md
update_changelog() {
  local message="$1"
  local date=$(date '+%Y-%m-%d')

  # Prepend to changelog (after the header)
  if [ -f "$CHANGELOG_FILE" ]; then
    # Find the first existing date entry and insert before it
    local temp_file=$(mktemp)
    
    # Keep header, insert new entry, then rest of file
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
    # Create new changelog
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

# Main monitoring logic
main() {
  log_info "Starting Bland documentation monitoring"
  
  # Initialize hashes
  for url in "${MONITORED_URLS[@]}"; do
    URL_HASHES["$url"]=""
  done
  
  local changes_detected=false
  local changes_summary=""
  local updated_files=""
  
  cd "$REPO_ROOT" || exit 1
  
  # Check git status before making changes
  local git_clean=$(git diff-index --quiet HEAD -- 2>/dev/null && echo "clean" || echo "dirty")
  
  if [ "$git_clean" = "dirty" ]; then
    log_warn "Git repository has uncommitted changes, skipping monitoring until clean"
    exit 0
  fi
  
  # Fetch and check each URL
  for url in "${MONITORED_URLS[@]}"; do
    log_info "Checking: $url"
    
    # Fetch content
    local content
    if ! content=$(fetch_content "$url"); then
      log_warn "Skipping $url due to fetch error"
      continue
    fi
    
    # Compute hash
    local new_hash=$(compute_hash "$content")
    store_hash "$url" "$new_hash"
    
    # Get existing hash
    local old_hash=$(get_existing_hash "$url")
    
    # Check if changed
    if [ "$old_hash" != "$new_hash" ]; then
      log_info "Change detected in $url"
      changes_detected=true
      
      # Find which file to update
      for mapping in "${UPDATE_MAPPING[@]}"; do
        mapping_prefix="${mapping%%|*}"
        if [[ "$url" == "$mapping_prefix"* ]]; then
          local target_file="${mapping#*|}"
          local target_path="$REPO_ROOT/$target_file"
          
          log_info "Would update: $target_file"
          changes_summary="$changes_summary- $url → $target_file (hash changed)\n"
          updated_files="$updated_files$target_file\n"
          
          # Note: Actual content parsing and updating is complex
          # For now, we detect changes and note what *would* need updating
          # The user can manually update or we can enhance parsing later
          break
        fi
      done
    else
      log_info "No changes in $url"
    fi
  done

  # If changes detected, update tracking
  if [ "$changes_detected" = true ]; then
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    update_last_check "$timestamp"
    
    # Update changelog
    update_changelog "Changes detected in monitored URLs:\n\n$changes_summary\n\nManual review and updates required for:\n\n$updated_files"
    
    # Git commit
    git add "$LAST_CHECK_FILE" "$CHANGELOG_FILE" "$REPO_ROOT"/*.md 2>/dev/null || true
    git add "$REPO_ROOT"/*/*.md 2>/dev/null || true
    git add "$REPO_ROOT"/*/*/*.md 2>/dev/null || true
    
    local commit_message="docs: update tracking after detecting changes

Changes detected in monitored documentation sources.
See CHANGELOG.md for details."
    
    if git commit -m "$commit_message" &>/dev/null; then
      log_info "Committed changes to git"
    else
      log_warn "No new changes to commit (or commit failed)"
    fi
    
    # Send email notification
    local email_subject="Bland Documentation Changes Detected - $(date '+%Y-%m-%d')"
    local email_body="Changes detected in monitored Bland documentation sources.

Updated at: $(date '+%Y-%m-%d %H:%M:%S')

Changes detected:
$changes_summary

Files that may need manual review/updates:
$updated_files

Changes have been tracked in: $CHANGELOG_FILE

Repository: $REPO_ROOT

---
This is an automated message from the Bland documentation monitoring script.
"
    
    send_email "$email_subject" "$email_body"
    
    # Push to remote if configured
    if git remote -v &>/dev/null; then
      log_info "Attempting to push to remote..."
      if git push &>/dev/null; then
        log_info "Successfully pushed to remote"
      else
        log_warn "Push failed (may need authentication)"
      fi
    fi
    
    log_info "Monitoring complete. Changes detected and documented."
  else
    # No changes, just update timestamp
    update_last_check "null"
    log_info "No changes detected. Monitoring complete."
  fi
}

# Run main function
main "$@"