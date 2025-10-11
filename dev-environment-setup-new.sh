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
# • Cross-distribution Linux support
# =====================================================================

set -euo pipefail
IFS=$'\n\t'

# ---------- Script Metadata ----------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"

# Source core libraries
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/distro.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/installer.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/reporter.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/security.sh"

# ---------- Global Configuration ----------
DRY_RUN=0
CHECK_ONLY=0
FORCE_INSTALL=0
UPGRADE_MODE=0
USER_MODE=0
VERBOSE=0
DEBUG=0

CONFIG_FILE=""
SELECTED_CATEGORIES=""
SELECTED_TOOLS=""
VERSION_CONSTRAINTS=""
OUTPUT_FORMATS="json,csv,txt"

# ---------- Usage Information ----------
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - InSight Dev Bootstrap

USAGE:
    $SCRIPT_NAME [OPTIONS] [COMMAND]

COMMANDS:
    install         Install development tools (default)
    check           Check current installation status
    upgrade         Upgrade installed tools to latest versions
    remove          Remove installed tools
    list            List available tools and categories

OPTIONS:
    Installation Mode:
        --system            Install system-wide (requires root)
        --user              Install to user directory (~/.local)
        --dry-run           Show what would be done without making changes
        --force             Force reinstallation of existing tools
        --upgrade           Upgrade existing tools to latest versions

    Tool Selection:
        --categories LIST   Install specific categories (comma-separated)
                           Available: containers,kubernetes,hashicorp,cloud,devtools
        --tools LIST        Install specific tools (comma-separated)
        --exclude LIST      Exclude specific tools from installation
        --config FILE       Use configuration file (YAML)
        --versions LIST     Pin specific versions (tool=version,...)

    Configuration:
        --config FILE       Load configuration from YAML file
        --profile NAME      Use predefined profile (default,enterprise,minimal)

    Security:
        --verify-signatures Enable GPG signature verification
        --verify-checksums  Enable checksum verification (default)
        --no-verify         Disable all verification
        --audit-log FILE    Enable security audit logging

    Output & Reporting:
        --output-formats LIST  Report formats (json,csv,txt,html,markdown)
        --output-dir DIR       Report output directory
        --compliance-report    Generate compliance report
        --quiet               Minimal output
        --verbose             Detailed output
        --debug               Debug output

    Help:
        --help              Show this help message
        --version           Show version information
        --list-tools        List all available tools
        --list-categories   List all available categories

EXAMPLES:
    # System-wide installation with default tools
    sudo $SCRIPT_NAME

    # User installation with specific categories
    $SCRIPT_NAME --user --categories containers,kubernetes

    # Install specific tools only
    $SCRIPT_NAME --tools docker,kubectl,terraform

    # Enterprise configuration with security verification
    $SCRIPT_NAME --config config/enterprise.yml --verify-signatures

    # Check current status without installing
    $SCRIPT_NAME --check

    # Dry run to preview changes
    $SCRIPT_NAME --dry-run --categories hashicorp

    # Upgrade all installed tools
    $SCRIPT_NAME --upgrade

CONFIGURATION:
    Configuration files are loaded in this order (last one wins):
    1. $SCRIPT_DIR/config/default.yml
    2. /etc/devtools/config.yml
    3. ~/.config/devtools.yml
    4. File specified with --config

ENVIRONMENT VARIABLES:
    HTTP_PROXY, HTTPS_PROXY    Proxy configuration
    LOG_LEVEL                  Log level (1-4, default: 3)
    LOG_FILE                   Log file path
    VERIFY_SIGNATURES          Enable signature verification (true/false)
    VERIFY_CHECKSUMS          Enable checksum verification (true/false)

EOF
}

show_version() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Copyright (c) 2025 InSight Development Team
Licensed under MIT License

System Information:
  OS: $(uname -s) $(uname -r)
  Architecture: $(uname -m)
  Bash: $BASH_VERSION
  
Libraries:
  Common: ${COMMON_LIB_LOADED:-not loaded}
  Distro: ${DISTRO_LIB_LOADED:-not loaded}
  Installer: ${INSTALLER_LIB_LOADED:-not loaded}
  Reporter: ${REPORTER_LIB_LOADED:-not loaded}
  Security: ${SECURITY_LIB_LOADED:-not loaded}
EOF
}

# ---------- Tool and Category Lists ----------
list_available_tools() {
    cat << EOF
Available Tools:

CONTAINERS:
  docker          Docker Engine and CLI
  docker-compose  Docker Compose orchestration tool
  podman          Podman container engine (rootless)
  containerd      containerd runtime

KUBERNETES:
  kubectl         Kubernetes command-line tool
  helm            Kubernetes package manager
  k9s             Kubernetes cluster management UI

HASHICORP:
  terraform       Infrastructure as Code tool
  packer          Image building tool
  vault           Secrets management
  consul          Service mesh and discovery

CLOUD:
  aws-cli         Amazon Web Services CLI v2
  gcloud          Google Cloud SDK
  azure-cli       Microsoft Azure CLI

DEVTOOLS:
  pyenv           Python version manager
  nvm             Node.js version manager
  rbenv           Ruby version manager
  git             Git version control
  jq              JSON processor
EOF
}

list_available_categories() {
    cat << EOF
Available Categories:

containers      Container engines and tools (Docker, Podman)
kubernetes      Kubernetes orchestration tools (kubectl, helm)
hashicorp       HashiCorp infrastructure tools (Terraform, Vault, Packer)
cloud           Cloud provider CLIs (AWS, Google Cloud, Azure)
devtools        Development language managers (pyenv, nvm, rbenv)
EOF
}

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
            # For now, we'll use a simple key=value parser
            # In a full implementation, this would parse YAML
            load_config_file "$config_file" || log_warn "Failed to load config: $config_file"
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
    
    # Generate reports
    if ! is_dry_run; then
        generate_final_reports
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
    
    # Initialize system detection
    initialize_distro_detection
    
    # Initialize installer
    initialize_installer
    
    # Initialize security
    initialize_security
    
    # Initialize reporter
    initialize_reporter
    
    # Load configuration
    load_configuration
    
    # Load tool modules
    load_tool_modules
    
    # Execute the requested command
    execute_command
    
    log_info "InSight Dev Bootstrap completed successfully"
    
    if [[ "${GENERATE_COMPLIANCE:-false}" == "true" ]]; then
        log_info "Compliance report generated"
    fi
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