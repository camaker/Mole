#!/bin/bash
# User Data Cleanup Module

set -euo pipefail

# Clean user essentials (caches, logs, trash, crash reports)
clean_user_essentials() {
    safe_clean ~/Library/Caches/* "User app cache"
    safe_clean ~/Library/Logs/* "User app logs"
    safe_clean ~/.Trash/* "Trash"

    # Empty trash on mounted volumes
    if [[ -d "/Volumes" ]]; then
        for volume in /Volumes/*; do
            [[ -d "$volume" && -d "$volume/.Trashes" && -w "$volume" ]] || continue

            # Skip network volumes
            local fs_type=$(command df -T "$volume" 2> /dev/null | tail -1 | awk '{print $2}')
            case "$fs_type" in
                nfs | smbfs | afpfs | cifs | webdav) continue ;;
            esac

            # Verify volume is mounted and not a symlink
            mount | grep -q "on $volume " || continue
            [[ -L "$volume/.Trashes" ]] && continue
            [[ "$DRY_RUN" == "true" ]] && continue

            # Safely iterate and remove each item
            while IFS= read -r -d '' item; do
                safe_remove "$item" true || true
            done < <(command find "$volume/.Trashes" -mindepth 1 -maxdepth 1 -print0 2> /dev/null || true)
        done
    fi

    safe_clean ~/Library/DiagnosticReports/* "Diagnostic reports"
    safe_clean ~/Library/Caches/com.apple.QuickLook.thumbnailcache "QuickLook thumbnails"
    safe_clean ~/Library/Caches/Quick\ Look/* "QuickLook cache"
    safe_clean ~/Library/Caches/com.apple.iconservices* "Icon services cache"
    safe_clean ~/Library/Caches/CloudKit/* "CloudKit cache"

    # Clean incomplete downloads
    safe_clean ~/Downloads/*.download "Incomplete downloads (Safari)"
    safe_clean ~/Downloads/*.crdownload "Incomplete downloads (Chrome)"
    safe_clean ~/Downloads/*.part "Incomplete downloads (partial)"

    # Additional user-level caches
    safe_clean ~/Library/Autosave\ Information/* "Autosave information"
    safe_clean ~/Library/IdentityCaches/* "Identity caches"
    safe_clean ~/Library/Suggestions/* "Suggestions cache (Siri)"
    safe_clean ~/Library/Calendars/Calendar\ Cache "Calendar cache"
    safe_clean ~/Library/Application\ Support/AddressBook/Sources/*/Photos.cache "Address Book photo cache"
}

# Clean Finder metadata (.DS_Store files)
clean_finder_metadata() {
    if [[ "$PROTECT_FINDER_METADATA" == "true" ]]; then
        note_activity
        echo -e "  ${GRAY}${ICON_SUCCESS}${NC} Finder metadata (whitelisted)"
    else
        clean_ds_store_tree "$HOME" "Home directory (.DS_Store)"

        if [[ -d "/Volumes" ]]; then
            for volume in /Volumes/*; do
                [[ -d "$volume" && -w "$volume" ]] || continue

                local fs_type=""
                fs_type=$(command df -T "$volume" 2> /dev/null | tail -1 | awk '{print $2}')
                case "$fs_type" in
                    nfs | smbfs | afpfs | cifs | webdav) continue ;;
                esac

                clean_ds_store_tree "$volume" "$(basename "$volume") volume (.DS_Store)"
            done
        fi
    fi
}

# Clean macOS system caches
clean_macos_system_caches() {
    safe_clean ~/Library/Saved\ Application\ State/* "Saved application states"
    safe_clean ~/Library/Caches/com.apple.spotlight "Spotlight cache"

    # Clean Spotlight user caches (CoreSpotlight can grow very large)
    clean_spotlight_caches

    safe_clean ~/Library/Caches/com.apple.photoanalysisd "Photo analysis cache"
    safe_clean ~/Library/Caches/com.apple.akd "Apple ID cache"
    safe_clean ~/Library/Caches/com.apple.Safari/Webpage\ Previews/* "Safari webpage previews"
    safe_clean ~/Library/Application\ Support/CloudDocs/session/db/* "iCloud session cache"
    safe_clean ~/Library/Caches/com.apple.Safari/fsCachedData/* "Safari cached data"
    safe_clean ~/Library/Caches/com.apple.WebKit.WebContent/* "WebKit content cache"
    safe_clean ~/Library/Caches/com.apple.WebKit.Networking/* "WebKit network cache"
}

# Clean sandboxed app caches
clean_sandboxed_app_caches() {
    safe_clean ~/Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches/* "Wallpaper agent cache"
    safe_clean ~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/* "Media analysis cache"
    safe_clean ~/Library/Containers/com.apple.AppStore/Data/Library/Caches/* "App Store cache"
    safe_clean ~/Library/Containers/com.apple.configurator.xpc.InternetService/Data/tmp/* "Apple Configurator temp files"
    safe_clean ~/Library/Containers/*/Data/Library/Caches/* "Sandboxed app caches"
}

# Clean browser caches (Safari, Chrome, Edge, Firefox, etc.)
clean_browsers() {
    safe_clean ~/Library/Caches/com.apple.Safari/* "Safari cache"

    # Chrome/Chromium
    safe_clean ~/Library/Caches/Google/Chrome/* "Chrome cache"
    safe_clean ~/Library/Application\ Support/Google/Chrome/*/Application\ Cache/* "Chrome app cache"
    safe_clean ~/Library/Application\ Support/Google/Chrome/*/GPUCache/* "Chrome GPU cache"
    safe_clean ~/Library/Caches/Chromium/* "Chromium cache"

    safe_clean ~/Library/Caches/com.microsoft.edgemac/* "Edge cache"
    safe_clean ~/Library/Caches/company.thebrowser.Browser/* "Arc cache"
    safe_clean ~/Library/Caches/company.thebrowser.dia/* "Dia cache"
    safe_clean ~/Library/Caches/BraveSoftware/Brave-Browser/* "Brave cache"
    safe_clean ~/Library/Caches/Firefox/* "Firefox cache"
    safe_clean ~/Library/Caches/com.operasoftware.Opera/* "Opera cache"
    safe_clean ~/Library/Caches/com.vivaldi.Vivaldi/* "Vivaldi cache"
    safe_clean ~/Library/Caches/Comet/* "Comet cache"
    safe_clean ~/Library/Caches/com.kagi.kagimacOS/* "Orion cache"
    safe_clean ~/Library/Caches/zen/* "Zen cache"
    safe_clean ~/Library/Application\ Support/Firefox/Profiles/*/cache2/* "Firefox profile cache"

    # DISABLED: Service Worker CacheStorage scanning (find can hang on large browser profiles)
    # Browser caches are already cleaned by the safe_clean calls above
}

# Clean cloud storage app caches
clean_cloud_storage() {
    safe_clean ~/Library/Caches/com.dropbox.* "Dropbox cache"
    safe_clean ~/Library/Caches/com.getdropbox.dropbox "Dropbox cache"
    safe_clean ~/Library/Caches/com.google.GoogleDrive "Google Drive cache"
    safe_clean ~/Library/Caches/com.baidu.netdisk "Baidu Netdisk cache"
    safe_clean ~/Library/Caches/com.alibaba.teambitiondisk "Alibaba Cloud cache"
    safe_clean ~/Library/Caches/com.box.desktop "Box cache"
    safe_clean ~/Library/Caches/com.microsoft.OneDrive "OneDrive cache"
}

# Clean office application caches
clean_office_applications() {
    safe_clean ~/Library/Caches/com.microsoft.Word "Microsoft Word cache"
    safe_clean ~/Library/Caches/com.microsoft.Excel "Microsoft Excel cache"
    safe_clean ~/Library/Caches/com.microsoft.Powerpoint "Microsoft PowerPoint cache"
    safe_clean ~/Library/Caches/com.microsoft.Outlook/* "Microsoft Outlook cache"
    safe_clean ~/Library/Caches/com.apple.iWork.* "Apple iWork cache"
    safe_clean ~/Library/Caches/com.kingsoft.wpsoffice.mac "WPS Office cache"
    safe_clean ~/Library/Caches/org.mozilla.thunderbird/* "Thunderbird cache"
    safe_clean ~/Library/Caches/com.apple.mail/* "Apple Mail cache"
}

# Clean virtualization tools
clean_virtualization_tools() {
    safe_clean ~/Library/Caches/com.vmware.fusion "VMware Fusion cache"
    safe_clean ~/Library/Caches/com.parallels.* "Parallels cache"
    safe_clean ~/VirtualBox\ VMs/.cache "VirtualBox cache"
    safe_clean ~/.vagrant.d/tmp/* "Vagrant temporary files"
}

# Clean Application Support logs and caches
clean_application_support_logs() {
    # Check permission
    if [[ ! -d "$HOME/Library/Application Support" ]] || ! ls "$HOME/Library/Application Support" > /dev/null 2>&1; then
        note_activity
        echo -e "  ${YELLOW}${ICON_WARNING}${NC} Skipped: No permission to access Application Support"
        return 0
    fi

    # Clean log directories and cache patterns with iteration limit
    # Reduced from 200 to 50 to prevent hanging on large directories
    local iteration_count=0
    local max_iterations=50

    for app_dir in ~/Library/Application\ Support/*; do
        [[ -d "$app_dir" ]] || continue

        # Safety: limit iterations
        ((iteration_count++))
        if [[ $iteration_count -gt $max_iterations ]]; then
            break
        fi

        app_name=$(basename "$app_dir")

        # Skip system and protected apps (case-insensitive)
        local app_name_lower
        app_name_lower=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')
        case "$app_name_lower" in
            com.apple.* | adobe* | jetbrains* | 1password | claude | *clashx* | *clash* | mihomo* | *surge* | iterm* | warp* | kitty* | alacritty* | wezterm* | ghostty*)
                continue
                ;;
        esac

        # Clean log directories - simple direct removal without deep scanning
        [[ -d "$app_dir/log" ]] && safe_clean "$app_dir/log"/* "App logs: $app_name"
        [[ -d "$app_dir/logs" ]] && safe_clean "$app_dir/logs"/* "App logs: $app_name"
        [[ -d "$app_dir/activitylog" ]] && safe_clean "$app_dir/activitylog"/* "Activity logs: $app_name"

        # Clean common cache patterns - skip complex patterns that might hang
        [[ -d "$app_dir/Cache/Cache_Data" ]] && safe_clean "$app_dir/Cache/Cache_Data" "Cache data: $app_name"
        [[ -d "$app_dir/Crashpad/completed" ]] && safe_clean "$app_dir/Crashpad/completed"/* "Crash reports: $app_name"

        # DISABLED: Service Worker and update scanning (too slow, causes hanging)
        # These are covered by browser-specific cleaning in clean_browsers()
    done

    # Clean Group Containers logs - only scan known containers to avoid hanging
    # Direct path access is fast and won't cause performance issues
    # Add new containers here as users report them
    local known_group_containers=(
        "group.com.apple.contentdelivery" # Issue #104: Can accumulate 4GB+ in Library/Logs/Transporter
    )

    for container in "${known_group_containers[@]}"; do
        local container_path="$HOME/Library/Group Containers/$container"

        # Check both direct Logs and Library/Logs patterns
        if [[ -d "$container_path/Logs" ]]; then
            debug_log "Scanning Group Container: $container/Logs"
            safe_clean "$container_path/Logs"/* "Group container logs: $container"
        fi
        if [[ -d "$container_path/Library/Logs" ]]; then
            debug_log "Scanning Group Container: $container/Library/Logs"
            safe_clean "$container_path/Library/Logs"/* "Group container logs: $container"
        fi
    done
}

# Check and show iOS device backup info
check_ios_device_backups() {
    local backup_dir="$HOME/Library/Application Support/MobileSync/Backup"
    # Simplified check without find to avoid hanging
    if [[ -d "$backup_dir" ]]; then
        local backup_kb=$(get_path_size_kb "$backup_dir")
        if [[ -n "${backup_kb:-}" && "$backup_kb" -gt 102400 ]]; then
            local backup_human=$(command du -sh "$backup_dir" 2> /dev/null | awk '{print $1}')
            if [[ -n "$backup_human" ]]; then
                note_activity
                echo -e "  Found ${GREEN}${backup_human}${NC} iOS backups"
                echo -e "  You can delete them manually: ${backup_dir}"
            fi
        fi
    fi
}

# Clean Apple Silicon specific caches
# Env: IS_M_SERIES
clean_apple_silicon_caches() {
    if [[ "$IS_M_SERIES" != "true" ]]; then
        return 0
    fi

    safe_clean /Library/Apple/usr/share/rosetta/rosetta_update_bundle "Rosetta 2 cache"
    safe_clean ~/Library/Caches/com.apple.rosetta.update "Rosetta 2 user cache"
    safe_clean ~/Library/Caches/com.apple.amp.mediasevicesd "Apple Silicon media service cache"
}
