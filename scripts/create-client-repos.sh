#!/bin/bash

# Batch create client repos in Bland-Applied-Solutions org
# Uses HTTPS with PAT for reliable access

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CLIENTS_FILE="$REPO_ROOT/clients-to-add.json"
CLIENTS_DIR="$REPO_ROOT/clients"
ORG="Bland-Applied-Solutions"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_info() { log "${GREEN}✓${NC} $1"; }
log_warn() { log "${YELLOW}!${NC} $1"; }
log_error() { log "${RED}✗${NC} $1"; }

# Slugify name
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Create a single client repo
create_client_repo() {
  local name="$1"
  local api_key="$2"
  local org_id="$3"
  local planhat_id="$4"
  local slack_channel="$5"
  
  local repo_name=$(slugify "$name")
  local client_dir="$CLIENTS_DIR/$repo_name"
  
  log "Processing: $name → $repo_name"
  
  # Check if repo already exists locally
  if [ -d "$client_dir" ]; then
    log_warn "Directory exists for $repo_name, skipping"
    return 0
  fi
  
  # Check if repo exists on GitHub
  if gh repo view "$ORG/$repo_name" &>/dev/null; then
    log_warn "Repo $repo_name already exists on GitHub"
  else
    # Create the repo
    if gh repo create "$ORG/$repo_name" \
      --private \
      --description "Bland AI documentation and workflows for $name" \
      2>/dev/null; then
      log_info "Created repo: $ORG/$repo_name"
    else
      log_error "Failed to create repo: $ORG/$repo_name"
      return 1
    fi
  fi
  
  # Clone using gh (uses HTTPS with auth)
  log_info "Cloning repo..."
  if ! gh repo clone "$ORG/$repo_name" "$client_dir" 2>/dev/null; then
    log_error "Failed to clone $repo_name"
    return 1
  fi
  
  cd "$client_dir"
  
  # Copy docs from bland-docs
  log_info "Copying docs..."
  cp -r "$REPO_ROOT/setup" . 2>/dev/null || mkdir -p setup
  cp -r "$REPO_ROOT/reference" . 2>/dev/null || mkdir -p reference
  cp -r "$REPO_ROOT/workflows" . 2>/dev/null || mkdir -p workflows
  cp -r "$REPO_ROOT/monitoring" . 2>/dev/null || mkdir -p monitoring
  cp "$REPO_ROOT/README.md" . 2>/dev/null || true
  mkdir -p scripts
  cp "$REPO_ROOT/scripts/monitor-bland-docs.sh" ./scripts/ 2>/dev/null || true
  
  # Create .env file with credentials
  cat > .env << EOF
# Bland AI Credentials for $name
# DO NOT COMMIT THIS FILE

BLAND_API_KEY=${api_key:-""}
BLAND_ORG_ID=${org_id:-""}
PLANHAT_ID=${planhat_id:-""}
SLACK_CHANNEL=${slack_channel:-""}
CLIENT_NAME="$name"
EOF
  
  # Create .env.example
  cat > .env.example << 'EOF'
# Bland AI Credentials Template
BLAND_API_KEY=your_api_key_here
BLAND_ORG_ID=your_org_id_here
PLANHAT_ID=your_planhat_id_here
SLACK_CHANNEL=your_slack_channel_here
CLIENT_NAME="Client Name"
EOF
  
  # Create .gitignore
  cat > .gitignore << 'EOF'
.env
.env.local
.env.*.local
.DS_Store
Thumbs.db
.idea/
.vscode/
*.swp
node_modules/
*.log
EOF
  
  # Update README
  sed -i "s/# Bland CLI Documentation/# Bland CLI Documentation - $name/" README.md 2>/dev/null || true
  
  # Commit and push
  git add -A 2>/dev/null || true
  
  if git diff --cached --quiet 2>/dev/null; then
    log_warn "No changes to commit"
  else
    git commit -m "Initialize client repo with Bland docs

Client: $name
Planhat ID: ${planhat_id:-N/A}

Includes setup, reference, workflows, monitoring, and credentials (.env gitignored)" 2>/dev/null
    
    git push origin main 2>/dev/null || git push -u origin main 2>/dev/null
    log_info "Pushed to $repo_name"
  fi
  
  cd "$REPO_ROOT"
  return 0
}

# Main
main() {
  log "Batch creating client repos in $ORG"
  
  mkdir -p "$CLIENTS_DIR"
  
  local total=$(jq 'length' "$CLIENTS_FILE")
  log "Total clients: $total"
  
  local i=0 success=0 failed=0
  
  while IFS= read -r client; do
    i=$((i + 1))
    
    name=$(echo "$client" | jq -r '.name')
    api_key=$(echo "$client" | jq -r '.bland_api_key // empty')
    org_id=$(echo "$client" | jq -r '.bland_org_id // empty')
    planhat_id=$(echo "$client" | jq -r '.planhat_id // empty')
    slack_channel=$(echo "$client" | jq -r '.slack_channel // empty')
    
    log "[$i/$total] $name"
    
    if create_client_repo "$name" "$api_key" "$org_id" "$planhat_id" "$slack_channel"; then
      success=$((success + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(jq -c '.[]' "$CLIENTS_FILE")
  
  log "Done! ✓ $success  ✗ $failed"
}

main "$@"