
#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap v1.0.0
# Enterprise-ready development environment setup for Linux
# 
# Features:
# • Modular architecture with pluggable tool modules
# • Dry-run and check-only modes
# • Selective installation by category or individual tools
# • Configuration-driven setup with YAML support
# • Enhanced security with signature verification
# • Comprehensive reporting and compliance features

# Source core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/distro.sh"

# ---------- Argument Parsing ----------
parse_arguments() {
    local command="install"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Commands
            install|check|upgrade|remove|list)
                command="$1"
                shift
                ;;
            # Installation mode
            --system)
                USER_MODE=0
                shift
                ;;
            --user)
                USER_MODE=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --force)
                FORCE_INSTALL=1
                shift
                ;;
            --upgrade)
                UPGRADE_MODE=1
                shift
                ;;
            # Tool selection
            --categories)
                SELECTED_CATEGORIES="$2"
                shift 2
                ;;
            --tools)
                SELECTED_TOOLS="$2"
                shift 2
                ;;
            --exclude)
                EXCLUDE_TOOLS="$2"
                shift 2
                ;;
            --versions)
                VERSION_CONSTRAINTS="$2"
                shift 2
                ;;
            # Configuration
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --profile)
                CONFIG_FILE="$SCRIPT_DIR/config/$2.yml"
                shift 2
                ;;
            # Security
            --verify-signatures)
                VERIFY_SIGNATURES="true"
                shift
                ;;
            --verify-checksums)
                VERIFY_CHECKSUMS="true"
                shift
                ;;
            --no-verify)
                VERIFY_SIGNATURES="false"
                VERIFY_CHECKSUMS="false"
                shift
                ;;
            --audit-log)
                AUDIT_LOGGING="true"
                SECURITY_LOG_FILE="$2"
                shift 2
                ;;
            # Output and reporting
            --output-formats)
                OUTPUT_FORMATS="$2"
                shift 2
                ;;
            --output-dir)
                REPORT_OUTPUT_DIR="$2"
                shift 2
                ;;
            --compliance-report)
                GENERATE_COMPLIANCE="true"
                shift
                ;;
            --quiet)
                LOG_LEVEL=$LOG_LEVEL_WARN
                shift
                ;;
            --verbose)
                VERBOSE=1
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            --debug)
                DEBUG=1
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                set -x
                shift
                ;;
            # Global flag: force latest version check
            --force-latest)
                FORCE_LATEST=1
                shift
                ;;
            # Help and information
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --list-tools)
                list_available_tools
                exit 0
                ;;
            --list-categories)
                list_available_categories
                exit 0
                ;;
            # Unknown option
            --*)
                die $EXIT_INVALID_ARGS "Unknown option: $1"
                ;;
            # Positional arguments
            *)
                # First positional argument is command if not already set
                if [[ "$command" == "install" && "$1" != "install" ]]; then
                    command="$1"
                else
                    die $EXIT_INVALID_ARGS "Unknown argument: $1"
                fi
                shift
                ;;
        esac
    done
    # Export command for use by other functions
    export COMMAND="$command"
    # Export configuration
    export DRY_RUN CHECK_ONLY FORCE_INSTALL UPGRADE_MODE USER_MODE VERBOSE DEBUG
    export SELECTED_CATEGORIES SELECTED_TOOLS VERSION_CONSTRAINTS OUTPUT_FORMATS
}

# ---------- Configuration Loading ----------
load_configuration() {
    local config_files=(
        "$SCRIPT_DIR/config/default.yml"
        "/etc/devtools/config.yml"
        "$HOME/.config/devtools.yml"
    )
    
    # Add user-specified config file
    if [[ -n "$CONFIG_FILE" ]]; then
        config_files+=("$CONFIG_FILE")
    fi
    
    log_info "Loading configuration files..."
    
    for config_file in "${config_files[@]}"; do
        if [[ -r "$config_file" ]]; then
            log_debug "Loading config: $config_file"
            # Parse YAML and set CONFIG_<tool> variables for tool enablement
            awk '/^[ ]*[a-zA-Z0-9_-]+:[ ]*(true|auto)/ {gsub(/:/,"",$0); gsub(/[ \t]+/," ",$0); split($0,a," "); key=a[1]; value=a[2]; gsub("-","_",key); print key ":" value}' "$config_file" | while IFS=: read -r key value; do
                export CONFIG_${key}="$value"
            done
        else
            log_debug "Config file not found: $config_file"
        fi
    done
}

# ---------- Module Loading ----------
load_tool_modules() {
    local modules=(
        "containers"
        "kubernetes" 
        "hashicorp"
        "cloud"
        "devtools"
    )
    
    log_debug "Loading tool modules..."
    
    for module in "${modules[@]}"; do
        local module_file="$SCRIPT_DIR/modules/${module}.sh"
        if [[ -r "$module_file" ]]; then
            log_debug "Loading module: $module"
            # shellcheck disable=SC1090
            source "$module_file"
        else
            log_warn "Module not found: $module_file"
        fi
    done
}

# ---------- Command Execution ----------
execute_command() {
    local command="$COMMAND"
    
    case "$command" in
        install)
            execute_install_command
            ;;
        check)
            execute_check_command
            ;;
        upgrade)
            execute_upgrade_command
            ;;
        remove)
            execute_remove_command
            ;;
        list)
            execute_list_command
            ;;
        *)
            die $EXIT_INVALID_ARGS "Unknown command: $command"
            ;;
    esac
}

execute_install_command() {
    title "InSight Dev Bootstrap - Installation"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY-RUN MODE: No changes will be made"
    fi
    
    # Install baseline packages first
    if ! is_check_only; then
        log_info "Installing baseline system packages"
        install_baseline_packages
    fi
    
    # Determine what to install
    local categories_to_install=""
    local tools_to_install=""
    
    if [[ -n "$SELECTED_CATEGORIES" ]]; then
        categories_to_install="$SELECTED_CATEGORIES"
    else
        # Use default categories from configuration
        categories_to_install="containers,kubernetes,hashicorp,cloud,devtools"
    fi
    
    if [[ -n "$SELECTED_TOOLS" ]]; then
        tools_to_install="$SELECTED_TOOLS"
    fi
    
    # Install by categories
    if [[ -n "$categories_to_install" ]]; then
        IFS=',' read -ra category_array <<< "$categories_to_install"
        for category in "${category_array[@]}"; do
            category=$(trim "$category")
            log_info "Installing category: $category"

            # Build tool list for this category from config
            local tool_list=""
            case "$category" in
                containers)
                    for t in docker docker-compose podman containerd; do
                        v="CONFIG_${t//-/_}"
                        if [[ "${!v:-}" == "true" || "${!v:-}" == "auto" ]]; then
                            tool_list+="$t," 
                        fi
                    done
                    ;;
                kubernetes)
                    for t in kubectl helm k9s; do
                        v="CONFIG_${t//-/_}"
                        if [[ "${!v:-}" == "true" || "${!v:-}" == "auto" ]]; then
                            tool_list+="$t," 
                        fi
                    done
                    ;;
                hashicorp)
                    for t in terraform packer vault consul; do
                        v="CONFIG_${t//-/_}"
                        if [[ "${!v:-}" == "true" || "${!v:-}" == "auto" ]]; then
                            tool_list+="$t," 
                        fi
                    done
                    ;;
                cloud)
                    for t in aws_cli gcloud azure_cli bicep; do
                        v="CONFIG_${t//-/_}"
                        if [[ "${!v:-}" == "true" || "${!v:-}" == "auto" ]]; then
                            tool_list+="$t," 
                        fi
                    done
                    ;;
                devtools)
                    for t in pyenv nvm rbenv git jq powershell; do
                        v="CONFIG_${t//-/_}"
                        if [[ "${!v:-}" == "true" || "${!v:-}" == "auto" ]]; then
                            tool_list+="$t," 
                        fi
                    done
                    ;;
                *)
                    log_warn "Unknown category: $category"
                    ;;
            esac
            # Remove trailing comma
            tool_list="${tool_list%,}"
            # Call the appropriate module installer
            case "$category" in
                containers)
                    if command_exists containers_install; then
                        containers_install "$tool_list"
                    else
                        log_warn "Containers module not loaded"
                    fi
                    ;;
                kubernetes)
                    if command_exists install_kubernetes_tools; then
                        install_kubernetes_tools "$tool_list"
                    else
                        log_warn "Kubernetes module not loaded"
                    fi
                    ;;
                hashicorp)
                    if command_exists install_hashicorp_tools; then
                        install_hashicorp_tools "$tool_list"
                    else
                        log_warn "HashiCorp module not loaded"
                    fi
                    ;;
                cloud)
                    if command_exists install_cloud_tools; then
                        install_cloud_tools "$tool_list"
                    else
                        log_warn "Cloud module not loaded"
                    fi
                    ;;
                devtools)
                    if command_exists install_devtools; then
                        install_devtools "$tool_list"
                    else
                        log_warn "DevTools module not loaded"
                    fi
                    ;;
            esac
        done
    fi
    
    # Install individual tools
    if [[ -n "$tools_to_install" ]]; then
        log_info "Installing individual tools: $tools_to_install"
        # Individual tool installation would be handled here
    fi
    
    # Ensure $BIN_DIR is in PATH
    ensure_path "$BIN_DIR"

    # Count installed tools in $BIN_DIR
    local installed_count
    installed_count=$(ls "$BIN_DIR" 2>/dev/null | wc -l)

    # Generate reports
    if ! is_dry_run; then
        generate_final_reports
    fi

    # Post-install message for PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo
        echo "[INFO] Installed tools may not be available until you restart your shell or run:"
        echo "  export PATH=$BIN_DIR:\$PATH"
        echo
    fi

    # Error reporting if no tools installed
    if [[ "$installed_count" -eq 0 ]]; then
        echo
        echo "[ERROR] No tools were installed. Please check configuration, permissions, and network connectivity."
        echo "[ERROR] This will be reported as a failure in the status report."
        # Optionally, touch a failure marker for reporting logic
        echo "No tools installed" > "$SCRIPT_DIR/dev_setup_failure.txt"
    fi
}

execute_check_command() {
    title "InSight Dev Bootstrap - Status Check"
    
    # Check all tool categories
    local categories=("containers" "kubernetes" "hashicorp" "cloud" "devtools")
    
    for category in "${categories[@]}"; do
        if command_exists "${category}_check"; then
            log_debug "Checking category: $category"
            "${category}_check"
        fi
    done
    
    # Display status table
    print_status_table
    print_summary
    
    # Generate reports
    generate_final_reports
}

execute_upgrade_command() {
    title "InSight Dev Bootstrap - Upgrade"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY-RUN MODE: No changes will be made"
    fi
    
    # Upgrade all categories
    local categories=("containers" "kubernetes" "hashicorp" "cloud" "devtools")
    
    for category in "${categories[@]}"; do
        if command_exists "${category}_upgrade"; then
            log_info "Upgrading category: $category"
            "${category}_upgrade"
        fi
    done
    
    # Generate reports
    if ! is_dry_run; then
        generate_final_reports
    fi
}

execute_remove_command() {
    title "InSight Dev Bootstrap - Remove Tools"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY-RUN MODE: No changes will be made"
    fi
    
    log_warn "Tool removal functionality not yet implemented"
    log_info "Use your system package manager to remove tools:"
    
    case "$PKG_MGR" in
        apt) echo "  sudo apt remove <package-name>" ;;
        dnf) echo "  sudo dnf remove <package-name>" ;;
        yum) echo "  sudo yum remove <package-name>" ;;
        zypper) echo "  sudo zypper remove <package-name>" ;;
        pacman) echo "  sudo pacman -R <package-name>" ;;
    esac
}

execute_list_command() {
    title "InSight Dev Bootstrap - Available Tools"
    
    list_available_categories
    echo
    list_available_tools
}

# ---------- Report Generation ----------
generate_final_reports() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    local base_name="dev_setup_status"
    local output_dir="${REPORT_OUTPUT_DIR:-.}"
    
    # Ensure output directory exists
    ensure_directory "$output_dir"
    
    # Generate requested formats
    generate_reports "$output_dir/$base_name" "$OUTPUT_FORMATS"
    
    # Generate compliance report if requested
    if [[ "${GENERATE_COMPLIANCE:-false}" == "true" ]]; then
        generate_compliance_report "$output_dir/compliance_report_${timestamp}.json"
    fi
    
    # Generate security report if security features are enabled
    if [[ "$VERIFY_SIGNATURES" == "true" || "$AUDIT_LOGGING" == "true" ]]; then
        generate_security_report "$output_dir/security_report_${timestamp}.json"
    fi
}

# ---------- Main Execution ----------
main() {
    # Initialize logging
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_message "INFO" "=== $SCRIPT_NAME v$SCRIPT_VERSION started ==="
    fi
    
    # Parse command-line arguments
    parse_arguments "$@"

    # Validate architecture and requirements
    title "System Validation"
    # Initialize distro detection to set DISTRO_NAME and PKG_MGR
    initialize_distro_detection
    echo "OS: $(uname -s) $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Distribution: ${DISTRO_NAME:-unknown}"
    echo "Package Manager: ${PKG_MGR:-unknown}"

    # Detect WSL
    local is_wsl=0
    if grep -qiE "microsoft|wsl" /proc/version; then
        is_wsl=1
    fi

    # Define categories and their tools
    # List all tools and their categories
    declare -A tool_category
    tool_category=(
        [docker]="CONTAINERS"
        [docker-compose]="CONTAINERS"
        [podman]="CONTAINERS"
        [containerd]="CONTAINERS"
        [kubectl]="KUBERNETES"
        [helm]="KUBERNETES"
        [k9s]="KUBERNETES"
        [terraform]="HASHICORP"
        [packer]="HASHICORP"
        [vault]="HASHICORP"
        [consul]="HASHICORP"
        [aws-cli]="CLOUD"
        [gcloud]="CLOUD"
        [azure-cli]="CLOUD"
        [bicep]="CLOUD"
        [powershell]="CLOUD"
        [pyenv]="DEVTOOLS"
        [nvm]="DEVTOOLS"
        [nodejs]="DEVTOOLS"
        [python]="DEVTOOLS"
        [rbenv]="DEVTOOLS"
        [git]="DEVTOOLS"
        [jq]="DEVTOOLS"
        [make]="DEVTOOLS"
        [cmake]="DEVTOOLS"
        [gcc]="DEVTOOLS"
        [clang]="DEVTOOLS"
        [vim]="DEVTOOLS"
        [nano]="DEVTOOLS"
        [curl]="DEVTOOLS"
        [wget]="DEVTOOLS"
        [vscode]="IDE"
        [pycharm]="IDE"
    )

    local all_tools=(docker docker-compose podman containerd kubectl helm k9s terraform packer vault consul aws-cli gcloud azure-cli bicep powershell pyenv nvm nodejs python rbenv git jq make cmake gcc clang vim nano curl wget vscode pycharm)

    echo
    printf "%-15s %-12s %-18s %-18s %-8s %-28s %-s\n" "Tool" "Category" "Installed" "Current Version" "Latest Version" "On PATH" "Path"
    printf "%-15s %-12s %-18s %-18s %-8s %-28s %-s\n" "---------------" "------------" "------------------" "------------------" "--------" "----------------------------" "-----------------------------"
    for tool in "${all_tools[@]}"; do
        local installed="no"
        local current_version="-"
        local latest_version="-"
        local on_path="no"
        local tool_path="-"
        local category="${tool_category[$tool]}"

        # Always show all tools, even if not installed
        if command_exists "$tool"; then
            tool_path="$(where_cmd "$tool")"
            # Filter out Windows executables (mounted drives) in WSL
            if [[ "$is_wsl" -eq 1 && "$tool_path" =~ ^/mnt/[a-zA-Z]/ ]]; then
                installed="no"
                on_path="no"
                tool_path="-"
                current_version="-"
            else
                installed="yes"
                on_path="yes"
                current_version=$(get_local_version "$tool" "--version")
            fi
        fi

        # Get latest version (dynamic fetch)
        case "$tool" in
            docker)
                latest_version=$(curl -s https://api.github.com/repos/moby/moby/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            docker-compose)
                latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            podman)
                latest_version=$(curl -s https://api.github.com/repos/containers/podman/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            containerd)
                latest_version=$(curl -s https://api.github.com/repos/containerd/containerd/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            kubectl)
                latest_version=$(curl -sL https://dl.k8s.io/release/stable.txt 2>/dev/null || true)
                [[ "$latest_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || latest_version="-"
                ;;
            helm)
                latest_version=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep 'tag_name' | head -1 | grep -o 'v[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            k9s)
                latest_version=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            terraform)
                latest_version=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            packer)
                latest_version=$(curl -s https://api.github.com/repos/hashicorp/packer/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            vault)
                latest_version=$(curl -s https://api.github.com/repos/hashicorp/vault/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            consul)
                latest_version=$(curl -s https://api.github.com/repos/hashicorp/consul/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            bicep)
                latest_version=$(curl -s https://api.github.com/repos/Azure/bicep/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            aws-cli)
                latest_version=$(curl -s https://api.github.com/repos/aws/aws-cli/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            gcloud)
                latest_version=$(curl -s https://dl.google.com/dl/cloudsdk/channels/rapid/components-2.json | grep -o '"version": "[0-9.]*"' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            azure-cli)
                latest_version=$(curl -s https://api.github.com/repos/Azure/azure-cli/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            powershell)
                latest_version=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            pyenv)
                latest_version=$(curl -s https://api.github.com/repos/pyenv/pyenv/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            nvm)
                latest_version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            nodejs)
                latest_version=$(curl -s https://api.github.com/repos/nodejs/node/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            python)
                latest_version=$(curl -s https://api.github.com/repos/python/cpython/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            rbenv)
                latest_version=$(curl -s https://api.github.com/repos/rbenv/rbenv/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            git)
                latest_version=$(curl -s https://api.github.com/repos/git/git/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            jq)
                latest_version=$(curl -s https://api.github.com/repos/stedolan/jq/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            make)
                latest_version=$(curl -s https://api.github.com/repos/GNUMake/make/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            cmake)
                latest_version=$(curl -s https://api.github.com/repos/Kitware/CMake/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            gcc)
                latest_version=$(curl -s https://api.github.com/repos/gcc-mirror/gcc/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            clang)
                latest_version=$(curl -s https://api.github.com/repos/llvm/llvm-project/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            vim)
                latest_version=$(curl -s https://api.github.com/repos/vim/vim/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            nano)
                latest_version=$(curl -s https://api.github.com/repos/nanorc/nano/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            curl)
                latest_version=$(curl -s https://api.github.com/repos/curl/curl/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            wget)
                latest_version=$(curl -s https://api.github.com/repos/mirror/wget/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            vscode)
                latest_version=$(curl -s https://api.github.com/repos/microsoft/vscode/releases/latest | grep 'tag_name' | head -1 | grep -o '[0-9.]*' || true)
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            pycharm)
                latest_version=$(curl -s https://data.services.jetbrains.com/products/releases?code=PCP&latest=true&type=release 2>/dev/null | grep -o '"version":"[0-9.]*"' | head -1 | grep -o '[0-9.]*')
                [[ -z "$latest_version" ]] && latest_version="-"
                ;;
            *)
                latest_version="-"
                ;;
        esac

        printf "%-15s %-12s %-18s %-18s %-8s %-28s %-s\n" "$tool" "$category" "$installed" "$current_version" "$latest_version" "$on_path" "$tool_path"
    done

    echo
    log_info "System validation and tool status completed."
}

# ---------- Error Handling ----------
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "Script failed at line $line_number with exit code $exit_code"
    
    # Cleanup on error
    cleanup_temp_files 2>/dev/null || true
    
    exit $exit_code
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# ---------- Script Execution ----------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi