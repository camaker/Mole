#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clean Mac (Dry Run)
# @raycast.mode fullOutput
# @raycast.packageName Mole

# Optional parameters:
# @raycast.icon 👀
# @raycast.needsConfirmation false

# Documentation:
# @raycast.description Preview what Mole would clean without making changes
# @raycast.author tw93
# @raycast.authorURL https://github.com/tw93/Mole

# Detect mo/mole installation
if command -v mo >/dev/null 2>&1; then
    MO_BIN="mo"
elif command -v mole >/dev/null 2>&1; then
    MO_BIN="mole"
else
    echo "❌ Mole not found. Install from:"
    echo "   https://github.com/tw93/Mole"
    exit 1
fi

# Run dry-run
echo "👀 Previewing cleanup..."
echo ""
"$MO_BIN" clean --dry-run
