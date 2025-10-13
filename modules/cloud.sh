#!/usr/bin/env bash
# Cloud CLI tools installer module
# Supports: aws-cli, gcloud, azure-cli

install_cloud_tools() {
    local tools="${1:-}" # comma-separated list
        local silent_mode="${SILENT:-0}"
        if [[ "$silent_mode" -eq 1 ]]; then
            log_info "Installing cloud tools silently: $tools"
            # ...actual install logic here, silent mode...
        else
            log_info "Installing cloud tools (verbose): $tools"
            # ...actual install logic here, verbose mode...
        fi
        # ...add_tool_result logic after install...
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            aws-cli)
                if [[ "$silent_mode" -eq 1 ]]; then
                    $PKG_MGR install -y awscli &>/dev/null
                else
                    $PKG_MGR install -y awscli
                fi
                ;;
            gcloud)
                if [[ "$silent_mode" -eq 1 ]]; then
                    $PKG_MGR install -y google-cloud-cli &>/dev/null
                else
                    $PKG_MGR install -y google-cloud-cli
                fi
                ;;
            azure-cli)
                if [[ "$silent_mode" -eq 1 ]]; then
                    $PKG_MGR install -y azure-cli &>/dev/null
                else
                    $PKG_MGR install -y azure-cli
                fi
                ;;
            bicep)
                local bin="$BIN_DIR/bicep"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo "$bin" https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
                else
                    curl -Lo "$bin" https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
                fi
                chmod +x "$bin"
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
