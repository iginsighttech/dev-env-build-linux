#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - HashiCorp Tools Module
# Supports: terraform, packer, vault, consul
# =====================================================================

# Prevent multiple inclusion
[[ "${HASHICORP_MODULE_LOADED:-}" == "true" ]] && return 0
readonly HASHICORP_MODULE_LOADED="true"

# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/installer.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/versioncheck.sh"

readonly HASHICORP_CATEGORY="hashicorp"

# Fallback versions used only if a package-manager install fails and we
# have to fall back to downloading a zip directly from releases.hashicorp.com
declare -A HASHICORP_FALLBACK_VERSION=(
    [terraform]="1.8.5"
    [packer]="1.10.2"
    [vault]="1.16.2"
    [consul]="1.18.2"
)

# ---------- Module Interface Functions ----------
hashicorp_check() {
    log_debug "Checking hashicorp tools status"

    local tool version latest
    for tool in terraform packer vault consul; do
        version=$(get_local_version "$tool" "--version" '[0-9]+(\.[0-9]+)+')
        latest=$(get_latest_version_cached "$tool")
        if [[ -n "$version" ]]; then
            add_tool_result "$tool" "$HASHICORP_CATEGORY" "$version" "$latest" "installed" "$(where_cmd "$tool")" "verified"
        else
            add_tool_result "$tool" "$HASHICORP_CATEGORY" "" "$latest" "not_found" "" "unknown"
        fi
    done
}

install_hashicorp_tools() {
    local tools="${1:-}" # comma-separated list
    local silent_mode="${SILENT:-0}"
    IFS=',' read -ra tool_array <<< "$tools"

    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            terraform|packer|vault|consul)
                local latest
                latest=$(get_latest_version_cached "$tool")

                if is_dry_run; then
                    log_info "DRY-RUN: Would install $tool"
                    add_tool_result "$tool" "$HASHICORP_CATEGORY" "" "$latest" "would_install" "" "pending"
                    continue
                fi

                local bin="$BIN_DIR/$tool"
                rm -f "$bin"
                local fallback_version="${HASHICORP_FALLBACK_VERSION[$tool]}"
                local arch
                arch=$(map_arch_for_vendor "$(detect_architecture)" "hashicorp")

                local pkg_ok=1
                if install_system_packages "$tool"; then pkg_ok=0; fi

                if [[ "$pkg_ok" -ne 0 ]]; then
                    curl -sLo "/tmp/${tool}.zip" "https://releases.hashicorp.com/${tool}/${fallback_version}/${tool}_${fallback_version}_linux_${arch}.zip"
                    unzip -qq -o "/tmp/${tool}.zip" -d /tmp
                    mv -f "/tmp/${tool}" "$bin"
                    chmod +x "$bin"
                    rm -f "/tmp/${tool}.zip" "/tmp/${tool}"
                fi

                local installed_version
                installed_version=$(get_local_version "$tool" "--version" '[0-9]+(\.[0-9]+)+')
                if [[ -n "$installed_version" ]]; then
                    add_tool_result "$tool" "$HASHICORP_CATEGORY" "$installed_version" "$latest" "installed" "$(where_cmd "$tool")" "verified"
                else
                    log_error "$tool installation verification failed"
                    add_tool_result "$tool" "$HASHICORP_CATEGORY" "" "$latest" "failed" "" "failed"
                fi
                ;;
            *)
                log_warn "Unknown hashicorp tool: $tool"
                ;;
        esac
    done
}

hashicorp_upgrade() {
    log_info "Upgrading hashicorp tools"
    install_hashicorp_tools "terraform,packer,vault,consul"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_hashicorp_tools hashicorp_check hashicorp_upgrade
fi
