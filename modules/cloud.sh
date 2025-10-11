#!/usr/bin/env bash
# Cloud CLI tools installer module
# Supports: aws-cli, gcloud, azure-cli

install_cloud_tools() {
    local tools="${1:-}" # comma-separated list
    log_info "Installing Cloud CLI tools: $tools"
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            aws-cli)
                log_info "Would install AWS CLI"
                ;;
            gcloud)
                log_info "Would install Google Cloud SDK"
                ;;
            azure-cli)
                log_info "Would install Azure CLI"
                ;;
            bicep)
                log_info "Would install Azure Bicep"
                ;;
            *)
                log_warn "Unknown cloud tool: $tool"
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_cloud_tools
fi
