#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Installation Management Library
# Core installation logic, PATH management, and verification
# =====================================================================

# Prevent multiple inclusion
[[ "${INSTALLER_LIB_LOADED:-}" == "true" ]] && return 0
readonly INSTALLER_LIB_LOADED="true"

# Source required libraries
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/distro.sh"

# ---------- Installation Modes ----------
readonly MODE_SYSTEM="system"
readonly MODE_USER="user"

# Installation paths
INSTALL_MODE=""
BIN_DIR=""
OPT_DIR=""
PROFILE_RC=""

# ---------- Path Management ----------
setup_installation_paths() {
    if [[ "${USER_MODE:-0}" == "1" ]] || ! is_root; then
        #!/usr/bin/env bash
        log_info "System-wide installation: $BIN_DIR"
    fi
    
    # Create necessary directories
    ensure_directory "$BIN_DIR"
    ensure_directory "$OPT_DIR"
    
    # Export for use by modules
    export INSTALL_MODE BIN_DIR OPT_DIR PROFILE_RC
}

# Ensure directory is in PATH
ensure_path() {
    local dir="$1"
    
    # Check if already in PATH
    case ":$PATH:" in
        *":$dir:"*) 
            log_debug "Directory already in PATH: $dir"
            return 0
            ;;
        *) 
            log_debug "Adding directory to PATH: $dir"
            export PATH="$dir:$PATH"
            ;;
    esac
    
    # Make PATH addition persistent
    if is_dry_run; then
        log_info "DRY-RUN: Would add $dir to PATH in $PROFILE_RC"
        return 0
    fi
    
    if [[ "$INSTALL_MODE" == "$MODE_USER" ]]; then
        # User-mode: append to .bashrc if not already present
        if [[ -f "$PROFILE_RC" ]] && grep -qs "$dir" "$PROFILE_RC" 2>/dev/null; then
            log_debug "PATH already configured in $PROFILE_RC"
        else
            log_debug "Adding PATH configuration to $PROFILE_RC"
            echo "export PATH=\"$dir:\$PATH\"" >> "$PROFILE_RC"
        fi
    else
        # System-mode: create profile.d script
        log_debug "Creating system-wide PATH configuration: $PROFILE_RC"
        ensure_directory "$(dirname "$PROFILE_RC")"
        echo "export PATH=\"$dir:\$PATH\"" > "$PROFILE_RC"
        chmod 644 "$PROFILE_RC" 2>/dev/null || true
    fi
}

# ---------- Version Management ----------
compare_versions() {
    local installed="$1"
    local available="$2"
    
    if [[ -z "$installed" ]]; then
        echo "not_installed"
    elif [[ -z "$available" ]]; then
        echo "unknown_latest"
    elif [[ "$installed" == "$available" ]]; then
        echo "current"
    elif is_version_newer "$installed" "$available"; then
        echo "newer"
    else
        echo "outdated"
    fi
}

# ---------- Download Functions ----------
download_and_verify() {
    local url="$1"
    local output_file="$2"
    local checksum="${3:-}"
    local checksum_algo="${4:-sha256}"
    
    log_debug "Downloading: $url"
    
    if ! download_file "$url" "$output_file"; then
        return 1
    fi
    
    # Verify checksum if provided
    if [[ -n "$checksum" ]]; then
        log_debug "Verifying checksum: $output_file"
        if ! validate_file_hash "$output_file" "$checksum" "$checksum_algo"; then
            rm -f "$output_file"
            return 1
        fi
    fi
    
    return 0
}

# Download and extract archive
download_and_extract() {
    local url="$1"
    local extract_dir="$2"
    local archive_type="${3:-auto}"
    
    local temp_file
    temp_file=$(mktemp)
    TEMP_FILES="$TEMP_FILES $temp_file"
    
    if ! download_file "$url" "$temp_file"; then
        return 1
    fi
    
    # Auto-detect archive type if not specified
    if [[ "$archive_type" == "auto" ]]; then
        case "$url" in
            *.tar.gz|*.tgz) archive_type="tar.gz" ;;
            *.tar.xz|*.txz) archive_type="tar.xz" ;;
            *.zip) archive_type="zip" ;;
            *) 
                log_error "Cannot determine archive type from URL: $url"
                return 1
                ;;
        esac
    fi
    
    log_debug "Extracting $archive_type archive to $extract_dir"
    ensure_directory "$extract_dir"
    
    case "$archive_type" in
        tar.gz|tgz)
            tar -xzf "$temp_file" -C "$extract_dir" || return 1
            ;;
        tar.xz|txz)
            tar -xJf "$temp_file" -C "$extract_dir" || return 1
            ;;
        zip)
            unzip -q "$temp_file" -d "$extract_dir" || return 1
            ;;
        *)
            log_error "Unsupported archive type: $archive_type"
            return 1
            ;;
    esac
    
    return 0
}

# ---------- Installation Functions ----------
install_single_binary() {
    local name="$1"
    local source_path="$2"
    local target_name="${3:-$name}"
    
    local target_path="$BIN_DIR/$target_name"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would install $name -> $target_path"
        return 0
    fi
    
    log_debug "Installing binary: $name -> $target_path"
    install_binary "$source_path" "$target_path"
    
    # Ensure it's in PATH
    ensure_path "$BIN_DIR"
    
    # Verify installation
    if [[ -x "$target_path" ]]; then
        log_info "Successfully installed: $name"
        return 0
    else
        log_error "Installation verification failed: $name"
        return 1
    fi
}

# Generic installer for pre-built binaries
install_prebuilt_binary() {
    local name="$1"
    local download_url="$2"
    local is_archive="${3:-false}"
    local binary_path="${4:-$name}"
    
    log_info "Installing $name from pre-built binary"
    
    local temp_dir
    temp_dir=$(mktemp -d)
    TEMP_FILES="$TEMP_FILES $temp_dir"
    
    if [[ "$is_archive" == "true" ]]; then
        # Download and extract archive
        if ! download_and_extract "$download_url" "$temp_dir"; then
            log_error "Failed to download/extract $name"
            return 1
        fi
        
        # Find the binary in extracted files
        local binary_file
        binary_file=$(find "$temp_dir" -name "$binary_path" -type f -executable | head -1)
        
        if [[ -z "$binary_file" ]]; then
            log_error "Binary not found in archive: $binary_path"
            return 1
        fi
        
        # Install the binary
        install_single_binary "$name" "$binary_file"
    else
        # Direct binary download
        local temp_binary="$temp_dir/$name"
        
        if ! download_file "$download_url" "$temp_binary"; then
            log_error "Failed to download $name"
            return 1
        fi
        
        chmod +x "$temp_binary"
        install_single_binary "$name" "$temp_binary"
    fi
}

# ---------- Package Installation ----------
install_system_packages() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_debug "No packages to install"
        return 0
    fi
    
    log_info "Installing system packages: ${packages[*]}"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would install packages: ${packages[*]}"
        return 0
    fi
    
    # Update package index first
    log_debug "Updating package index"
    eval "$PKG_UPDATE" || log_warn "Package index update failed"
    
    # Install packages
    local install_cmd="$PKG_INSTALL ${packages[*]}"
        # Add --allowerasing for dnf/yum to resolve package conflicts (e.g., curl/curl-minimal)
        if [[ "$PKG_MGR" == "dnf" || "$PKG_MGR" == "yum" ]]; then
            install_cmd="$PKG_MGR install -y --allowerasing ${packages[*]}"
        fi
    log_debug "Running: $install_cmd"
    
    if eval "$install_cmd"; then
        log_info "Successfully installed system packages"
        return 0
    else
        log_error "Failed to install some system packages"
        return 1
    fi
}

# Install baseline development packages
install_baseline_packages() {
    local packages
    packages=$(get_baseline_packages "$PKG_MGR")
    
    if [[ -n "$packages" ]]; then
        log_info "Installing baseline packages for $PKG_MGR"
        # Convert space-separated string to array
        # shellcheck disable=SC2086
        install_system_packages $packages
    else
        log_warn "No baseline packages defined for $PKG_MGR"
    fi
}

# ---------- Service Management ----------
start_and_enable_service() {
    local service_name="$1"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would start and enable service: $service_name"
        return 0
    fi
    
    if has_systemd; then
        log_debug "Starting and enabling service: $service_name"
        
        if systemctl start "$service_name" 2>/dev/null; then
            log_debug "Service started: $service_name"
        else
            log_warn "Failed to start service: $service_name"
        fi
        
        if systemctl enable "$service_name" 2>/dev/null; then
            log_debug "Service enabled: $service_name"
        else
            log_warn "Failed to enable service: $service_name"
        fi
    else
        log_warn "systemd not available, cannot manage service: $service_name"
    fi
}

# ---------- User Management ----------
add_user_to_group() {
    local user="$1"
    local group="$2"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would add user $user to group $group"
        return 0
    fi
    
    if ! getent group "$group" >/dev/null 2>&1; then
        log_debug "Creating group: $group"
        groupadd "$group" 2>/dev/null || log_warn "Failed to create group: $group"
    fi
    
    if usermod -aG "$group" "$user" 2>/dev/null; then
        log_info "Added user $user to group $group"
        log_warn "Please log out and back in for group membership to take effect"
    else
        log_warn "Failed to add user $user to group $group"
    fi
}

# ---------- Cleanup Functions ----------
cleanup_installation() {
    local temp_base="$OPT_DIR/temp"
    
    if [[ -d "$temp_base" ]]; then
        log_debug "Cleaning up temporary installation files"
        rm -rf "$temp_base" 2>/dev/null || true
    fi
}

# Remove installed tool
uninstall_tool() {
    local name="$1"
    local binary_path="$BIN_DIR/$name"
    local opt_path="$OPT_DIR/$name"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would uninstall $name"
        return 0
    fi
    
    log_info "Uninstalling $name"
    
    # Remove binary
    if [[ -f "$binary_path" ]]; then
        rm -f "$binary_path"
        log_debug "Removed binary: $binary_path"
    fi
    
    # Remove optional installation directory
    if [[ -d "$opt_path" ]]; then
        rm -rf "$opt_path"
        log_debug "Removed directory: $opt_path"
    fi
    
    log_info "Successfully uninstalled $name"
}

# ---------- Verification Functions ----------
verify_installation() {
    local name="$1"
    local expected_version="${2:-}"
    local version_cmd="${3:-$name --version}"
    
    local binary_path
    binary_path=$(where_cmd "$name")
    
    if [[ -z "$binary_path" ]]; then
        log_error "Verification failed: $name not found in PATH"
        return 1
    fi
    
    if [[ ! -x "$binary_path" ]]; then
        log_error "Verification failed: $name not executable"
        return 1
    fi
    
    # Check version if provided
    if [[ -n "$expected_version" ]]; then
        local actual_version
        actual_version=$(get_local_version "$name" "--version")
        
        if [[ -n "$actual_version" ]]; then
            log_debug "Installed version: $actual_version"
            if [[ "$actual_version" != "$expected_version" ]]; then
                log_warn "Version mismatch for $name: expected $expected_version, got $actual_version"
            fi
        else
            log_warn "Could not determine version for $name"
        fi
    fi
    
    log_debug "Verification successful: $name"
    return 0
}

# Verify tool functionality
test_tool_functionality() {
    local name="$1"
    local test_cmd="${2:-$name --help}"
    
    log_debug "Testing functionality: $name"
    
    if run_with_timeout 10 bash -c "$test_cmd" >/dev/null 2>&1; then
        log_debug "Functionality test passed: $name"
        return 0
    else
        log_warn "Functionality test failed: $name"
        return 1
    fi
}

# ---------- Backup Functions ----------
backup_existing_binary() {
    local name="$1"
    local backup_suffix="${2:-.backup}"
    
    local binary_path="$BIN_DIR/$name"
    local backup_path="${binary_path}${backup_suffix}"
    
    if [[ -f "$binary_path" ]]; then
        log_debug "Backing up existing binary: $name"
        if is_dry_run; then
            log_info "DRY-RUN: Would backup $binary_path -> $backup_path"
        else
            cp "$binary_path" "$backup_path" || log_warn "Failed to backup $name"
        fi
    fi
}

restore_backup() {
    local name="$1"
    local backup_suffix="${2:-.backup}"
    
    local binary_path="$BIN_DIR/$name"
    local backup_path="${binary_path}${backup_suffix}"
    
    if [[ -f "$backup_path" ]]; then
        log_info "Restoring backup: $name"
        if is_dry_run; then
            log_info "DRY-RUN: Would restore $backup_path -> $binary_path"
        else
            mv "$backup_path" "$binary_path" || log_warn "Failed to restore backup for $name"
        fi
    else
        log_warn "No backup found for $name"
    fi
}

# ---------- Initialization ----------
initialize_installer() {
    log_debug "Initializing installer library"
    
    setup_installation_paths
    
    # Set up cleanup on exit
    trap cleanup_installation EXIT
}