#!/bin/bash
# Update Manager
# Unified update execution for all update types

set -euo pipefail

# Format Homebrew update label for display
format_brew_update_label() {
    local total="${BREW_OUTDATED_COUNT:-0}"
    if [[ -z "$total" || "$total" -le 0 ]]; then
        return
    fi

    local -a details=()
    local formulas="${BREW_FORMULA_OUTDATED_COUNT:-0}"
    local casks="${BREW_CASK_OUTDATED_COUNT:-0}"

    ((formulas > 0)) && details+=("${formulas} formula")
    ((casks > 0)) && details+=("${casks} cask")

    local detail_str="(${total} updates)"
    if ((${#details[@]} > 0)); then
        detail_str="($(
            IFS=', '
            printf '%s' "${details[*]}"
        ))"
    fi
    printf "  • Homebrew %s" "$detail_str"
}

brew_has_outdated() {
    local kind="${1:-formula}"
    command -v brew > /dev/null 2>&1 || return 1

    if [[ "$kind" == "cask" ]]; then
        brew outdated --cask --quiet 2> /dev/null | grep -q .
    else
        brew outdated --quiet 2> /dev/null | grep -q .
    fi
}

# Ask user if they want to update
# Returns: 0 if yes, 1 if no
ask_for_updates() {
    local has_updates=false
    local -a update_list=()

    local brew_entry
    brew_entry=$(format_brew_update_label || true)
    if [[ -n "$brew_entry" ]]; then
        has_updates=true
        update_list+=("$brew_entry")
    fi

    if [[ -n "${APPSTORE_UPDATE_COUNT:-}" && "${APPSTORE_UPDATE_COUNT:-0}" -gt 0 ]]; then
        has_updates=true
        update_list+=("  • App Store (${APPSTORE_UPDATE_COUNT} apps)")
    fi

    if [[ -n "${MACOS_UPDATE_AVAILABLE:-}" && "${MACOS_UPDATE_AVAILABLE}" == "true" ]]; then
        has_updates=true
        update_list+=("  • macOS system")
    fi

    if [[ -n "${MOLE_UPDATE_AVAILABLE:-}" && "${MOLE_UPDATE_AVAILABLE}" == "true" ]]; then
        has_updates=true
        update_list+=("  • Mole")
    fi

    if [[ "$has_updates" == "false" ]]; then
        return 1
    fi

    echo -e "${BLUE}AVAILABLE UPDATES${NC}"
    for item in "${update_list[@]}"; do
        echo -e "$item"
    done
    echo ""
    echo -ne "${YELLOW}Update all now?${NC} ${GRAY}Enter confirm / ESC cancel${NC}: "

    local key
    if ! key=$(read_key); then
        echo "skip"
        echo ""
        return 1
    fi

    if [[ "$key" == "ENTER" ]]; then
        echo "yes"
        echo ""
        return 0
    else
        echo "skip"
        echo ""
        return 1
    fi
}

# Perform all pending updates
# Returns: 0 if all succeeded, 1 if some failed
perform_updates() {
    local updated_count=0
    local total_count=0
    local brew_formula="${BREW_FORMULA_OUTDATED_COUNT:-0}"
    local brew_cask="${BREW_CASK_OUTDATED_COUNT:-0}"

    # Get update labels
    local -a appstore_labels=()
    if [[ -n "${APPSTORE_UPDATE_COUNT:-}" && "${APPSTORE_UPDATE_COUNT:-0}" -gt 0 ]]; then
        while IFS= read -r label; do
            [[ -n "$label" ]] && appstore_labels+=("$label")
        done < <(get_appstore_update_labels || true)
    fi

    local -a macos_labels=()
    if [[ -n "${MACOS_UPDATE_AVAILABLE:-}" && "${MACOS_UPDATE_AVAILABLE}" == "true" ]]; then
        while IFS= read -r label; do
            [[ -n "$label" ]] && macos_labels+=("$label")
        done < <(get_macos_update_labels || true)
    fi

    # Check fallback needed
    local appstore_needs_fallback=false
    local macos_needs_fallback=false
    if [[ -n "${APPSTORE_UPDATE_COUNT:-}" && "${APPSTORE_UPDATE_COUNT:-0}" -gt 0 && ${#appstore_labels[@]} -eq 0 ]]; then
        appstore_needs_fallback=true
    fi
    if [[ -n "${MACOS_UPDATE_AVAILABLE:-}" && "${MACOS_UPDATE_AVAILABLE}" == "true" && ${#macos_labels[@]} -eq 0 ]]; then
        macos_needs_fallback=true
    fi

    # Count total updates
    ((brew_formula > 0)) && ((total_count++))
    ((brew_cask > 0)) && ((total_count++))
    [[ -n "${APPSTORE_UPDATE_COUNT:-}" && "${APPSTORE_UPDATE_COUNT:-0}" -gt 0 ]] && ((total_count++))
    [[ -n "${MACOS_UPDATE_AVAILABLE:-}" && "${MACOS_UPDATE_AVAILABLE}" == "true" ]] && ((total_count++))
    [[ -n "${MOLE_UPDATE_AVAILABLE:-}" && "${MOLE_UPDATE_AVAILABLE}" == "true" ]] && ((total_count++))

    # Update Homebrew formulae
    if ((brew_formula > 0)); then
        if ! brew_has_outdated "formula"; then
            echo -e "${GRAY}-${NC} Homebrew formulae already up to date"
            ((total_count--))
            echo ""
        else
            echo -e "${BLUE}Updating Homebrew formulae...${NC}"
            local spinner_started=false
            if [[ -t 1 ]]; then
                start_inline_spinner "Running brew upgrade"
                spinner_started=true
            fi

            local brew_output=""
            local brew_status=0
            if ! brew_output=$(brew upgrade 2>&1); then
                brew_status=$?
            fi

            if [[ "$spinner_started" == "true" ]]; then
                stop_inline_spinner
            fi

            local filtered_output
            filtered_output=$(echo "$brew_output" | grep -Ev "^(==>|Warning:)" || true)
            [[ -n "$filtered_output" ]] && echo "$filtered_output"

            if [[ ${brew_status:-0} -eq 0 ]]; then
                echo -e "${GREEN}✓${NC} Homebrew formulae updated"
                reset_brew_cache
                ((updated_count++))
            else
                echo -e "${RED}✗${NC} Homebrew formula update failed"
            fi
            echo ""
        fi
    fi

    # Update Homebrew casks
    if ((brew_cask > 0)); then
        if ! brew_has_outdated "cask"; then
            echo -e "${GRAY}-${NC} Homebrew casks already up to date"
            ((total_count--))
            echo ""
        else
            echo -e "${BLUE}Updating Homebrew casks...${NC}"
            local spinner_started=false
            if [[ -t 1 ]]; then
                start_inline_spinner "Running brew upgrade --cask"
                spinner_started=true
            fi

            local brew_output=""
            local brew_status=0
            if ! brew_output=$(brew upgrade --cask 2>&1); then
                brew_status=$?
            fi

            if [[ "$spinner_started" == "true" ]]; then
                stop_inline_spinner
            fi

            local filtered_output
            filtered_output=$(echo "$brew_output" | grep -Ev "^(==>|Warning:)" || true)
            [[ -n "$filtered_output" ]] && echo "$filtered_output"

            if [[ ${brew_status:-0} -eq 0 ]]; then
                echo -e "${GREEN}✓${NC} Homebrew casks updated"
                reset_brew_cache
                ((updated_count++))
            else
                echo -e "${RED}✗${NC} Homebrew cask update failed"
            fi
            echo ""
        fi
    fi

    # Update App Store apps
    local macos_handled_via_appstore=false
    if [[ -n "${APPSTORE_UPDATE_COUNT:-}" && "${APPSTORE_UPDATE_COUNT:-0}" -gt 0 ]]; then
        # Check sudo access
        if ! has_sudo_session; then
            if ! ensure_sudo_session "Software updates require admin access"; then
                echo -e "${YELLOW}☻${NC} App Store updates available — update via System Settings"
                echo ""
                ((total_count--))
                if [[ -n "${MACOS_UPDATE_AVAILABLE:-}" && "${MACOS_UPDATE_AVAILABLE}" == "true" ]]; then
                    ((total_count--))
                fi
            else
                _perform_appstore_update
            fi
        else
            _perform_appstore_update
        fi
    fi

    # Update macOS
    if [[ -n "${MACOS_UPDATE_AVAILABLE:-}" && "${MACOS_UPDATE_AVAILABLE}" == "true" && "$macos_handled_via_appstore" != "true" ]]; then
        if ! has_sudo_session; then
            echo -e "${YELLOW}☻${NC} macOS updates available — update via System Settings"
            echo ""
            ((total_count--))
        else
            _perform_macos_update
        fi
    fi

    # Update Mole
    if [[ -n "${MOLE_UPDATE_AVAILABLE:-}" && "${MOLE_UPDATE_AVAILABLE}" == "true" ]]; then
        echo -e "${BLUE}Updating Mole...${NC}"
        if "${SCRIPT_DIR}/mole" update 2>&1 | grep -qE "(Updated|latest version)"; then
            echo -e "${GREEN}✓${NC} Mole updated"
            reset_mole_cache
            ((updated_count++))
        else
            echo -e "${RED}✗${NC} Mole update failed"
        fi
        echo ""
    fi

    # Summary
    if [[ $total_count -eq 0 ]]; then
        echo -e "${GRAY}No updates to perform${NC}"
        return 0
    elif [[ $updated_count -eq $total_count ]]; then
        echo -e "${GREEN}All updates completed (${updated_count}/${total_count})${NC}"
        return 0
    elif [[ $updated_count -gt 0 ]]; then
        echo -e "${YELLOW}Partial updates completed (${updated_count}/${total_count})${NC}"
        return 0
    else
        echo -e "${RED}No updates were completed${NC}"
        return 0
    fi
}

# Internal: Perform App Store update
_perform_appstore_update() {
    echo -e "${BLUE}Updating App Store apps...${NC}"
    local appstore_log
    appstore_log=$(mktemp "${TMPDIR:-/tmp}/mole-appstore.XXXXXX" 2> /dev/null || echo "/tmp/mole-appstore.log")

    if [[ "$appstore_needs_fallback" == "true" ]]; then
        echo -e "  ${GRAY}Installing all available updates${NC}"
        if sudo softwareupdate -i -a 2>&1 | tee "$appstore_log" | grep -v "^$"; then
            echo -e "${GREEN}✓${NC} Software updates completed"
            ((updated_count++))
            if [[ -n "${MACOS_UPDATE_AVAILABLE:-}" && "${MACOS_UPDATE_AVAILABLE}" == "true" ]]; then
                macos_handled_via_appstore=true
                ((updated_count++))
            fi
        else
            echo -e "${RED}✗${NC} Software update failed"
        fi
    else
        if sudo softwareupdate -i "${appstore_labels[@]}" 2>&1 | tee "$appstore_log" | grep -v "^$"; then
            echo -e "${GREEN}✓${NC} App Store apps updated"
            ((updated_count++))
        else
            echo -e "${RED}✗${NC} App Store update failed"
        fi
    fi
    rm -f "$appstore_log" 2> /dev/null || true
    reset_softwareupdate_cache
    echo ""
}

# Internal: Perform macOS update
_perform_macos_update() {
    echo -e "${BLUE}Updating macOS...${NC}"
    echo -e "${YELLOW}Note:${NC} System update may require restart"

    local macos_log
    macos_log=$(mktemp "${TMPDIR:-/tmp}/mole-macos.XXXXXX" 2> /dev/null || echo "/tmp/mole-macos.log")

    if [[ "$macos_needs_fallback" == "true" ]]; then
        if sudo softwareupdate -i -r 2>&1 | tee "$macos_log" | grep -v "^$"; then
            echo -e "${GREEN}✓${NC} macOS updated"
            ((updated_count++))
        else
            echo -e "${RED}✗${NC} macOS update failed"
        fi
    else
        if sudo softwareupdate -i "${macos_labels[@]}" 2>&1 | tee "$macos_log" | grep -v "^$"; then
            echo -e "${GREEN}✓${NC} macOS updated"
            ((updated_count++))
        else
            echo -e "${RED}✗${NC} macOS update failed"
        fi
    fi

    if grep -qi "restart" "$macos_log" 2> /dev/null; then
        echo -e "${YELLOW}${ICON_WARNING}${NC} Restart required to complete update"
    fi

    rm -f "$macos_log" 2> /dev/null || true
    reset_softwareupdate_cache
    echo ""
}
