#!/usr/bin/env bash
# HashiCorp tools installer module
# Supports: terraform, packer, vault, consul

install_hashicorp_tools() {
    local tools="${1:-}" # comma-separated list
    log_info "Installing HashiCorp tools: $tools"
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            terraform)
                log_info "Would install terraform"
                ;;
            packer)
                log_info "Would install packer"
                ;;
            vault)
                log_info "Would install vault"
                ;;
            consul)
                log_info "Would install consul"
                ;;
            *)
                log_warn "Unknown hashicorp tool: $tool"
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_hashicorp_tools
fi
