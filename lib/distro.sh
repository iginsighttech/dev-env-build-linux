#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Distribution Detection Library
# OS/distribution detection and package manager abstraction
# =====================================================================

# Prevent multiple inclusion
[[ "${DISTRO_LIB_LOADED:-}" == "true" ]] && return 0
readonly DISTRO_LIB_LOADED="true"

# Source common library
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/common.sh"

# ---------- Architecture Detection ----------
detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        armv7l|armhf)
            echo "armv7l"
            ;;
        *)
            log_warn "Unrecognized architecture '$arch', defaulting to x86_64"
            echo "x86_64"
            ;;
    esac
}

# Map architecture for different vendors
map_arch_for_vendor() {
    local arch="$1"
    local vendor="$2"
    
    case "$vendor" in
        hashicorp)
            case "$arch" in
                x86_64) echo "amd64" ;;
                aarch64) echo "arm64" ;;
                armv7l) echo "arm" ;;
                *) echo "amd64" ;;
            esac
            ;;
        kubernetes)
            case "$arch" in
                x86_64) echo "amd64" ;;
                aarch64) echo "arm64" ;;
                armv7l) echo "arm" ;;
                *) echo "amd64" ;;
            esac
            ;;
        aws)
            case "$arch" in
                x86_64) echo "x86_64" ;;
                aarch64) echo "aarch64" ;;
                armv7l) echo "armv7l" ;;
                *) echo "x86_64" ;;
            esac
            ;;
        google)
            case "$arch" in
                x86_64) echo "x86_64" ;;
                aarch64) echo "arm" ;;
                armv7l) echo "arm" ;;
                *) echo "x86_64" ;;
            esac
            ;;
        bicep)
            case "$arch" in
                x86_64) echo "x64" ;;
                aarch64) echo "arm64" ;;
                *) echo "x64" ;;
            esac
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# ---------- OS Detection ----------
detect_os() {
    local os
    os=$(uname -s)
    
    case "$os" in
        Linux)
            echo "linux"
            ;;
        Darwin)
            echo "darwin"
            ;;
        *)
            log_warn "Unsupported OS: $os"
            echo "unknown"
            ;;
    esac
}

# ---------- Distribution Detection ----------
detect_distribution() {
    local distro_id=""
    local distro_like=""
    local distro_version=""
    local distro_codename=""
    
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        distro_id="${ID:-unknown}"
        distro_like="${ID_LIKE:-}"
        distro_version="${VERSION_ID:-}"
        distro_codename="${VERSION_CODENAME:-}"
    elif [[ -r /etc/lsb-release ]]; then
        # shellcheck disable=SC1091
        source /etc/lsb-release
        distro_id=$(to_lower "${DISTRIB_ID:-unknown}")
        distro_version="${DISTRIB_RELEASE:-}"
        distro_codename="${DISTRIB_CODENAME:-}"
    else
        # Fallback detection
        if [[ -f /etc/debian_version ]]; then
            distro_id="debian"
        elif [[ -f /etc/redhat-release ]]; then
            distro_id="rhel"
        elif [[ -f /etc/arch-release ]]; then
            distro_id="arch"
        elif [[ -f /etc/SUSE-brand ]] || [[ -f /etc/SuSE-release ]]; then
            distro_id="suse"
        else
            distro_id="unknown"
        fi
    fi
    
    # Export distribution information
    export DISTRO_ID="$distro_id"
    export DISTRO_LIKE="$distro_like"
    export DISTRO_VERSION="$distro_version"
    export DISTRO_CODENAME="$distro_codename"
    
    log_debug "Detected distribution: $distro_id (like: $distro_like, version: $distro_version)"
}

# ---------- Package Manager Detection ----------
detect_package_manager() {
    local pkg_mgr=""
    local update_cmd=""
    local install_cmd=""
    local search_cmd=""
    local remove_cmd=""
    
    if command_exists apt-get; then
        pkg_mgr="apt"
        update_cmd="apt-get update -y"
        install_cmd="apt-get install -y"
        search_cmd="apt-cache search"
        remove_cmd="apt-get remove -y"
    elif command_exists dnf; then
        pkg_mgr="dnf"
        update_cmd="dnf -y makecache"
        install_cmd="dnf install -y"
        search_cmd="dnf search"
        remove_cmd="dnf remove -y"
    elif command_exists yum; then
        pkg_mgr="yum"
        update_cmd="yum -y makecache"
        install_cmd="yum install -y"
        search_cmd="yum search"
        remove_cmd="yum remove -y"
    elif command_exists zypper; then
        pkg_mgr="zypper"
        update_cmd="zypper -n refresh"
        install_cmd="zypper -n install --no-confirm"
        search_cmd="zypper search"
        remove_cmd="zypper -n remove"
    elif command_exists pacman; then
        pkg_mgr="pacman"
        update_cmd="pacman -Sy --noconfirm"
        install_cmd="pacman -S --noconfirm --needed"
        search_cmd="pacman -Ss"
        remove_cmd="pacman -R --noconfirm"
    elif command_exists apk; then
        pkg_mgr="apk"
        update_cmd="apk update"
        install_cmd="apk add"
        search_cmd="apk search"
        remove_cmd="apk del"
    else
        die $EXIT_CONFIGURATION "No supported package manager found"
    fi
    
    # Export package manager commands
    export PKG_MGR="$pkg_mgr"
    export PKG_UPDATE="$update_cmd"
    export PKG_INSTALL="$install_cmd"
    export PKG_SEARCH="$search_cmd"
    export PKG_REMOVE="$remove_cmd"
    
    log_debug "Detected package manager: $pkg_mgr"
}

# ---------- Baseline Package Lists ----------
get_baseline_packages() {
    local pkg_mgr="$1"
    
    case "$pkg_mgr" in
        apt)
            echo "ca-certificates curl wget git jq unzip tar xz-utils gnupg lsb-release build-essential"
            ;;
        dnf|yum)
            echo "ca-certificates curl wget git jq unzip tar xz gzip gnupg2 gcc gcc-c++ make"
            ;;
        zypper)
            echo "ca-certificates curl wget git jq unzip tar xz gzip gpg2 lsb-release gcc gcc-c++ make"
            ;;
        pacman)
            echo "ca-certificates curl wget git jq unzip tar xz gnupg lsb-release base-devel"
            ;;
        apk)
            echo "ca-certificates curl wget git jq unzip tar xz gnupg lsb-release build-base"
            ;;
        *)
            log_warn "Unknown package manager: $pkg_mgr"
            echo ""
            ;;
    esac
}

# ---------- Distribution-Specific Functions ----------
setup_docker_repository() {
    local distro="$1"
    local pkg_mgr="$2"
    
    case "$pkg_mgr" in
        apt)
            if is_dry_run; then
                log_info "DRY-RUN: Would setup Docker APT repository for $distro"
                return 0
            fi
            
            log_info "Setting up Docker repository for $distro"
            
            # Create keyring directory
            install -m 0755 -d /etc/apt/keyrings || true
            
            # Download and install GPG key
            local gpg_url="https://download.docker.com/linux/${distro}/gpg"
            local keyring_file="/etc/apt/keyrings/docker.gpg"
            
            if download_file "$gpg_url" "-" | gpg --dearmor -o "$keyring_file"; then
                chmod a+r "$keyring_file" || true
                
                # Add repository
                local repo_url="https://download.docker.com/linux/${distro}"
                local arch
                arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
                
                echo "deb [arch=${arch} signed-by=${keyring_file}] ${repo_url} ${DISTRO_CODENAME:-stable} stable" \
                    > /etc/apt/sources.list.d/docker.list
                
                # Update package index
                $PKG_UPDATE || log_warn "Failed to update package index after adding Docker repository"
            else
                log_warn "Failed to setup Docker repository"
            fi
            ;;
        dnf|yum)
            if is_dry_run; then
                log_info "DRY-RUN: Would use Docker installation script"
                return 0
            fi
            
            log_info "Using Docker installation script for RHEL-based systems"
            download_file "https://get.docker.com" "/tmp/docker-install.sh"
            bash /tmp/docker-install.sh || log_warn "Docker installation script failed"
            rm -f /tmp/docker-install.sh
            ;;
        zypper)
            if is_dry_run; then
                log_info "DRY-RUN: Would use Docker installation script"
                return 0
            fi
            
            log_info "Using Docker installation script for SUSE systems"
            download_file "https://get.docker.com" "/tmp/docker-install.sh"
            bash /tmp/docker-install.sh || log_warn "Docker installation script failed"
            rm -f /tmp/docker-install.sh
            ;;
        pacman)
            log_info "Docker available in Arch repositories, no additional setup needed"
            ;;
        *)
            log_warn "Unknown package manager for Docker setup: $pkg_mgr"
            ;;
    esac
}

# ---------- System Information ----------
get_system_info() {
    local os arch distro pkg_mgr
    
    os=$(detect_os)
    arch=$(detect_architecture)
    detect_distribution
    detect_package_manager
    
    cat << EOF
OS: $os
Architecture: $arch
Distribution: ${DISTRO_ID} ${DISTRO_VERSION} (${DISTRO_CODENAME})
Distribution Like: ${DISTRO_LIKE}
Package Manager: ${PKG_MGR}
EOF
}

# ---------- Capability Detection ----------
has_systemd() {
    command_exists systemctl && [[ -d /run/systemd/system ]]
}

has_docker_group() {
    getent group docker >/dev/null 2>&1
}

can_use_sudo() {
    sudo -n true 2>/dev/null
}

# ---------- Environment Setup ----------
setup_package_manager_env() {
    # Set package manager specific environment variables
    case "${PKG_MGR:-}" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            export APT_LISTCHANGES_FRONTEND=none
            ;;
        dnf|yum)
            export YUM_OPTS="-y"
            ;;
        zypper)
            export ZYPPER_OPTS="-n"
            ;;
        pacman)
            export PACMAN_OPTS="--noconfirm"
            ;;
    esac
}

# ---------- Repository Management ----------
add_third_party_repository() {
    local repo_name="$1"
    local repo_url="$2"
    local gpg_key_url="${3:-}"
    
    case "${PKG_MGR}" in
        apt)
            if [[ -n "$gpg_key_url" ]]; then
                local keyring="/etc/apt/keyrings/${repo_name}.gpg"
                download_file "$gpg_key_url" "-" | gpg --dearmor -o "$keyring"
                chmod a+r "$keyring"
                echo "deb [signed-by=$keyring] $repo_url" > "/etc/apt/sources.list.d/${repo_name}.list"
            else
                echo "deb $repo_url" > "/etc/apt/sources.list.d/${repo_name}.list"
            fi
            $PKG_UPDATE
            ;;
        dnf|yum)
            if [[ -n "$gpg_key_url" ]]; then
                rpm --import "$gpg_key_url" 2>/dev/null || true
            fi
            cat > "/etc/yum.repos.d/${repo_name}.repo" << EOF
[${repo_name}]
name=${repo_name}
baseurl=${repo_url}
enabled=1
gpgcheck=1
EOF
            ;;
        *)
            log_warn "Third-party repository addition not implemented for $PKG_MGR"
            ;;
    esac
}

# ---------- Initialization ----------
initialize_distro_detection() {
    log_debug "Initializing distribution detection"
    
    detect_distribution
    detect_package_manager
    setup_package_manager_env
    
    log_info "System: ${DISTRO_ID} ${DISTRO_VERSION} (${PKG_MGR})"
    log_info "Architecture: $(detect_architecture)"
}