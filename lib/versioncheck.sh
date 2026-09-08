#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Version Lookup Library
# Shared "latest available version" lookups for all supported tools
# =====================================================================

# Prevent multiple inclusion
[[ "${VERSIONCHECK_LIB_LOADED:-}" == "true" ]] && return 0
readonly VERSIONCHECK_LIB_LOADED="true"

# Source required libraries
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/common.sh"

readonly VERSION_CACHE_FILE="${TMPDIR:-/tmp}/insight-devbootstrap-version-cache"
readonly VERSION_CACHE_TTL=604800  # 1 week

# Look up the latest published version of a supported tool.
# Always talks to the network; callers that want caching should use
# get_latest_version_cached instead.
get_latest_version() {
    local tool="$1"
    local timeout="${LATEST_VERSION_TIMEOUT:-5}"
    local latest="-"

    case "$tool" in
        docker)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/moby/moby/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        docker-compose)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/docker/compose/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        podman)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/containers/podman/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        containerd)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/containerd/containerd/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        kubectl)
            latest=$(curl -m "$timeout" -sL https://dl.k8s.io/release/stable.txt 2>/dev/null || true)
            [[ "$latest" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || latest="-"
            ;;
        helm)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/helm/helm/releases/latest | grep -m1 'tag_name' | grep -o 'v[0-9][0-9.]*' || true)
            ;;
        k9s)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        terraform)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        packer)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/hashicorp/packer/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        vault)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/hashicorp/vault/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        consul)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/hashicorp/consul/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        aws-cli)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/aws/aws-cli/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        gcloud)
            latest=$(curl -m "$timeout" -s https://dl.google.com/dl/cloudsdk/channels/rapid/components-2.json | grep -o '"version": *"[0-9][0-9.]*"' | head -1 | grep -o '[0-9][0-9.]*' || true)
            ;;
        azure-cli)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/Azure/azure-cli/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        bicep)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/Azure/bicep/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        pyenv)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/pyenv/pyenv/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        nvm)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        rbenv)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/rbenv/rbenv/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        git)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/git/git/tags | grep -m1 '"name"' | grep -o '[0-9][0-9.]*' || true)
            ;;
        jq)
            # jq moved from stedolan/jq to jqlang/jq after the 1.6 release.
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/jqlang/jq/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        powershell)
            latest=$(curl -m "$timeout" -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep -m1 'tag_name' | grep -o '[0-9][0-9.]*' || true)
            ;;
        *)
            latest="-"
            ;;
    esac

    [[ -z "$latest" ]] && latest="-"
    echo "$latest"
}

# Cached wrapper around get_latest_version. Avoids hammering upstream APIs
# (and rate limits) when a tool's status is checked repeatedly.
get_latest_version_cached() {
    local tool="$1"
    local now cached_version cached_epoch

    if [[ "${FORCE_LATEST:-0}" != "1" && -f "$VERSION_CACHE_FILE" ]]; then
        while IFS='|' read -r cached_tool cached_version cached_epoch; do
            if [[ "$cached_tool" == "$tool" && -n "$cached_version" && "$cached_version" != "-" ]]; then
                now=$(date +%s)
                if (( now - cached_epoch < VERSION_CACHE_TTL )); then
                    echo "$cached_version"
                    return 0
                fi
                break
            fi
        done < "$VERSION_CACHE_FILE"
    fi

    local latest
    latest=$(get_latest_version "$tool")

    now=$(date +%s)
    { [[ -f "$VERSION_CACHE_FILE" ]] && grep -v "^${tool}|" "$VERSION_CACHE_FILE"; printf '%s|%s|%s\n' "$tool" "$latest" "$now"; } > "${VERSION_CACHE_FILE}.tmp" 2>/dev/null \
        && mv "${VERSION_CACHE_FILE}.tmp" "$VERSION_CACHE_FILE" 2>/dev/null || true

    echo "$latest"
}
