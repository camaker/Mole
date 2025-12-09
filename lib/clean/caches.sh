#!/bin/bash
# Cache Cleanup Module

set -euo pipefail

# Trigger all TCC permission dialogs upfront to avoid random interruptions
# Only runs once (uses ~/.cache/mole/permissions_granted flag)
check_tcc_permissions() {
    # Only check in interactive mode
    [[ -t 1 ]] || return 0

    local permission_flag="$HOME/.cache/mole/permissions_granted"

    # Skip if permissions were already granted
    [[ -f "$permission_flag" ]] && return 0

    # Key protected directories that require TCC approval
    local -a tcc_dirs=(
        "$HOME/Library/Caches"
        "$HOME/Library/Logs"
        "$HOME/Library/Application Support"
        "$HOME/Library/Containers"
        "$HOME/.cache"
    )

    # Quick permission test - if first directory is accessible, likely others are too
    # Use simple ls test instead of find to avoid triggering permission dialogs prematurely
    local needs_permission_check=false
    if ! ls "$HOME/Library/Caches" > /dev/null 2>&1; then
        needs_permission_check=true
    fi

    if [[ "$needs_permission_check" == "true" ]]; then
        echo ""
        echo -e "${BLUE}First-time setup${NC}"
        echo -e "${GRAY}macOS will request permissions to access Library folders.${NC}"
        echo -e "${GRAY}You may see ${GREEN}${#tcc_dirs[@]} permission dialogs${NC}${GRAY} - please approve them all.${NC}"
        echo ""
        echo -ne "${PURPLE}${ICON_ARROW}${NC} Press ${GREEN}Enter${NC} to continue: "
        read -r

        MOLE_SPINNER_PREFIX="" start_inline_spinner "Requesting permissions..."

        # Trigger all TCC prompts upfront by accessing each directory
        # Using find -maxdepth 1 ensures we touch the directory without deep scanning
        for dir in "${tcc_dirs[@]}"; do
            [[ -d "$dir" ]] && command find "$dir" -maxdepth 1 -type d > /dev/null 2>&1
        done

        stop_inline_spinner
        echo ""
    fi

    # Mark permissions as granted (won't prompt again)
    mkdir -p "$(dirname "$permission_flag")" 2> /dev/null || true
    touch "$permission_flag" 2> /dev/null || true
}

# Clean browser Service Worker cache, protecting web editing tools (capcut, photopea, pixlr)
# Args: $1=browser_name, $2=cache_path
clean_service_worker_cache() {
    local browser_name="$1"
    local cache_path="$2"

    [[ ! -d "$cache_path" ]] && return 0

    local cleaned_size=0
    local protected_count=0

    # Find all cache directories and calculate sizes with timeout protection
    while IFS= read -r cache_dir; do
        [[ ! -d "$cache_dir" ]] && continue

        # Extract domain from path using regex
        # Pattern matches: letters/numbers, hyphens, then dot, then TLD
        # Example: "abc123_https_example.com_0" → "example.com"
        local domain=$(basename "$cache_dir" | grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}' | head -1 || echo "")
        local size=$(run_with_timeout 5 get_path_size_kb "$cache_dir")

        # Check if domain is protected
        local is_protected=false
        for protected_domain in "${PROTECTED_SW_DOMAINS[@]}"; do
            if [[ "$domain" == *"$protected_domain"* ]]; then
                is_protected=true
                protected_count=$((protected_count + 1))
                break
            fi
        done

        # Clean if not protected
        if [[ "$is_protected" == "false" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                safe_remove "$cache_dir" true || true
            fi
            cleaned_size=$((cleaned_size + size))
        fi
    done < <(run_with_timeout 10 sh -c "find '$cache_path' -type d -depth 2 2> /dev/null || true")

    if [[ $cleaned_size -gt 0 ]]; then
        # Temporarily stop spinner for clean output
        local spinner_was_running=false
        if [[ -t 1 && -n "${INLINE_SPINNER_PID:-}" ]]; then
            stop_inline_spinner
            spinner_was_running=true
        fi

        local cleaned_mb=$((cleaned_size / 1024))
        if [[ "$DRY_RUN" != "true" ]]; then
            if [[ $protected_count -gt 0 ]]; then
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} $browser_name Service Worker (${cleaned_mb}MB, ${protected_count} protected)"
            else
                echo -e "  ${GREEN}${ICON_SUCCESS}${NC} $browser_name Service Worker (${cleaned_mb}MB)"
            fi
        else
            echo -e "  ${YELLOW}→${NC} $browser_name Service Worker (would clean ${cleaned_mb}MB, ${protected_count} protected)"
        fi
        note_activity

        # Restart spinner if it was running
        if [[ "$spinner_was_running" == "true" ]]; then
            MOLE_SPINNER_PREFIX="  " start_inline_spinner "Scanning browser Service Worker caches..."
        fi
    fi
}

# Clean Next.js (.next/cache) and Python (__pycache__) build caches
# Uses maxdepth 3, excludes Library/.Trash/node_modules, 10s timeout per scan
clean_project_caches() {
    # Clean Next.js caches
    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  "
        start_inline_spinner "Searching Next.js caches..."
    fi

    # Use timeout to prevent hanging on problematic directories
    local nextjs_tmp_file
    nextjs_tmp_file=$(create_temp_file)
    (
        command find "$HOME" -P -mount -type d -name ".next" -maxdepth 3 \
            -not -path "*/Library/*" \
            -not -path "*/.Trash/*" \
            -not -path "*/node_modules/*" \
            -not -path "*/.*" \
            2> /dev/null || true
    ) > "$nextjs_tmp_file" 2>&1 &
    local find_pid=$!
    local find_timeout=10
    local elapsed=0

    # Wait for find to complete or timeout
    while kill -0 $find_pid 2> /dev/null && [[ $elapsed -lt $find_timeout ]]; do
        sleep 1
        ((elapsed++))
    done

    # Kill if still running after timeout
    if kill -0 $find_pid 2> /dev/null; then
        kill -TERM $find_pid 2> /dev/null || true
        wait $find_pid 2> /dev/null || true
    else
        wait $find_pid 2> /dev/null || true
    fi

    # Clean found Next.js caches
    while IFS= read -r next_dir; do
        [[ -d "$next_dir/cache" ]] && safe_clean "$next_dir/cache"/* "Next.js build cache" || true
    done < "$nextjs_tmp_file"

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    # Clean Python bytecode caches
    if [[ -t 1 ]]; then
        MOLE_SPINNER_PREFIX="  "
        start_inline_spinner "Searching Python caches..."
    fi

    # Use timeout to prevent hanging on problematic directories
    local pycache_tmp_file
    pycache_tmp_file=$(create_temp_file)
    (
        command find "$HOME" -P -mount -type d -name "__pycache__" -maxdepth 3 \
            -not -path "*/Library/*" \
            -not -path "*/.Trash/*" \
            -not -path "*/node_modules/*" \
            -not -path "*/.*" \
            2> /dev/null || true
    ) > "$pycache_tmp_file" 2>&1 &
    local find_pid=$!
    local find_timeout=10
    local elapsed=0

    # Wait for find to complete or timeout
    while kill -0 $find_pid 2> /dev/null && [[ $elapsed -lt $find_timeout ]]; do
        sleep 1
        ((elapsed++))
    done

    # Kill if still running after timeout
    if kill -0 $find_pid 2> /dev/null; then
        kill -TERM $find_pid 2> /dev/null || true
        wait $find_pid 2> /dev/null || true
    else
        wait $find_pid 2> /dev/null || true
    fi

    # Clean found Python caches
    while IFS= read -r pycache; do
        [[ -d "$pycache" ]] && safe_clean "$pycache"/* "Python bytecode cache" || true
    done < "$pycache_tmp_file"

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi
}

# Clean Spotlight user caches
# Cleans CoreSpotlight index cache and Spotlight saved state
# System Spotlight index (/System/Volumes/Data/.Spotlight-V100) is never touched
clean_spotlight_caches() {
    local cleaned_size=0
    local cleaned_count=0

    # CoreSpotlight user cache (can grow very large, safe to delete)
    local spotlight_cache="$HOME/Library/Metadata/CoreSpotlight"
    if [[ -d "$spotlight_cache" ]]; then
        local size_kb=$(get_path_size_kb "$spotlight_cache")
        if [[ "$size_kb" -gt 0 ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                safe_remove "$spotlight_cache" true && {
                    ((cleaned_size += size_kb))
                    ((cleaned_count++))
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Spotlight cache ($(bytes_to_human $((size_kb * 1024))))"
                    note_activity
                }
            else
                ((cleaned_size += size_kb))
                echo -e "  ${YELLOW}→${NC} Spotlight cache (would clean $(bytes_to_human $((size_kb * 1024))))"
                note_activity
            fi
        fi
    fi

    # Spotlight saved application state
    local spotlight_state="$HOME/Library/Saved Application State/com.apple.spotlight.Spotlight.savedState"
    if [[ -d "$spotlight_state" ]]; then
        local size_kb=$(get_path_size_kb "$spotlight_state")
        if [[ "$size_kb" -gt 0 ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                safe_remove "$spotlight_state" true && {
                    ((cleaned_size += size_kb))
                    ((cleaned_count++))
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Spotlight state ($(bytes_to_human $((size_kb * 1024))))"
                    note_activity
                }
            else
                ((cleaned_size += size_kb))
                echo -e "  ${YELLOW}→${NC} Spotlight state (would clean $(bytes_to_human $((size_kb * 1024))))"
                note_activity
            fi
        fi
    fi

    if [[ $cleaned_size -gt 0 ]]; then
        ((files_cleaned += cleaned_count))
        ((total_size_cleaned += cleaned_size))
        ((total_items++))
    fi
}
