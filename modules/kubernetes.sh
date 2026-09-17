#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Kubernetes Tools Module
# Supports: kubectl, helm, k9s
# =====================================================================

# Prevent multiple inclusion
[[ "${KUBERNETES_MODULE_LOADED:-}" == "true" ]] && return 0
readonly KUBERNETES_MODULE_LOADED="true"

# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/installer.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/versioncheck.sh"

readonly KUBERNETES_CATEGORY="kubernetes"

# ---------- Module Interface Functions ----------
kubernetes_check() {
    log_debug "Checking kubernetes tools status"

    local tool version_args
    for tool in kubectl helm k9s; do
        case "$tool" in
            kubectl) version_args="version --client" ;;
            # helm and k9s both moved version reporting to a "version"
            # subcommand; neither accepts a --version flag anymore.
            helm|k9s) version_args="version --short" ;;
            *) version_args="--version" ;;
        esac

        local version latest
        version=$(get_local_version "$tool" "$version_args" '[0-9]+(\.[0-9]+)+')
        latest=$(get_latest_version_cached "$tool")
        if [[ -n "$version" ]]; then
            add_tool_result "$tool" "$KUBERNETES_CATEGORY" "$version" "$latest" "installed" "$(where_cmd "$tool")" "verified"
        else
            add_tool_result "$tool" "$KUBERNETES_CATEGORY" "" "$latest" "not_found" "" "unknown"
        fi
    done
}

install_kubernetes_tools() {
    local tools="${1:-}" # comma-separated list
    local silent_mode="${SILENT:-0}"
    IFS=',' read -ra tool_array <<< "$tools"

    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            kubectl)
                if is_dry_run; then
                    log_info "DRY-RUN: Would install kubectl to $BIN_DIR"
                    add_tool_result "kubectl" "$KUBERNETES_CATEGORY" "" "$(get_latest_version_cached kubectl)" "would_install" "" "pending"
                    continue
                fi
                local bin="$BIN_DIR/kubectl"
                rm -f "$bin"
                local arch
                arch=$(map_arch_for_vendor "$(detect_architecture)" "kubernetes")
                local kubectl_release
                kubectl_release=$(curl -s https://dl.k8s.io/release/stable.txt)
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo "$bin" "https://dl.k8s.io/release/${kubectl_release}/bin/linux/${arch}/kubectl"
                else
                    curl -Lo "$bin" "https://dl.k8s.io/release/${kubectl_release}/bin/linux/${arch}/kubectl"
                fi
                chmod +x "$bin"
                local installed_version
                installed_version=$(get_local_version kubectl "version --client" '[0-9]+(\.[0-9]+)+')
                if [[ -n "$installed_version" ]]; then
                    add_tool_result "kubectl" "$KUBERNETES_CATEGORY" "$installed_version" "$kubectl_release" "installed" "$bin" "verified"
                else
                    log_error "kubectl installation verification failed"
                    add_tool_result "kubectl" "$KUBERNETES_CATEGORY" "" "$kubectl_release" "failed" "" "failed"
                fi
                ;;
            helm)
                if is_dry_run; then
                    log_info "DRY-RUN: Would install helm to $BIN_DIR"
                    add_tool_result "helm" "$KUBERNETES_CATEGORY" "" "$(get_latest_version_cached helm)" "would_install" "" "pending"
                    continue
                fi
                local bin="$BIN_DIR/helm"
                rm -f "$bin"
                local arch
                arch=$(map_arch_for_vendor "$(detect_architecture)" "kubernetes")
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo /tmp/helm.tar.gz "https://get.helm.sh/helm-v3.14.2-linux-${arch}.tar.gz"
                else
                    curl -Lo /tmp/helm.tar.gz "https://get.helm.sh/helm-v3.14.2-linux-${arch}.tar.gz"
                fi
                tar -xzf /tmp/helm.tar.gz -C /tmp
                mv -f "/tmp/linux-${arch}/helm" "$bin"
                chmod +x "$bin"
                rm -rf /tmp/helm.tar.gz "/tmp/linux-${arch}"
                local installed_version latest_version
                installed_version=$(get_local_version helm "version --short" '[0-9]+(\.[0-9]+)+')
                latest_version=$(get_latest_version_cached helm)
                if [[ -n "$installed_version" ]]; then
                    add_tool_result "helm" "$KUBERNETES_CATEGORY" "$installed_version" "$latest_version" "installed" "$bin" "verified"
                else
                    log_error "helm installation verification failed"
                    add_tool_result "helm" "$KUBERNETES_CATEGORY" "" "$latest_version" "failed" "" "failed"
                fi
                ;;
            k9s)
                if is_dry_run; then
                    log_info "DRY-RUN: Would install k9s to $BIN_DIR"
                    add_tool_result "k9s" "$KUBERNETES_CATEGORY" "" "$(get_latest_version_cached k9s)" "would_install" "" "pending"
                    continue
                fi
                local bin="$BIN_DIR/k9s"
                rm -f "$bin"
                local arch
                arch=$(map_arch_for_vendor "$(detect_architecture)" "kubernetes")
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${arch}.tar.gz"
                else
                    curl -Lo /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${arch}.tar.gz"
                fi
                tar -xzf /tmp/k9s.tar.gz -C /tmp
                mv -f /tmp/k9s "$bin"
                chmod +x "$bin"
                rm -rf /tmp/k9s.tar.gz /tmp/k9s
                local installed_version latest_version
                installed_version=$(get_local_version k9s "version --short" '[0-9]+(\.[0-9]+)+')
                latest_version=$(get_latest_version_cached k9s)
                if [[ -n "$installed_version" ]]; then
                    add_tool_result "k9s" "$KUBERNETES_CATEGORY" "$installed_version" "$latest_version" "installed" "$bin" "verified"
                else
                    log_error "k9s installation verification failed"
                    add_tool_result "k9s" "$KUBERNETES_CATEGORY" "" "$latest_version" "failed" "" "failed"
                fi
                ;;
            *)
                log_warn "Unknown kubernetes tool: $tool"
                ;;
        esac
    done
}

kubernetes_upgrade() {
    log_info "Upgrading kubernetes tools"
    install_kubernetes_tools "kubectl,helm,k9s"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_kubernetes_tools kubernetes_check kubernetes_upgrade
fi
