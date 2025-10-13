#!/usr/bin/env bash
# Kubernetes tools installer module
# Supports: kubectl, helm, k9s

install_kubernetes_tools() {
    local tools="${1:-}" # comma-separated list
        local silent_mode="${SILENT:-0}"
        if [[ "$silent_mode" -eq 1 ]]; then
            log_info "Installing kubernetes tools silently: $tools"
            # ...actual install logic here, silent mode...
        else
            log_info "Installing kubernetes tools (verbose): $tools"
            # ...actual install logic here, verbose mode...
        fi
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            kubectl)
                local bin="$BIN_DIR/kubectl"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo "$bin" https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
                else
                    curl -Lo "$bin" https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
                fi
                chmod +x "$bin"
                ;;
            helm)
                local bin="$BIN_DIR/helm"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo /tmp/helm.tar.gz https://get.helm.sh/helm-v3.14.2-linux-amd64.tar.gz
                else
                    curl -Lo /tmp/helm.tar.gz https://get.helm.sh/helm-v3.14.2-linux-amd64.tar.gz
                fi
                tar -xzf /tmp/helm.tar.gz -C /tmp
                mv -f /tmp/linux-amd64/helm "$bin"
                chmod +x "$bin"
                rm -rf /tmp/helm.tar.gz /tmp/linux-amd64
                ;;
            k9s)
                local bin="$BIN_DIR/k9s"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo /tmp/k9s.tar.gz https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
                else
                    curl -Lo /tmp/k9s.tar.gz https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
                fi
                tar -xzf /tmp/k9s.tar.gz -C /tmp
                mv -f /tmp/k9s "$bin"
                chmod +x "$bin"
                rm -rf /tmp/k9s.tar.gz /tmp/k9s
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
