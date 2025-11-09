#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clean Mac
# @raycast.mode fullOutput
# @raycast.packageName Mole

# Optional parameters:
# @raycast.icon 🐹
# @raycast.needsConfirmation true

# Documentation:
# @raycast.description Deep clean your Mac using Mole
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

# Run cleanup
echo "🐹 Starting cleanup..."
echo ""
"$MO_BIN" clean
