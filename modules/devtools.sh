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

# PowerShell's binary is "pwsh", not "powershell"
_devtools_command_for() {
    case "$1" in
        powershell) echo "pwsh" ;;
        *) echo "$1" ;;
    esac
}

# pyenv/nvm/rbenv all install into $HOME and edit the user's shell rc files,
# so they only make sense for a real human account, never for root's own
# home. In user-mode installs, just run them directly. Under sudo
# (system-mode with root), drop down to the account that ran sudo instead
# of silently skipping the tool; only skip when there's truly no user to
# fall back to (a direct root login, not via sudo).
_install_user_scoped() {
    local tool="$1"
    local cmd="$2"

    if [[ "$INSTALL_MODE" != "$MODE_SYSTEM" ]]; then
        bash -c "$cmd"
        return
    fi

    local target_user
    target_user=$(sudo_invoking_user)
    if [[ -z "$target_user" ]]; then
        log_warn "$tool should only be installed in user mode. Skipping system-wide install."
        return 1
    fi

    log_info "Installing $tool for user '$target_user' (dropping from sudo for this user-scoped tool)"
    run_as_user "$target_user" "$cmd"
}

# Home directory to check for pyenv/nvm/rbenv: the sudo-invoking user's
# home when running system-wide as root, otherwise the current $HOME.
# Mirrors exactly where _install_user_scoped actually places these tools.
_user_scoped_home() {
    local target_user
    target_user=$(sudo_invoking_user)
    if [[ -n "$target_user" ]]; then
        user_home_dir "$target_user"
    else
        echo "$HOME"
    fi
}

# pyenv/nvm/rbenv can never be found via PATH from this script's own
# process: pyenv/rbenv only land on PATH in a *new* shell session (their
# installers edit ~/.bashrc, which this process never re-reads), and nvm
# is a shell function sourced from nvm.sh, not a binary, so `command -v
# nvm` would never find it even on a correctly working install. Check
# their known install locations on disk directly instead. Prints
# "<version>|<path>" (version is empty if the path exists but a version
# couldn't be parsed out of it; path is empty if it's not installed at
# all).
_check_user_scoped_tool() {
    local tool="$1"
    local home
    home=$(_user_scoped_home)
    local path="" version=""

    case "$tool" in
        pyenv)
            path="$home/.pyenv/bin/pyenv"
            [[ -x "$path" ]] && version=$("$path" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)
            ;;
        rbenv)
            path="$home/.rbenv/bin/rbenv"
            [[ -x "$path" ]] && version=$("$path" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)
            ;;
        nvm)
            path="$home/.nvm/nvm.sh"
            [[ -f "$path" ]] && version=$(bash -c "source '$path' >/dev/null 2>&1 && nvm --version" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)
            ;;
    esac

    [[ -e "$path" ]] || path=""
    echo "${version}|${path}"
}

# ---------- Module Interface Functions ----------
devtools_check() {
    log_debug "Checking devtools status"

    local tool cmd version path latest
    for tool in pyenv nvm rbenv git jq powershell; do
        case "$tool" in
            pyenv|nvm|rbenv)
                IFS='|' read -r version path <<< "$(_check_user_scoped_tool "$tool")"
                ;;
            *)
                cmd=$(_devtools_command_for "$tool")
                version=$(get_local_version "$cmd" "--version" '[0-9]+(\.[0-9]+)+')
                path=$(where_cmd "$cmd")
                ;;
        esac
        latest=$(get_latest_version_cached "$tool")
        if [[ -n "$version" ]]; then
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "$version" "$latest" "installed" "$path" "verified"
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
                local pyenv_cmd="curl https://pyenv.run | bash"
                [[ "$silent_mode" -eq 1 ]] && pyenv_cmd="curl -s https://pyenv.run | bash"
                _install_user_scoped "pyenv" "$pyenv_cmd" || continue
                ;;
            nvm)
                local nvm_cmd="curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
                [[ "$silent_mode" -eq 1 ]] && nvm_cmd="curl -s https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
                _install_user_scoped "nvm" "$nvm_cmd" || continue
                ;;
            rbenv)
                local rbenv_cmd="git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
                [[ "$silent_mode" -eq 1 ]] && rbenv_cmd="git clone -q https://github.com/rbenv/rbenv.git ~/.rbenv"
                _install_user_scoped "rbenv" "$rbenv_cmd" || continue
                ;;
            git|jq)
                install_system_packages "$tool"
                ;;
            powershell)
                # Microsoft only publishes a "powershell" apt package for
                # amd64; on other architectures (e.g. arm64) there is no deb
                # at all, only the self-contained tarball release.
                if [[ "$(detect_architecture)" == "x86_64" ]]; then
                    install_system_packages powershell
                else
                    local ps_arch
                    case "$(detect_architecture)" in
                        aarch64) ps_arch="arm64" ;;
                        armv7l) ps_arch="arm32" ;;
                        *) ps_arch="x64" ;;
                    esac
                    local ps_dir="$OPT_DIR/powershell"
                    ensure_directory "$ps_dir"
                    curl -sLo /tmp/powershell.tar.gz \
                        "https://github.com/PowerShell/PowerShell/releases/download/v${latest}/powershell-${latest}-linux-${ps_arch}.tar.gz"
                    tar -xzf /tmp/powershell.tar.gz -C "$ps_dir"
                    chmod +x "$ps_dir/pwsh"
                    ln -sf "$ps_dir/pwsh" "$BIN_DIR/pwsh"
                    rm -f /tmp/powershell.tar.gz
                fi
                ;;
            *)
                log_warn "Unknown devtool: $tool"
                continue
                ;;
        esac

        local installed_version="" location=""
        case "$tool" in
            pyenv|nvm|rbenv)
                IFS='|' read -r installed_version location <<< "$(_check_user_scoped_tool "$tool")"
                ;;
            *)
                local cmd
                cmd=$(_devtools_command_for "$tool")
                installed_version=$(get_local_version "$cmd" "--version" '[0-9]+(\.[0-9]+)+')
                location=$(where_cmd "$cmd")
                ;;
        esac

        if [[ -n "$installed_version" ]]; then
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "$installed_version" "$latest" "installed" "$location" "verified"
        elif [[ -n "$location" ]]; then
            # The binary/shim exists on disk but we couldn't parse a version
            # out of it (e.g. an unexpected output format).
            log_warn "$tool is installed at $location but its version could not be determined"
            add_tool_result "$tool" "$DEVTOOLS_CATEGORY" "" "$latest" "installed" "$location" "unverified"
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
