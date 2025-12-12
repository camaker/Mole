#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-system-clean.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "clean_deep_system issues safe sudo deletions" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
CALL_LOG="$HOME/system_calls.log"
> "$CALL_LOG"
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/system.sh"

safe_sudo_find_delete() {
    echo "safe_sudo_find_delete:$1:$2" >> "$CALL_LOG"
    return 0
}
safe_sudo_remove() {
    echo "safe_sudo_remove:$1" >> "$CALL_LOG"
    return 0
}
log_success() { :; }
is_sip_enabled() { return 1; }
get_file_mtime() { echo 0; }
get_path_size_kb() { echo 0; }
find() { return 0; }

clean_deep_system
cat "$CALL_LOG"
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"/Library/Caches"* ]]
    [[ "$output" == *"/private/tmp"* ]]
    [[ "$output" == *"/private/var/log"* ]]
}

@test "clean_deep_system skips /Library/Updates when SIP enabled" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
CALL_LOG="$HOME/system_calls_skip.log"
> "$CALL_LOG"
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/system.sh"

safe_sudo_find_delete() { return 0; }
safe_sudo_remove() {
    echo "REMOVE:$1" >> "$CALL_LOG"
    return 0
}
log_success() { :; }
is_sip_enabled() { return 0; } # SIP enabled -> skip removal
find() { return 0; }

clean_deep_system
cat "$CALL_LOG"
EOF

    [ "$status" -eq 0 ]
    [[ "$output" != *"/Library/Updates"* ]]
}

@test "clean_time_machine_failed_backups exits when tmutil has no destinations" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/system.sh"

tmutil() {
    if [[ "$1" == "destinationinfo" ]]; then
        echo "No destinations configured"
        return 0
    fi
    return 0
}
pgrep() { return 1; }
find() { return 0; }

clean_time_machine_failed_backups
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"No failed Time Machine backups found"* ]]
}

@test "clean_orphaned_casks uses cached mapping when recent" {
    cache_dir="$HOME/.cache/mole"
    mkdir -p "$cache_dir"
    cat > "$cache_dir/cask_apps.cache" <<'EOF'
fake-app|Fake.app
EOF

    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/brew.sh"

touch "$HOME/.cache/mole/cask_apps.cache"

brew() { return 0; }
start_inline_spinner(){ :; }
stop_inline_spinner(){ :; }
sudo() { return 0; }
MOLE_SPINNER_PREFIX=""
clean_orphaned_casks
EOF

    [ "$status" -eq 0 ]
}

@test "clean_homebrew skips when cleaned recently" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/brew.sh"

mkdir -p "$HOME/.cache/mole"
date +%s > "$HOME/.cache/mole/brew_last_cleanup"

brew() { return 0; }

clean_homebrew
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"cleaned"* ]]
}

@test "clean_homebrew runs cleanup with timeout stubs" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/brew.sh"

mkdir -p "$HOME/.cache/mole"
rm -f "$HOME/.cache/mole/brew_last_cleanup"

MO_BREW_TIMEOUT=2

start_inline_spinner(){ :; }
stop_inline_spinner(){ :; }

brew() {
    case "$1" in
        cleanup)
            echo "Removing: package"
            return 0
            ;;
        autoremove)
            echo "Uninstalling pkg"
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

clean_homebrew
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Homebrew cleanup"* ]]
}

@test "check_homebrew_updates reports counts and uses cache" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/check/all.sh"

brew() {
    if [[ "$1" == "outdated" && "$2" == "--quiet" ]]; then
        echo "pkg1"
        echo "pkg2"
        return 0
    fi
    if [[ "$1" == "outdated" && "$2" == "--cask" ]]; then
        echo "cask1"
        return 0
    fi
    return 0
}

start_inline_spinner(){ :; }
stop_inline_spinner(){ :; }

check_homebrew_updates

# second call should read cache (no spinner)
check_homebrew_updates
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Homebrew"* ]]
    [[ "$output" == *"2 formula"* ]]
}

@test "check_appstore_updates reports count from softwareupdate" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/check/all.sh"

softwareupdate() {
    echo "* Label: AppOne"
    echo "* Label: AppTwo"
    return 0
}

start_inline_spinner(){ :; }
stop_inline_spinner(){ :; }

check_appstore_updates
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"App Store"* ]]
    [[ "$output" == *"2 apps"* ]]
}

@test "check_macos_update warns when update available" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/check/all.sh"

softwareupdate() {
    echo "* Label: macOS 99"
    return 0
}

start_inline_spinner(){ :; }
stop_inline_spinner(){ :; }

check_macos_update
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"macOS"* ]]
}

@test "run_with_timeout succeeds without GNU timeout" {
    run bash --noprofile --norc -c '
        set -euo pipefail
        PATH="/usr/bin:/bin"
        unset MO_TIMEOUT_INITIALIZED MO_TIMEOUT_BIN
        source "'"$PROJECT_ROOT"'/lib/core/common.sh"
        run_with_timeout 1 sleep 0.1
    '
    [ "$status" -eq 0 ]
}

@test "run_with_timeout enforces timeout and returns 124" {
    run bash --noprofile --norc -c '
        set -euo pipefail
        PATH="/usr/bin:/bin"
        unset MO_TIMEOUT_INITIALIZED MO_TIMEOUT_BIN
        source "'"$PROJECT_ROOT"'/lib/core/common.sh"
        run_with_timeout 1 sleep 5
    '
    [ "$status" -eq 124 ]
}

@test "opt_recent_items removes shared file lists" {
    local shared_dir="$HOME/Library/Application Support/com.apple.sharedfilelist"
    mkdir -p "$shared_dir"
    touch "$shared_dir/test.sfl2"
    touch "$shared_dir/recent.sfl2"

    run env HOME="$HOME" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
# Mock sudo and defaults to avoid system changes
sudo() { return 0; }
defaults() { return 0; }
export -f sudo defaults
opt_recent_items
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Recent items cleared"* ]]
}

@test "opt_recent_items handles missing shared directory" {
    rm -rf "$HOME/Library/Application Support/com.apple.sharedfilelist"

    run env HOME="$HOME" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
sudo() { return 0; }
defaults() { return 0; }
export -f sudo defaults
opt_recent_items
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Recent items cleared"* ]]
}

@test "opt_saved_state_cleanup removes old saved states" {
    local state_dir="$HOME/Library/Saved Application State"
    mkdir -p "$state_dir/com.example.app.savedState"
    touch "$state_dir/com.example.app.savedState/data.plist"

    # Make the file old (8+ days) - MOLE_SAVED_STATE_AGE_DAYS defaults to 7
    touch -t 202301010000 "$state_dir/com.example.app.savedState/data.plist"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
opt_saved_state_cleanup
EOF

    [ "$status" -eq 0 ]
}

@test "opt_saved_state_cleanup handles missing state directory" {
    rm -rf "$HOME/Library/Saved Application State"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
opt_saved_state_cleanup
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"No saved states directory"* ]]
}

@test "opt_cache_refresh cleans Quick Look cache" {
    mkdir -p "$HOME/Library/Caches/com.apple.QuickLook.thumbnailcache"
    touch "$HOME/Library/Caches/com.apple.QuickLook.thumbnailcache/test.db"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
# Mock qlmanage and cleanup_path to avoid system calls
qlmanage() { return 0; }
cleanup_path() {
    local path="$1"
    local label="${2:-}"
    [[ -e "$path" ]] && rm -rf "$path" 2>/dev/null || true
}
export -f qlmanage cleanup_path
opt_cache_refresh
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Finder and Safari caches updated"* ]]
}

@test "opt_mail_downloads skips cleanup when size below threshold" {
    mkdir -p "$HOME/Library/Mail Downloads"
    # Create small file (below threshold of 5MB)
    echo "test" > "$HOME/Library/Mail Downloads/small.txt"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
# MOLE_MAIL_DOWNLOADS_MIN_KB is readonly, defaults to 5120 KB (~5MB)
opt_mail_downloads
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping cleanup"* ]]
    [ -f "$HOME/Library/Mail Downloads/small.txt" ]
}

@test "opt_mail_downloads removes old attachments" {
    mkdir -p "$HOME/Library/Mail Downloads"
    touch "$HOME/Library/Mail Downloads/old.pdf"
    # Make file old (31+ days) - MOLE_LOG_AGE_DAYS defaults to 30
    touch -t 202301010000 "$HOME/Library/Mail Downloads/old.pdf"

    # Create large enough size to trigger cleanup (>5MB threshold)
    dd if=/dev/zero of="$HOME/Library/Mail Downloads/dummy.dat" bs=1024 count=6000 2>/dev/null

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
# MOLE_MAIL_DOWNLOADS_MIN_KB and MOLE_LOG_AGE_DAYS are readonly constants
opt_mail_downloads
EOF

    [ "$status" -eq 0 ]
}

@test "get_path_size_kb returns zero for missing directory" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" MO_DEBUG=0 bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
size=$(get_path_size_kb "/nonexistent/path")
echo "$size"
EOF

    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "get_path_size_kb calculates directory size" {
    mkdir -p "$HOME/test_size"
    dd if=/dev/zero of="$HOME/test_size/file.dat" bs=1024 count=10 2>/dev/null

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" MO_DEBUG=0 bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
size=$(get_path_size_kb "$HOME/test_size")
echo "$size"
EOF

    [ "$status" -eq 0 ]
    # Should be >= 10 KB
    [ "$output" -ge 10 ]
}

@test "opt_log_cleanup runs cleanup_path and safe_sudo_find_delete" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"

CALLS_FILE="$HOME/log_cleanup_calls"
: > "$CALLS_FILE"

cleanup_path() {
    echo "cleanup:$1" >> "$CALLS_FILE"
}
safe_sudo_find_delete() {
    echo "safe:$1" >> "$CALLS_FILE"
    return 0
}

opt_log_cleanup
cat "$CALLS_FILE"
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"cleanup:$HOME/Library/Logs/DiagnosticReports"* ]]
    [[ "$output" == *"safe:/Library/Logs/DiagnosticReports"* ]]
}

@test "opt_fix_broken_configs reports fixes" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/maintenance.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"

fix_broken_preferences() {
    echo 2
}
fix_broken_login_items() {
    echo 1
}

opt_fix_broken_configs
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Fixed 2 broken preference files"* ]]
    [[ "$output" == *"Removed 1 broken login items"* ]]
}
