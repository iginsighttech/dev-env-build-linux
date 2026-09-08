#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Developer Tools Module
# Supports: pyenv, nvm, rbenv, git, jq, powershell
# =====================================================================

# Prevent multiple inclusion
[[ "${DEVTOOLS_MODULE_LOADED:-}" == "true" ]] && return 0
readonly DEVTOOLS_MODULE_LOADED="true"

# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/installer.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/versioncheck.sh"

readonly DEVTOOLS_CATEGORY="devtools"

# ---------- Module Interface Functions ----------
devtools_check() {
    log_debug "Checking devtools status"

    local tool version latest
    for tool in pyenv nvm rbenv git jq powershell; do
        version=$(get_local_version "$tool" "--version" '[0-9]+(\.[0-9]+)+')
        latest=$(get_latest_version_cached "$tool")
        if [[ -n "$version" ]]; then
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "$version" "$latest" "installed" "$(where_cmd "$tool")" "verified"
        else
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "" "$latest" "not_found" "" "unknown"
        fi
    done
}

install_devtools() {
    local tools="${1:-}" # comma-separated list
    local silent_mode="${SILENT:-0}"
    IFS=',' read -ra tool_array <<< "$tools"

    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        local latest
        latest=$(get_latest_version_cached "$tool")

        if is_dry_run; then
            log_info "DRY-RUN: Would install $tool"
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "" "$latest" "would_install" "" "pending"
            continue
        fi

        case "$tool" in
            pyenv)
                if [[ "$INSTALL_MODE" == "$MODE_SYSTEM" ]]; then
                    log_warn "pyenv should only be installed in user mode. Skipping system-wide install."
                    continue
                fi
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -s https://pyenv.run | bash
                else
                    curl https://pyenv.run | bash
                fi
                ;;
            nvm)
                if [[ "$INSTALL_MODE" == "$MODE_SYSTEM" ]]; then
                    log_warn "nvm should only be installed in user mode. Skipping system-wide install."
                    continue
                fi
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -s https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
                else
                    curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
                fi
                ;;
            rbenv)
                if [[ "$INSTALL_MODE" == "$MODE_SYSTEM" ]]; then
                    log_warn "rbenv should only be installed in user mode. Skipping system-wide install."
                    continue
                fi
                if [[ "$silent_mode" -eq 1 ]]; then
                    git clone -q https://github.com/rbenv/rbenv.git ~/.rbenv
                else
                    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
                fi
                ;;
            git|jq|powershell)
                install_system_packages "$tool"
                ;;
            *)
                log_warn "Unknown devtool: $tool"
                continue
                ;;
        esac

        local installed_version
        installed_version=$(get_local_version "$tool" "--version" '[0-9]+(\.[0-9]+)+')
        if [[ -n "$installed_version" ]]; then
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "$installed_version" "$latest" "installed" "$(where_cmd "$tool")" "verified"
        elif [[ "$tool" == "pyenv" || "$tool" == "nvm" || "$tool" == "rbenv" ]]; then
            # These install their shims into the user's shell rc files and
            # genuinely aren't on PATH until a new shell session picks that
            # up, even when the install itself succeeded.
            log_warn "$tool installed but not yet on PATH (may require a new shell session)"
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "" "$latest" "installed" "" "pending"
        else
            log_error "$tool installation verification failed"
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "" "$latest" "failed" "" "failed"
        fi
    done
}

devtools_upgrade() {
    log_info "Upgrading devtools"
    install_devtools "pyenv,nvm,rbenv,git,jq,powershell"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_devtools devtools_check devtools_upgrade
fi
