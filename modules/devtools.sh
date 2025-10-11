#!/usr/bin/env bash
# Developer tools installer module
# Supports: pyenv, nvm, rbenv, git, jq

install_devtools() {
    log_info "Installing developer tools..."
    # Always install pyenv, nvm, rbenv in user mode
    if [[ "${CONFIG_pyenv:-false}" == "true" ]]; then
        if [[ "${INSTALL_MODE}" == "system" ]]; then
            log_warn "pyenv should only be installed in user mode. Skipping system-wide install."
        else
            log_info "Would install pyenv (user mode)"
        fi
    fi
    if [[ "${CONFIG_nvm:-false}" == "true" ]]; then
        if [[ "${INSTALL_MODE}" == "system" ]]; then
            log_warn "nvm should only be installed in user mode. Skipping system-wide install."
        else
            log_info "Would install nvm (user mode)"
        fi
    fi
    if [[ "${CONFIG_rbenv:-false}" == "true" ]]; then
        if [[ "${INSTALL_MODE}" == "system" ]]; then
            log_warn "rbenv should only be installed in user mode. Skipping system-wide install."
        else
            log_info "Would install rbenv (user mode)"
        fi
    fi
    if [[ "${CONFIG_git:-false}" == "true" ]]; then
        log_info "Would install git"
    fi
    if [[ "${CONFIG_jq:-false}" == "true" ]]; then
        log_info "Would install jq"
    fi
    if [[ "${CONFIG_powershell:-false}" == "true" ]]; then
        log_info "Would install PowerShell"
    fi
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_devtools
fi
