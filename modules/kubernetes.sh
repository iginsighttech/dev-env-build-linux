#!/usr/bin/env bash
# Kubernetes tools installer module
# Supports: kubectl, helm, k9s

install_kubernetes_tools() {
    local tools="${1:-}" # comma-separated list
    log_info "Installing Kubernetes tools: $tools"
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            kubectl)
                log_info "Would install kubectl"
                ;;
            helm)
                log_info "Would install helm"
                ;;
            k9s)
                log_info "Would install k9s"
                ;;
            *)
                log_warn "Unknown kubernetes tool: $tool"
                ;;
        esac
    done
}

# Only run if sourced as a module
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_kubernetes_tools
fi
