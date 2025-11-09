# Mole Integrations

Quick launcher integrations for Mole.

## Raycast

One command install:

```bash
curl -fsSL https://raw.githubusercontent.com/tw93/Mole/main/integrations/setup-raycast.sh | bash
```

Then open Raycast and search "Reload Script Commands".

Available commands: `clean mac`, `dry run`, `uninstall apps`

## Alfred

Add a workflow with keyword `clean` and script:

```bash
mo clean
```

For dry-run: `mo clean --dry-run`

For uninstall: `mo uninstall`

## macOS Shortcuts

Create a shortcut with "Run Shell Script":

```bash
mo clean
```

Then add to Menu Bar or assign a keyboard shortcut.

## Uninstall

```bash
rm -rf ~/Library/Application\ Support/Raycast/script-commands/mole-*.sh
```
