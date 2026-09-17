#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Cloud CLI Tools Module
# Supports: aws-cli, gcloud, azure-cli, bicep
# =====================================================================

# Prevent multiple inclusion
[[ "${CLOUD_MODULE_LOADED:-}" == "true" ]] && return 0
readonly CLOUD_MODULE_LOADED="true"

# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/installer.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/versioncheck.sh"

readonly CLOUD_CATEGORY="cloud"

# On a fresh $HOME (e.g. root's first-ever gcloud invocation via sudo), gcloud
# tries to detect whether it's running on a GCE instance by resolving
# metadata.google.internal. Off GCE, that DNS lookup has no answer and gcloud
# retries across search domains, which reliably blows past our version-check
# timeout and leaves get_local_version() with no output to parse. Once
# ~/.config/gcloud/gce is cached this is instant, but the first run needs the
# check disabled outright.
export CLOUDSDK_CORE_CHECK_GCE_METADATA=False

# Maps the tool's config/CLI name to the actual command on PATH
_cloud_command_for() {
    case "$1" in
        aws-cli) echo "aws" ;;
        azure-cli) echo "az" ;;
        *) echo "$1" ;;
    esac
}

# ---------- Module Interface Functions ----------
cloud_check() {
    log_debug "Checking cloud CLI tools status"

    local tool cmd version latest
    for tool in aws-cli gcloud azure-cli bicep; do
        cmd=$(_cloud_command_for "$tool")
        version=$(get_local_version "$cmd" "--version" '[0-9]+(\.[0-9]+)+')
        latest=$(get_latest_version_cached "$tool")
        if [[ -n "$version" ]]; then
            add_tool_result "$tool" "$CLOUD_CATEGORY" "$version" "$latest" "installed" "$(where_cmd "$cmd")" "verified"
        else
            add_tool_result "$tool" "$CLOUD_CATEGORY" "" "$latest" "not_found" "" "unknown"
        fi
    done
}

install_cloud_tools() {
    local tools="${1:-}" # comma-separated list
    local silent_mode="${SILENT:-0}"
    IFS=',' read -ra tool_array <<< "$tools"

    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        local latest
        latest=$(get_latest_version_cached "$tool")

        if is_dry_run; then
            log_info "DRY-RUN: Would install $tool"
            add_tool_result "$tool" "$CLOUD_CATEGORY" "" "$latest" "would_install" "" "pending"
            continue
        fi

        case "$tool" in
            aws-cli)
                # Ubuntu/Debian no longer ship an "awscli" apt package (v1, Python-based,
                # was dropped from the archives), so install AWS's official v2 bundle instead.
                local arch
                arch=$(map_arch_for_vendor "$(detect_architecture)" "aws")
                local tmp_zip="/tmp/awscliv2.zip"
                local tmp_dir="/tmp/awscliv2"
                rm -rf "$tmp_zip" "$tmp_dir"
                curl -sLo "$tmp_zip" "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip"
                unzip -qq -o "$tmp_zip" -d "$tmp_dir"
                "$tmp_dir/aws/install" --update -i "$OPT_DIR/aws-cli" -b "$BIN_DIR"
                rm -rf "$tmp_zip" "$tmp_dir"
                ;;
            gcloud)
                install_system_packages google-cloud-cli
                ;;
            azure-cli)
                install_system_packages azure-cli
                ;;
            bicep)
                local bin="$BIN_DIR/bicep"
                rm -f "$bin"
                local arch
                arch=$(map_arch_for_vendor "$(detect_architecture)" "bicep")
                if [[ "$silent_mode" -eq 1 ]]; then
                    curl -sLo "$bin" "https://github.com/Azure/bicep/releases/latest/download/bicep-linux-${arch}"
                else
                    curl -Lo "$bin" "https://github.com/Azure/bicep/releases/latest/download/bicep-linux-${arch}"
                fi
                chmod +x "$bin"
                ;;
            *)
                log_warn "Unknown cloud tool: $tool"
                continue
                ;;
        esac

        local cmd installed_version
        cmd=$(_cloud_command_for "$tool")
        installed_version=$(get_local_version "$cmd" "--version" '[0-9]+(\.[0-9]+)+')
        if [[ -n "$installed_version" ]]; then
            add_tool_result "$tool" "$CLOUD_CATEGORY" "$installed_version" "$latest" "installed" "$(where_cmd "$cmd")" "verified"
        else
            log_error "$tool installation verification failed"
            add_tool_result "$tool" "$CLOUD_CATEGORY" "" "$latest" "failed" "" "failed"
        fi
    done
}

cloud_upgrade() {
    log_info "Upgrading cloud CLI tools"
    install_cloud_tools "aws-cli,gcloud,azure-cli,bicep"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_cloud_tools cloud_check cloud_upgrade
fi
