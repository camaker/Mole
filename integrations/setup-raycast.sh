#!/bin/bash
# One-line Raycast integration installer
# Usage: curl -fsSL https://raw.githubusercontent.com/tw93/Mole/main/integrations/setup-raycast.sh | bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

RAYCAST_DIR="$HOME/Library/Application Support/Raycast/script-commands"
BASE_URL="https://raw.githubusercontent.com/tw93/Mole/main/integrations/raycast"

# Check Raycast
if [[ ! -d "$HOME/Library/Application Support/Raycast" ]]; then
    echo -e "${YELLOW}Raycast not found. Install from: https://raycast.com${NC}"
    exit 1
fi

echo "Installing Mole commands for Raycast..."
mkdir -p "$RAYCAST_DIR"

# Download scripts
for script in mole-clean.sh mole-clean-dry-run.sh mole-uninstall.sh; do
    curl -fsSL "$BASE_URL/$script" -o "$RAYCAST_DIR/$script"
    chmod +x "$RAYCAST_DIR/$script"
done

echo -e "${GREEN}✓${NC} Installed! Open Raycast and search: 'Reload Script Commands'"
echo ""
echo "Then search for: 'Clean Mac'"
