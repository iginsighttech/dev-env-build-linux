#!/usr/bin/env bash
# HashiCorp tools installer module
# Supports: terraform, packer, vault, consul

install_hashicorp_tools() {
    log_info "Installing HashiCorp tools..."
    if [[ "${CONFIG_terraform:-false}" == "true" ]]; then
        log_info "Would install terraform"
    fi
    if [[ "${CONFIG_packer:-false}" == "true" ]]; then
        log_info "Would install packer"
    fi
    if [[ "${CONFIG_vault:-false}" == "true" ]]; then
        log_info "Would install vault"
    fi
    if [[ "${CONFIG_consul:-false}" == "true" ]]; then
        log_info "Would install consul"
    fi
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_hashicorp_tools
fi
