#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Container Tools Module
# Docker, Podman, and container runtime installation
# =====================================================================

# Prevent multiple inclusion
[[ "${CONTAINERS_MODULE_LOADED:-}" == "true" ]] && return 0
readonly CONTAINERS_MODULE_LOADED="true"

# Source required libraries
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/installer.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/security.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/../lib/versioncheck.sh"

# ---------- Module Configuration ----------
readonly CONTAINERS_CATEGORY="containers"

# Docker configuration
readonly DOCKER_GPG_KEY="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
readonly DOCKER_COMPOSE_GITHUB_REPO="docker/compose"

# ---------- Docker Engine Installation ----------
install_docker_engine() {
    local current_version
    current_version=$(get_local_version "docker" "--version" '[0-9]+(\.[0-9]+)+')
    
    if [[ -n "$current_version" ]]; then
        log_info "Docker already installed: $current_version"
        verify_installation "docker" "$current_version"
        add_tool_result "Docker Engine" "$CONTAINERS_CATEGORY" "$current_version" "latest" "installed" "$(where_cmd docker)" "verified"
        return 0
    fi
    
    log_info "Installing Docker Engine"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would install Docker Engine"
        add_tool_result "Docker Engine" "$CONTAINERS_CATEGORY" "" "latest" "would_install" "" "pending"
        return 0
    fi
    
    case "$PKG_MGR" in
        apt)
            install_docker_apt
            ;;
        dnf|yum)
            install_docker_rpm
            ;;
        zypper)
            install_docker_rpm
            ;;
        pacman)
            install_docker_pacman
            ;;
        *)
            log_error "Docker installation not supported for package manager: $PKG_MGR"
            add_tool_result "Docker Engine" "$CONTAINERS_CATEGORY" "" "latest" "failed" "" "failed"
            return 1
            ;;
    esac
    
    # Post-installation configuration
    configure_docker_post_install
    
    # Verify installation
    local installed_version
    installed_version=$(get_local_version "docker" "--version" '[0-9]+(\.[0-9]+)+')
    
    if [[ -n "$installed_version" ]]; then
        log_info "Docker Engine successfully installed: $installed_version"
        add_tool_result "Docker Engine" "$CONTAINERS_CATEGORY" "$installed_version" "latest" "installed" "$(where_cmd docker)" "verified"
    else
        log_error "Docker Engine installation verification failed"
        add_tool_result "Docker Engine" "$CONTAINERS_CATEGORY" "" "latest" "failed" "" "failed"
        return 1
    fi
}

install_docker_apt() {
    log_debug "Installing Docker via APT"
    
    # Install prerequisites
    install_system_packages ca-certificates curl gnupg lsb-release
    
    # Set up Docker repository
    setup_docker_repository "$DISTRO_ID" "$PKG_MGR"
    
    # Install Docker packages
    install_system_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_rpm() {
    log_debug "Installing Docker via RPM-based package manager"
    
    # Use Docker's convenience script for RPM-based systems
    local install_script="/tmp/docker-install.sh"
    
    if secure_download "https://get.docker.com" "$install_script"; then
        bash "$install_script" || {
            log_error "Docker installation script failed"
            return 1
        }
        rm -f "$install_script"
    else
        log_error "Failed to download Docker installation script"
        return 1
    fi
}

install_docker_pacman() {
    log_debug "Installing Docker via pacman"
    
    # Install Docker from Arch repositories
    install_system_packages docker docker-compose
}

configure_docker_post_install() {
    log_debug "Configuring Docker post-installation"
    
    # Enable and start Docker service
    start_and_enable_service "docker"
    
    # Add current user to docker group (if not root)
    if [[ "$INSTALL_MODE" == "$MODE_USER" ]] && ! is_root; then
        local current_user
        current_user=$(whoami)
        add_user_to_group "$current_user" "docker"
    fi
    
    # Test Docker installation
    if ! is_dry_run && command_exists docker; then
        log_debug "Testing Docker installation"
        if timeout 30 docker info >/dev/null 2>&1; then
            log_debug "Docker service test successful"
        else
            log_warn "Docker service test failed - may need service restart"
        fi
    fi
}

# ---------- Docker Compose Installation ----------
install_docker_compose() {
    # Check if Docker Compose is already available via plugin
    if command_exists docker && docker compose version >/dev/null 2>&1; then
        local version
        version=$(docker compose version --short 2>/dev/null || echo "plugin")
        log_info "Docker Compose plugin already available: $version"
        add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "$version" "latest" "installed" "docker-compose-plugin" "verified"
        return 0
    fi
    
    # Install standalone Docker Compose
    local current_version
    current_version=$(get_local_version "docker-compose" "--version" '[0-9]+(\.[0-9]+)+')
    
    if [[ -n "$current_version" ]]; then
        log_info "Docker Compose already installed: $current_version"
        add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "$current_version" "latest" "installed" "$(where_cmd docker-compose)" "verified"
        return 0
    fi
    
    log_info "Installing Docker Compose"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would install Docker Compose"
        add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "" "latest" "would_install" "" "pending"
        return 0
    fi
    
    # Get latest version from GitHub
    local latest_version
    latest_version=$(curl -fsSL "https://api.github.com/repos/$DOCKER_COMPOSE_GITHUB_REPO/releases/latest" | \
        jq -r '.tag_name' 2>/dev/null | sed 's/^v//')
    
    if [[ -z "$latest_version" ]]; then
        log_warn "Could not determine latest Docker Compose version"
        latest_version="2.24.0"  # Fallback version
    fi
    
    # Determine architecture
    local arch
    arch=$(map_arch_for_vendor "$(detect_architecture)" "docker")
    
    # Download and install
    local download_url="https://github.com/$DOCKER_COMPOSE_GITHUB_REPO/releases/download/v${latest_version}/docker-compose-linux-${arch}"
    local binary_path="$BIN_DIR/docker-compose"
    
    if download_file "$download_url" "$binary_path"; then
        chmod +x "$binary_path"
        
        # Verify installation
        local installed_version
        installed_version=$(get_local_version "docker-compose" "--version" '[0-9]+(\.[0-9]+)+')
        
        if [[ -n "$installed_version" ]]; then
            log_info "Docker Compose successfully installed: $installed_version"
            add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "$installed_version" "$latest_version" "installed" "$binary_path" "verified"
        else
            log_error "Docker Compose installation verification failed"
            add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "" "$latest_version" "failed" "" "failed"
            return 1
        fi
    else
        log_error "Failed to download Docker Compose"
        add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "" "$latest_version" "failed" "" "failed"
        return 1
    fi
}

# ---------- Podman Installation ----------
install_podman() {
    local current_version
    current_version=$(get_local_version "podman" "--version" '[0-9]+(\.[0-9]+)+')
    
    if [[ -n "$current_version" ]]; then
        log_info "Podman already installed: $current_version"
        add_tool_result "Podman" "$CONTAINERS_CATEGORY" "$current_version" "latest" "installed" "$(where_cmd podman)" "verified"
        return 0
    fi
    
    log_info "Installing Podman"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would install Podman"
        add_tool_result "Podman" "$CONTAINERS_CATEGORY" "" "latest" "would_install" "" "pending"
        return 0
    fi
    
    case "$PKG_MGR" in
        apt)
            # Add Podman repository for Ubuntu
            if [[ "$DISTRO_ID" == "ubuntu" ]]; then
                local ubuntu_version
                ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
                
                add_third_party_repository "podman" \
                    "http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${ubuntu_version}/ /" \
                    "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${ubuntu_version}/Release.key"
            fi
            
            install_system_packages podman
            ;;
        dnf|yum)
            install_system_packages podman
            ;;
        zypper)
            install_system_packages podman
            ;;
        pacman)
            install_system_packages podman
            ;;
        *)
            log_warn "Podman installation not supported for package manager: $PKG_MGR"
            add_tool_result "Podman" "$CONTAINERS_CATEGORY" "" "latest" "not_supported" "" "failed"
            return 1
            ;;
    esac
    
    # Verify installation
    local installed_version
    installed_version=$(get_local_version "podman" "--version" '[0-9]+(\.[0-9]+)+')
    
    if [[ -n "$installed_version" ]]; then
        log_info "Podman successfully installed: $installed_version"
        add_tool_result "Podman" "$CONTAINERS_CATEGORY" "$installed_version" "latest" "installed" "$(where_cmd podman)" "verified"
        
        # Configure rootless containers if not root
        if [[ "$INSTALL_MODE" == "$MODE_USER" ]]; then
            configure_podman_rootless
        fi
    else
        log_error "Podman installation verification failed"
        add_tool_result "Podman" "$CONTAINERS_CATEGORY" "" "latest" "failed" "" "failed"
        return 1
    fi
}

configure_podman_rootless() {
    log_debug "Configuring Podman for rootless containers"
    
    # Check if user namespaces are available
    if [[ -f /proc/sys/user/max_user_namespaces ]]; then
        local max_namespaces
        max_namespaces=$(cat /proc/sys/user/max_user_namespaces)
        
        if [[ "$max_namespaces" -eq 0 ]]; then
            log_warn "User namespaces are disabled - rootless containers may not work"
        fi
    fi
    
    # Initialize Podman for current user
    if command_exists podman && ! is_dry_run; then
        podman system migrate 2>/dev/null || log_debug "Podman migration not needed"
    fi
}

# ---------- Container Runtime Tools ----------
install_containerd() {
    local current_version
    current_version=$(get_local_version "containerd" "--version" '[0-9]+(\.[0-9]+)+')
    
    if [[ -n "$current_version" ]]; then
        log_info "containerd already installed: $current_version"
        add_tool_result "containerd" "$CONTAINERS_CATEGORY" "$current_version" "latest" "installed" "$(where_cmd containerd)" "verified"
        return 0
    fi
    
    log_info "Installing containerd"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would install containerd"
        add_tool_result "containerd" "$CONTAINERS_CATEGORY" "" "latest" "would_install" "" "pending"
        return 0
    fi
    
    # containerd is typically installed with Docker
    # For standalone installation, use distribution packages
    install_system_packages containerd || install_system_packages containerd.io
    
    # Verify installation
    local installed_version
    installed_version=$(get_local_version "containerd" "--version" '[0-9]+(\.[0-9]+)+')
    
    if [[ -n "$installed_version" ]]; then
        log_info "containerd successfully installed: $installed_version"
        add_tool_result "containerd" "$CONTAINERS_CATEGORY" "$installed_version" "latest" "installed" "$(where_cmd containerd)" "verified"
    else
        log_error "containerd installation verification failed"
        add_tool_result "containerd" "$CONTAINERS_CATEGORY" "" "latest" "failed" "" "failed"
        return 1
    fi
}

# ---------- Module Interface Functions ----------
containers_check() {
    log_debug "Checking container tools status"

    # Check Docker
    local docker_version docker_latest
    docker_version=$(get_local_version "docker" "--version" '[0-9]+(\.[0-9]+)+')
    docker_latest=$(get_latest_version_cached "docker")
    if [[ -n "$docker_version" ]]; then
        add_tool_result "Docker Engine" "$CONTAINERS_CATEGORY" "$docker_version" "$docker_latest" "installed" "$(where_cmd docker)" "verified"
    else
        add_tool_result "Docker Engine" "$CONTAINERS_CATEGORY" "" "$docker_latest" "not_found" "" "unknown"
    fi

    # Check Docker Compose
    local compose_version compose_latest
    compose_latest=$(get_latest_version_cached "docker-compose")
    compose_version=$(get_local_version "docker-compose" "--version" '[0-9]+(\.[0-9]+)+')
    if command_exists docker && docker compose version >/dev/null 2>&1; then
        compose_version=$(docker compose version --short 2>/dev/null || echo "plugin")
        add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "$compose_version" "$compose_latest" "installed" "docker-compose-plugin" "verified"
    elif [[ -n "$compose_version" ]]; then
        add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "$compose_version" "$compose_latest" "installed" "$(where_cmd docker-compose)" "verified"
    else
        add_tool_result "Docker Compose" "$CONTAINERS_CATEGORY" "" "$compose_latest" "not_found" "" "unknown"
    fi

    # Check Podman
    local podman_version podman_latest
    podman_version=$(get_local_version "podman" "--version" '[0-9]+(\.[0-9]+)+')
    podman_latest=$(get_latest_version_cached "podman")
    if [[ -n "$podman_version" ]]; then
        add_tool_result "Podman" "$CONTAINERS_CATEGORY" "$podman_version" "$podman_latest" "installed" "$(where_cmd podman)" "verified"
    else
        add_tool_result "Podman" "$CONTAINERS_CATEGORY" "" "$podman_latest" "not_found" "" "unknown"
    fi

    # Check containerd
    local containerd_version containerd_latest
    containerd_version=$(get_local_version "containerd" "--version" '[0-9]+(\.[0-9]+)+')
    containerd_latest=$(get_latest_version_cached "containerd")
    if [[ -n "$containerd_version" ]]; then
        add_tool_result "containerd" "$CONTAINERS_CATEGORY" "$containerd_version" "$containerd_latest" "installed" "$(where_cmd containerd)" "verified"
    else
        add_tool_result "containerd" "$CONTAINERS_CATEGORY" "" "$containerd_latest" "not_found" "" "unknown"
    fi
}

containers_install() {
    local tools="${1:-docker,docker-compose}"
    
    log_info "Installing container tools: $tools"
    
    IFS=',' read -ra tool_array <<< "$tools"
    
    # Detect WSL
    if grep -qiE "microsoft|wsl" /proc/version; then
        log_warn "WSL detected: Skipping container tool installation."
        return 0
    fi
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        # "pkg" is the apt/dnf/pacman package to install; "cmd" is the
        # resulting binary name used for verification and reporting. These
        # differ for docker on Debian/Ubuntu, which ships the engine as the
        # "docker.io" package (the bare "docker" apt package doesn't exist
        # there and only resolves to virtual packages like moby-engine).
        local pkg="" cmd=""
        case "$tool" in
            docker|docker-engine)
                cmd="docker"
                if [[ "$PKG_MGR" == "apt" ]]; then
                    pkg="docker.io"
                else
                    pkg="docker"
                fi
                ;;
            docker-compose|compose) pkg="docker-compose"; cmd="docker-compose" ;;
            podman) pkg="podman"; cmd="podman" ;;
            containerd) pkg="containerd"; cmd="containerd" ;;
            *)
                log_warn "Unknown container tool: $tool"
                continue
                ;;
        esac

        local latest
        latest=$(get_latest_version_cached "$cmd")

        if is_dry_run; then
            log_info "DRY-RUN: Would install $pkg"
            add_tool_result "$cmd" "$CONTAINERS_CATEGORY" "" "$latest" "would_install" "" "pending"
            continue
        fi

        install_system_packages "$pkg"

        local installed_version
        installed_version=$(get_local_version "$cmd" "--version" '[0-9]+(\.[0-9]+)+')
        if [[ -n "$installed_version" ]]; then
            add_tool_result "$cmd" "$CONTAINERS_CATEGORY" "$installed_version" "$latest" "installed" "$(where_cmd "$cmd")" "verified"
        else
            log_error "$cmd installation verification failed"
            add_tool_result "$cmd" "$CONTAINERS_CATEGORY" "" "$latest" "failed" "" "failed"
        fi
    done
}

containers_upgrade() {
    log_info "Upgrading container tools"
    
    # For now, use the install function which will handle upgrades
    containers_install "docker,docker-compose,podman"
}

containers_verify() {
    log_info "Verifying container tools"
    
    local verification_failed=false
    
    # Verify Docker
    if command_exists docker; then
        if test_tool_functionality "docker" "docker --help"; then
            log_debug "Docker functionality verified"
        else
            log_warn "Docker functionality test failed"
            verification_failed=true
        fi
    fi
    
    # Verify Docker Compose
    if command_exists docker-compose; then
        if test_tool_functionality "docker-compose" "docker-compose --help"; then
            log_debug "Docker Compose functionality verified"
        else
            log_warn "Docker Compose functionality test failed"
            verification_failed=true
        fi
    elif command_exists docker && docker compose version >/dev/null 2>&1; then
        log_debug "Docker Compose plugin verified"
    fi
    
    # Verify Podman
    if command_exists podman; then
        if test_tool_functionality "podman" "podman --help"; then
            log_debug "Podman functionality verified"
        else
            log_warn "Podman functionality test failed"
            verification_failed=true
        fi
    fi
    
    [[ "$verification_failed" != "true" ]]
}

containers_remove() {
    local tools="${1:-docker,docker-compose,podman}"
    
    log_info "Removing container tools: $tools"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would remove container tools: $tools"
        return 0
    fi
    
    IFS=',' read -ra tool_array <<< "$tools"
    
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        
        case "$tool" in
            docker|docker-engine)
                # Stop and disable Docker service
                if has_systemd; then
                    systemctl stop docker 2>/dev/null || true
                    systemctl disable docker 2>/dev/null || true
                fi
                
                # Remove Docker packages
                case "$PKG_MGR" in
                    apt) eval "$PKG_REMOVE docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" ;;
                    dnf|yum) eval "$PKG_REMOVE docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" ;;
                    zypper) eval "$PKG_REMOVE docker docker-compose" ;;
                    pacman) eval "$PKG_REMOVE docker docker-compose" ;;
                esac
                ;;
            docker-compose|compose)
                uninstall_tool "docker-compose"
                ;;
            podman)
                eval "$PKG_REMOVE podman"
                ;;
        esac
    done
}

# ---------- Initialization ----------
initialize_containers_module() {
    log_debug "Initializing containers module"
}