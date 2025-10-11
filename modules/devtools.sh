#!/usr/bin/env bash
# Developer tools installer module
# Supports: pyenv, nvm, rbenv, git, jq, powershell

install_devtools() {
    local tools="${1:-}" # comma-separated list
    log_info "Installing developer tools: $tools"
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            pyenv)
                if [[ "$INSTALL_MODE" == "system" ]]; then
                    log_warn "pyenv should only be installed in user mode. Skipping system-wide install."
                else
                    log_info "Would install pyenv (user mode)"
                fi
                ;;
            nvm)
                if [[ "$INSTALL_MODE" == "system" ]]; then
                    log_warn "nvm should only be installed in user mode. Skipping system-wide install."
                else
                    log_info "Would install nvm (user mode)"
                fi
                ;;
            rbenv)
                if [[ "$INSTALL_MODE" == "system" ]]; then
                    log_warn "rbenv should only be installed in user mode. Skipping system-wide install."
                else
                    log_info "Would install rbenv (user mode)"
                fi
                ;;
            git)
                log_info "Would install git"
                ;;
            jq)
                log_info "Would install jq"
                ;;
            powershell)
                log_info "Would install PowerShell"
                ;;
            *)
                log_warn "Unknown devtool: $tool"
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_devtools
fi
