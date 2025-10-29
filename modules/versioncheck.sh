#!/usr/bin/env bash
# Version check module for InSight Dev Bootstrap

# Usage: version_check <tool>

# Version cache file
VERSION_CACHE_FILE="/tmp/dev-env-version-cache"

# Fetch latest version (no cache)
version_check() {
    local tool="$1"
    local latest_version="-"
    case "$tool" in
        kubectl)
            latest_version=$(curl -m 5 -sL https://dl.k8s.io/release/stable.txt 2>/dev/null || true)
            [[ "$latest_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || latest_version="-"
            ;;
        helm)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/helm/helm/releases/latest | grep 'tag_name' | head -1 | grep -o 'v[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        k9s)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/derailed/k9s/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        terraform)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        packer)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/hashicorp/packer/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        vault)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/hashicorp/vault/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        consul)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/hashicorp/consul/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        docker)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/moby/moby/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        docker-compose)
            raw_response=$(curl -m 5 -s https://api.github.com/repos/docker/compose/releases/latest)
            latest_version=$(echo "$raw_response" | grep 'tag_name' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/^v//' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        gcloud)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/GoogleCloudPlatform/cloud-sdk/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        aws-cli)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/aws/aws-cli/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        bicep)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/Azure/bicep/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        pyenv)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/pyenv/pyenv/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        nvm)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        rbenv)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/rbenv/rbenv/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        powershell)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        git)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/git/git/tags | grep 'name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        jq)
            latest_version=$(curl -m 5 -s https://api.github.com/repos/stedolan/jq/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
            [[ -z "$latest_version" ]] && latest_version="-"
            ;;
        *)
            latest_version="-"
            ;;
    esac
    echo "$latest_version"
}

# Cached version check
version_check_cached() {
    local tool="$1"
    local cache_ttl="604800" # 1 week
    local now epoch cache_epoch cache_version
    now=$(date +%s)

    # Ensure cache file exists
    [[ -f "$VERSION_CACHE_FILE" ]] || touch "$VERSION_CACHE_FILE"

    # Try to read from cache
    cache_version=""
    cache_epoch=""
    while IFS='|' read -r cached_tool cached_version cached_time; do
        if [[ "$cached_tool" == "$tool" ]]; then
            cache_version="$cached_version"
            cache_epoch="$cached_time"
            break
        fi
    done < "$VERSION_CACHE_FILE"

    # If cache is valid and not empty, return
    if [[ -n "$cache_version" && -n "$cache_epoch" && "$cache_version" != "-" ]]; then
        if (( now - cache_epoch < cache_ttl )); then
            echo "$cache_version"
            return 0
        fi
    fi

    # Otherwise, fetch and update cache
    local latest_version
    latest_version=$(version_check "$tool")
    # Remove old entry
    grep -v "^$tool|" "$VERSION_CACHE_FILE" > "$VERSION_CACHE_FILE.tmp" && mv "$VERSION_CACHE_FILE.tmp" "$VERSION_CACHE_FILE"
    # Add new entry
    echo "$tool|$latest_version|$now" >> "$VERSION_CACHE_FILE"
    echo "$latest_version"
}
