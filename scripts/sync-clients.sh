#!/bin/bash

# Sync docs from bland-docs to all client repos
# Called by monitor-bland-docs.sh after changes detected

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CLIENTS_FILE="$REPO_ROOT/clients.json"
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

# Sync a single client repo
sync_client() {
  local name="$1"
  local repo="$2"
  local client_dir="$CLIENTS_DIR/$repo"
  
  log "Syncing: $name ($repo)"
  
  # Clone if needed
  if [ ! -d "$client_dir" ]; then
    log_info "Cloning $repo..."
    gh repo clone "$ORG/$repo" "$client_dir" 2>/dev/null || {
      log_error "Failed to clone $repo"
      return 1
    }
  fi
  
  cd "$client_dir"
  
  # Pull latest
  git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
  
  # Copy docs from bland-docs (preserve .env)
  log_info "Copying docs..."
  
  # Copy directories
  cp -r "$REPO_ROOT/setup" . 2>/dev/null || true
  cp -r "$REPO_ROOT/reference" . 2>/dev/null || true
  cp -r "$REPO_ROOT/workflows" . 2>/dev/null || true
  cp -r "$REPO_ROOT/monitoring" . 2>/dev/null || true
  
  # Copy scripts
  mkdir -p scripts
  cp "$REPO_ROOT/scripts/monitor-bland-docs.sh" ./scripts/ 2>/dev/null || true
  
  # Copy README (update title to keep client name)
  if [ -f "$REPO_ROOT/README.md" ]; then
    # Preserve client-specific title if already set
    if head -1 README.md 2>/dev/null | grep -q "Bland CLI Documentation"; then
      sed -i "s/# Bland CLI Documentation.*/# Bland CLI Documentation - $name/" README.md 2>/dev/null || true
    fi
  fi
  
  # Update .gitignore if needed
  if [ ! -f .gitignore ]; then
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
  fi
  
  # Update .env.example
  if [ ! -f .env.example ]; then
    cat > .env.example << 'EOF'
BLAND_API_KEY=your_api_key_here
BLAND_ORG_ID=your_org_id_here
PLANHAT_ID=your_planhat_id_here
SLACK_CHANNEL=your_slack_channel_here
CLIENT_NAME="Client Name"
EOF
  fi
  
  # Git operations
  git add -A 2>/dev/null || true
  
  if git diff --cached --quiet 2>/dev/null; then
    log_warn "No changes for $repo"
  else
    git commit -m "docs: sync from bland-docs

Updated: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null
    
    git push origin main 2>/dev/null || git push 2>/dev/null
    log_info "Pushed to $repo"
  fi
  
  cd "$REPO_ROOT"
  return 0
}

# Main
main() {
  log "Starting client sync..."
  log "Clients file: $CLIENTS_FILE"
  
  mkdir -p "$CLIENTS_DIR"
  
  local total=$(jq '.clients | length' "$CLIENTS_FILE")
  log "Total clients: $total"
  
  local i=0 success=0 failed=0
  
  while IFS= read -r client; do
    i=$((i + 1))
    
    name=$(echo "$client" | jq -r '.name')
    repo=$(echo "$client" | jq -r '.repo')
    
    log "[$i/$total] $name"
    
    if sync_client "$name" "$repo"; then
      success=$((success + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(jq -c '.clients[]' "$CLIENTS_FILE")
  
  log "Sync complete! ✓ $success  ✗ $failed"
}

main "$@"