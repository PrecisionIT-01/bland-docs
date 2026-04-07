#!/bin/bash

# Sync docs from bland-docs to all client repos
# Only copies operational docs (CLI, MCP, workflows) - no automation/sync docs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CLIENTS_FILE="$REPO_ROOT/clients.json"
CLIENTS_DIR="$REPO_ROOT/clients"
ORG="Bland-Applied-Solutions"
README_TEMPLATE="$REPO_ROOT/templates/client-README.md"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_info() { log "${GREEN}✓${NC} $1"; }
log_warn() { log "${YELLOW}!${NC} $1"; }
log_error() { log "${RED}✗${NC} $1"; }

sync_client() {
  local name="$1"
  local repo="$2"
  local client_dir="$CLIENTS_DIR/$repo"
  
  log "Syncing: $name ($repo)"
  
  if [ ! -d "$client_dir" ]; then
    log_info "Cloning $repo..."
    gh repo clone "$ORG/$repo" "$client_dir" 2>/dev/null || return 1
  fi
  
  cd "$client_dir"
  git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
  
  log_info "Copying operational docs..."
  
  # Create directory structure
  mkdir -p setup reference workflows
  
  # Copy ONLY operational docs (no monitoring, no sync scripts)
  cp "$REPO_ROOT/setup/installation.md" ./setup/ 2>/dev/null || true
  cp "$REPO_ROOT/setup/cursor-integration.md" ./setup/ 2>/dev/null || true
  
  cp "$REPO_ROOT/reference/cli-commands.md" ./reference/ 2>/dev/null || true
  cp "$REPO_ROOT/reference/mcp-tools.md" ./reference/ 2>/dev/null || true
  cp "$REPO_ROOT/reference/tools.md" ./reference/ 2>/dev/null || true
  cp "$REPO_ROOT/reference/webhooks.md" ./reference/ 2>/dev/null || true
  cp "$REPO_ROOT/reference/personas.md" ./reference/ 2>/dev/null || true
  cp "$REPO_ROOT/reference/custom-code-node.md" ./reference/ 2>/dev/null || true
  cp "$REPO_ROOT/reference/web-agent-sdk.md" ./reference/ 2>/dev/null || true
  
  cp "$REPO_ROOT/workflows/troubleshooting.md" ./workflows/ 2>/dev/null || true
  cp "$REPO_ROOT/workflows/testing.md" ./workflows/ 2>/dev/null || true
  cp "$REPO_ROOT/workflows/daily-tasks.md" ./workflows/ 2>/dev/null || true
  
  # Remove automation/sync files that shouldn't be in client repos
  rm -rf monitoring/ 2>/dev/null || true
  rm -rf scripts/ 2>/dev/null || true
  rm -f clients.json 2>/dev/null || true
  rm -f clients-to-add.json 2>/dev/null || true
  rm -f .latest_changes.txt 2>/dev/null || true
  
  # Write client-specific README
  if [ -f "$README_TEMPLATE" ]; then
    sed "s/{{CLIENT_NAME}}/$name/g" "$README_TEMPLATE" > README.md
  fi
  
  # Ensure .gitignore has .env
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
  
  # Ensure .env.example exists
  if [ ! -f .env.example ]; then
    cat > .env.example << 'EOF'
# Bland AI Credentials
BLAND_API_KEY=your_api_key_here
BLAND_ORG_ID=your_org_id_here
PLANHAT_ID=your_planhat_id_here
SLACK_CHANNEL=your_slack_channel_here
CLIENT_NAME="Client Name"
EOF
  fi
  
  git add -A 2>/dev/null || true
  
  if git diff --cached --quiet 2>/dev/null; then
    log_warn "No changes for $repo"
  else
    git commit -m "docs: sync operational docs

$(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null
    git push origin main 2>/dev/null || git push 2>/dev/null
    log_info "Pushed to $repo"
  fi
  
  cd "$REPO_ROOT"
  return 0
}

main() {
  log "Syncing operational docs to clients..."
  mkdir -p "$CLIENTS_DIR"
  
  local total=$(jq '.clients | length' "$CLIENTS_FILE")
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
  
  log "Done! ✓ $success  ✗ $failed"
}

main "$@"