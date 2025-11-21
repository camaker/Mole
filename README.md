<div align="center">
  <h1>Mole</h1>
  <p><em>Dig deep like a mole to clean your Mac.</em></p>
</div>

<p align="center">
  <a href="https://github.com/tw93/mole/stargazers"><img src="https://img.shields.io/github/stars/tw93/mole?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/tw93/mole/releases"><img src="https://img.shields.io/github/v/tag/tw93/mole?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="https://github.com/tw93/mole/commits"><img src="https://img.shields.io/github/commit-activity/m/tw93/mole?style=flat-square" alt="Commits"></a>
  <a href="https://twitter.com/HiTw93"><img src="https://img.shields.io/badge/follow-Tw93-red?style=flat-square&logo=Twitter" alt="Twitter"></a>
  <a href="https://t.me/+GclQS9ZnxyI2ODQ1"><img src="https://img.shields.io/badge/chat-Telegram-blueviolet?style=flat-square&logo=Telegram" alt="Telegram"></a>
</p>

<p align="center">
  <img src="https://cdn.tw93.fun/img/mole.jpeg" alt="Mole - 95.50GB freed" width="800" />
  <p align="center">由于 Mole 还在中级版本，如果这台 Mac 对你非常重要，建议再等等。</p>
</p>

## Features

- **Deep System Cleanup** - Cleans way more junk than CleanMyMac/Lemon - caches, logs, temp files
- **Thorough Uninstall** - Scans 22+ locations to remove app leftovers, not just the .app file
- **System Optimization** - Rebuilds caches, resets services, and trims swap/network cruft with one run
- **Interactive Disk Analyzer** - Navigate folders with arrow keys, find and delete large files quickly
- **System Status Dashboard** - Real-time health score with live CPU/GPU/Memory/Disk/Network/Battery metrics
- **Fast & Lightweight** - Terminal-based with arrow-key navigation, pagination, and Touch ID support

## Quick Start

**Install:**

```bash
curl -fsSL https://raw.githubusercontent.com/tw93/mole/main/install.sh | bash
```

Or via Homebrew:

```bash
brew install tw93/tap/mole
```

**Run:**

```bash
mo                      # Interactive menu
mo clean                # System cleanup
mo clean --dry-run      # Preview mode
mo clean --whitelist    # Manage protected caches
mo uninstall            # Uninstall apps
mo optimize             # System optimization
mo analyze              # Disk analyzer
mo status               # Live system status dashboard

mo touchid              # Configure Touch ID for sudo
mo update               # Update Mole
mo remove               # Remove Mole from system
mo --help               # Show help
mo --version            # Show installed version

```

## Tips

- Safety first, if your Mac is mission-critical, wait for Mole to mature before full cleanups.
- Preview the cleanup by running `mo clean --dry-run` and reviewing the generated list.
- Use `mo clean --whitelist` to manage protected caches.
- Use `mo touchid` to approve sudo with Touch ID instead of typing your password.

## Features in Detail

### Deep System Cleanup

```bash
$ mo clean

Scanning cache directories...

  ✓ User app cache                                           45.2GB
  ✓ Browser cache (Chrome, Safari, Firefox)                  10.5GB
  ✓ Developer tools (Xcode, Node.js, npm)                    23.3GB
  ✓ System logs and temp files                                3.8GB
  ✓ App-specific cache (Spotify, Dropbox, Slack)              8.4GB
  ✓ Trash                                                     12.3GB

====================================================================
Space freed: 95.5GB | Free space now: 223.5GB
====================================================================
```

### Smart App Uninstaller

```bash
$ mo uninstall

Select Apps to Remove
═══════════════════════════
▶ ☑ Adobe Creative Cloud      (12.4G) | Old
  ☐ WeChat                    (2.1G) | Recent
  ☐ Final Cut Pro             (3.8G) | Recent

Uninstalling: Adobe Creative Cloud

  ✓ Removed application
  ✓ Cleaned 52 related files across 12 locations
    - Application Support, Caches, Preferences
    - Logs, WebKit storage, Cookies
    - Extensions, Plugins, Launch daemons

====================================================================
Space freed: 12.8GB
====================================================================
```

### System Optimization

```bash
$ mo optimize

System: 5/32 GB RAM | 333/460 GB Disk (72%) | Uptime 6d

  ✓ Rebuild system databases and flush caches
  ✓ Reset network services
  ✓ Refresh Finder and Dock
  ✓ Clean diagnostic and crash logs
  ✓ Purge swap files and restart dynamic pager
  ✓ Rebuild launch services and spotlight index

====================================================================
System optimization completed
====================================================================
```

### Disk Space Analyzer

```bash
$ mo analyze

Analyze Disk  ~/Documents  |  Total: 156.8GB

 ▶  1. ███████████████████  48.2%  |  📁 Library                     75.4GB  >6mo
    2. ██████████░░░░░░░░░  22.1%  |  📁 Downloads                   34.6GB
    3. ████░░░░░░░░░░░░░░░  14.3%  |  📁 Movies                      22.4GB
    4. ███░░░░░░░░░░░░░░░░  10.8%  |  📁 Documents                   16.9GB
    5. ██░░░░░░░░░░░░░░░░░   5.2%  |  📄 backup_2023.zip              8.2GB

  ↑↓←→ Navigate  |  O Open  |  F Reveal  |  ⌫ Delete  |  L Large(24)  |  Q Quit
```

### Live System Status

Real-time dashboard with system health score, hardware info, and performance metrics.

```bash
$ mo status

Mole Status  Health ● 92  MacBook Pro · Apple M4 Pro · 32.0 GB · 460.4 GB · macOS 14.5

⚙ CPU ──────────────────────          ▦ Memory ─────────────────────
Total  ████████████░░░░░░ 45.2%       Used   ███████████░░░░░░ 58.4%
0.82 / 1.05 / 1.23  (8 cores)         14.2 GB / 24.0 GB total
Core1  ███████████████░░░ 78.3%       Free   ████████░░░░░░░░░ 41.6%
Core2  ████████████░░░░░░ 62.1%       9.8 GB available

▤ Disk ──────────────────────       ▮ Power ──────────────────────
Used   █████████████░░░░░ 67.2%       100%   ██████████████████ 100%
156.3 GB free                         Charged ⚡
Read   ▮▯▯▯▯  2.1 MB/s                Normal · 423 cycles
Write  ▮▮▮▯▯  18.3 MB/s               58°C · 1200 RPM

⇅ Network ───────────────────       ▶ Processes ───────────────────
Down   ▮▮▯▯▯  3.2 MB/s                Code      ▮▮▮▮▯  42.1%
Up     ▮▯▯▯▯  0.8 MB/s                Chrome    ▮▮▮▯▯  28.3%
Proxy: HTTP · 192.168.1.100          Terminal  ▮▯▯▯▯  12.5%
```

Health score is calculated from CPU usage, memory pressure, disk space, temperature, and I/O load. Color-coded: 90-100 green, 75-89 light green, 60-74 yellow, 40-59 orange, 0-39 red.

## Quick Launchers

Launch Mole commands instantly from Raycast or Alfred:

```bash
curl -fsSL https://raw.githubusercontent.com/tw93/Mole/main/scripts/setup-quick-launchers.sh | bash
```

Adds 5 commands: `clean`, `uninstall`, `optimize`, `analyze`, `status`. Auto-detects your terminal or set `MO_LAUNCHER_APP=<name>` to override.

**Reload Raycast scripts after installation:**

1. Open Raycast (⌘ Space)
2. Search for "Reload Script Directories"
3. Press Enter to activate new commands

Alternatively, restart Raycast to load the new scripts.

## Support

<a href="https://miaoyan.app/cats.html?name=Mole"><img src="https://miaoyan.app/assets/sponsors.svg" width="1000px" /></a>

- If Mole reclaimed storage for you, consider starring the repo or sharing it with friends needing a cleaner Mac.
- Have ideas or fixes? Open an issue or PR and help shape Mole's roadmap together with the community.
- Love cats? Treat Tangyuan and Cola to canned food via <a href="https://miaoyan.app/cats.html?name=Mole" target="_blank">this link</a> and keep the mascots purring.

## License

MIT License - feel free to enjoy and participate in open source.
