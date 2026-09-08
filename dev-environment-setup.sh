#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap v1.1.0
# Enterprise-ready development environment setup for Linux
#
# Features:
# • Modular architecture with pluggable tool modules
# • Dry-run and check-only modes
# • Selective installation by category or individual tools
# • Configuration-driven setup with YAML support
# • Enhanced security with signature verification
# • Comprehensive reporting and compliance features
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_VERSION="1.1.0"

# Source core libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/distro.sh"
source "$SCRIPT_DIR/lib/installer.sh"
source "$SCRIPT_DIR/lib/reporter.sh"
source "$SCRIPT_DIR/lib/security.sh"
source "$SCRIPT_DIR/lib/versioncheck.sh"

# ---------- Default Configuration (nounset-safe) ----------
DRY_RUN=0
CHECK_ONLY=0
FORCE_INSTALL=0
UPGRADE_MODE=0
USER_MODE=0
VERBOSE=0
DEBUG=0
FORCE_LATEST=0
SELECTED_CATEGORIES=""
SELECTED_TOOLS=""
EXCLUDE_TOOLS=""
VERSION_CONSTRAINTS=""
CONFIG_FILE=""
VERIFY_SIGNATURES="false"
VERIFY_CHECKSUMS="false"
AUDIT_LOGGING="false"
SECURITY_LOG_FILE=""
OUTPUT_FORMATS="txt"
REPORT_OUTPUT_DIR="."
GENERATE_COMPLIANCE="false"

# Canonical tool -> category map, used for individual --tools selection
declare -A TOOL_CATEGORY=(
    [docker]="containers" [docker-compose]="containers" [podman]="containers" [containerd]="containers"
    [kubectl]="kubernetes" [helm]="kubernetes" [k9s]="kubernetes"
    [terraform]="hashicorp" [packer]="hashicorp" [vault]="hashicorp" [consul]="hashicorp"
    [aws-cli]="cloud" [gcloud]="cloud" [azure-cli]="cloud" [bicep]="cloud"
    [pyenv]="devtools" [nvm]="devtools" [rbenv]="devtools" [git]="devtools" [jq]="devtools" [powershell]="devtools"
)
readonly SUPPORTED_CATEGORIES=(containers kubernetes hashicorp cloud devtools)

# ---------- Help / Info ----------
show_usage() {
    cat <<EOF
$SCRIPT_NAME v$SCRIPT_VERSION - InSight Dev Bootstrap

Usage: $SCRIPT_NAME <command> [options]

Commands:
  install       Install selected tools (default)
  check         Report installed/available versions without changing anything
  upgrade       Upgrade installed tools to their latest version
  remove        Show how to remove installed tools
  list          List supported categories and tools

Installation mode:
  --system                 Install system-wide (requires root)
  --user                   Install to \$HOME/.local/bin
  --dry-run                Preview actions without making changes
  --force                  Reinstall even if already present
  --upgrade                Upgrade instead of fresh-install

Tool selection:
  --categories <list>      Comma-separated categories (e.g. containers,cloud)
  --tools <list>            Comma-separated individual tools (e.g. docker,kubectl)
  --exclude <list>          Comma-separated tools to skip
  --versions <list>         Version pins, e.g. terraform=1.5.0,kubectl=1.27.0

Configuration:
  --config <file>           Path to a YAML config file
  --profile <name>          Use config/<name>.yml

Security:
  --verify-signatures       Enable GPG signature verification
  --verify-checksums        Enable checksum validation
  --no-verify               Disable both of the above
  --audit-log <file>        Enable audit logging to <file>

Output:
  --output-formats <list>   csv,json,txt,html,markdown
  --output-dir <dir>        Directory for generated reports
  --compliance-report       Also generate a compliance report
  --force-latest            Bypass the cached latest-version lookups

Other:
  --quiet | --verbose | --debug
  --list-tools | --list-categories
  --help, -h                Show this help
  --version, -v             Show version information

Examples:
  $SCRIPT_NAME check
  $SCRIPT_NAME install --dry-run
  $SCRIPT_NAME install --user --categories containers,cloud
  $SCRIPT_NAME install --tools docker,kubectl,terraform
EOF
}

show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

list_available_categories() {
    title "Available Categories"
    for category in "${SUPPORTED_CATEGORIES[@]}"; do
        echo "  - $category"
    done
}

list_available_tools() {
    title "Available Tools"
    local tool
    for tool in "${!TOOL_CATEGORY[@]}"; do
        printf "  %-15s (%s)\n" "$tool" "${TOOL_CATEGORY[$tool]}"
    done | sort
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
                die $EXIT_INVALID_ARGS "Unknown argument: $1"
                ;;
        esac
    done
    # Export command for use by other functions
    export COMMAND="$command"
    export DRY_RUN CHECK_ONLY FORCE_INSTALL UPGRADE_MODE USER_MODE VERBOSE DEBUG FORCE_LATEST
    export SELECTED_CATEGORIES SELECTED_TOOLS EXCLUDE_TOOLS VERSION_CONSTRAINTS OUTPUT_FORMATS
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
            while IFS=: read -r key value; do
                export "CONFIG_${key}=${value}"
            done < <(awk '/^[ ]*[a-zA-Z0-9_-]+:[ ]*(true|auto)/ {gsub(/:/,"",$0); gsub(/[ \t]+/," ",$0); split($0,a," "); key=a[1]; value=a[2]; gsub("-","_",key); print key ":" value}' "$config_file")
        else
            log_debug "Config file not found: $config_file"
        fi
    done
}

# ---------- Module Loading ----------
load_tool_modules() {
    local modules=(containers kubernetes hashicorp cloud devtools)

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

# ---------- Category / Tool Selection Helpers ----------
# Build the comma-separated tool list for one category, honoring the YAML
# config's true/auto flags and any --exclude list from the CLI.
_tools_for_category() {
    local category="$1"
    local tool tool_list=""

    for tool in "${!TOOL_CATEGORY[@]}"; do
        [[ "${TOOL_CATEGORY[$tool]}" == "$category" ]] || continue

        local config_key="CONFIG_${tool//-/_}"
        if [[ "${!config_key:-}" == "true" || "${!config_key:-}" == "auto" ]]; then
            if [[ ",${EXCLUDE_TOOLS}," == *",${tool},"* ]]; then
                continue
            fi
            tool_list+="${tool},"
        fi
    done
    echo "${tool_list%,}"
}

# Remove duplicate entries from a comma-separated tool list, preserving
# first-seen order (a tool may appear once from category expansion and again
# from an explicit --tools request).
_dedupe_tool_list() {
    local list="${1%,}"
    local tool seen="," result=""
    IFS=',' read -ra all_tools <<< "$list"
    for tool in "${all_tools[@]}"; do
        [[ -z "$tool" ]] && continue
        [[ "$seen" == *",${tool},"* ]] && continue
        seen+="${tool},"
        result+="${tool},"
    done
    echo "${result%,}"
}

# Dispatch an install call to the right module for one category.
_install_category() {
    local category="$1"
    local tool_list="$2"
    [[ -z "$tool_list" ]] && return 0

    local installer_fn=""
    case "$category" in
        containers) installer_fn="containers_install" ;;
        kubernetes) installer_fn="install_kubernetes_tools" ;;
        hashicorp)  installer_fn="install_hashicorp_tools" ;;
        cloud)      installer_fn="install_cloud_tools" ;;
        devtools)   installer_fn="install_devtools" ;;
        *)
            log_warn "Unknown category: $category"
            return 0
            ;;
    esac

    if ! command_exists "$installer_fn"; then
        log_warn "${category^} module not loaded"
        return 0
    fi

    # Calling the installer from a tested (if !) context suspends `set -e`
    # for its entire execution (this is documented bash behavior, not a bug):
    # a failure on one tool inside the loop no longer aborts the whole
    # script, it just falls through to that module's own verification code,
    # which already records the failure via add_tool_result. This is what
    # makes a failed docker install, say, not also take out kubernetes,
    # hashicorp, cloud, and devtools installs that were queued after it.
    if ! "$installer_fn" "$tool_list"; then
        log_error "One or more tools in category '$category' failed to install; continuing with remaining categories"
    fi
}

# ---------- Command Execution ----------
execute_command() {
    case "$COMMAND" in
        install) execute_install_command ;;
        check)   execute_check_command ;;
        upgrade) execute_upgrade_command ;;
        remove)  execute_remove_command ;;
        list)    execute_list_command ;;
        *)       die $EXIT_INVALID_ARGS "Unknown command: $COMMAND" ;;
    esac
}

execute_install_command() {
    title "InSight Dev Bootstrap - Installation"

    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY-RUN MODE: No changes will be made"
    fi

    # Put $BIN_DIR on PATH (and persist it) *before* installing anything, so
    # that verification lookups for tools installed this run (e.g. kubectl
    # right after it's dropped into $BIN_DIR) can actually find them, and so
    # a plain `check` run afterwards sees them too.
    ensure_path "$BIN_DIR"

    if ! is_dry_run; then
        log_info "Installing baseline system packages"
        install_baseline_packages
    fi

    # Build the set of tools to install as the UNION of:
    #   - every tool enabled (true/auto) in the selected (or default)
    #     categories, and
    #   - any individually-named --tools, which are installed even if not
    #     enabled in the config (an explicit request overrides config gating,
    #     matching config/default.yml's own documented precedence).
    # Both may be given together, e.g. --categories containers --tools terraform.
    declare -A tools_by_category=()

    if [[ -n "$SELECTED_CATEGORIES" || -z "$SELECTED_TOOLS" ]]; then
        local categories_to_install="${SELECTED_CATEGORIES:-containers,kubernetes,hashicorp,cloud,devtools}"
        IFS=',' read -ra category_array <<< "$categories_to_install"
        for category in "${category_array[@]}"; do
            category=$(trim "$category")
            local category_tools
            category_tools="$(_tools_for_category "$category")"
            [[ -n "$category_tools" ]] && tools_by_category[$category]+="${category_tools},"
        done
    fi

    if [[ -n "$SELECTED_TOOLS" ]]; then
        log_info "Also installing individually requested tools: $SELECTED_TOOLS"
        IFS=',' read -ra requested_tools <<< "$SELECTED_TOOLS"
        for tool in "${requested_tools[@]}"; do
            tool=$(trim "$tool")
            local category="${TOOL_CATEGORY[$tool]:-}"
            if [[ -z "$category" ]]; then
                log_warn "Unknown tool: $tool"
                continue
            fi
            tools_by_category[$category]+="${tool},"
        done
    fi

    local category
    for category in "${!tools_by_category[@]}"; do
        log_info "Installing category: $category"
        _install_category "$category" "$(_dedupe_tool_list "${tools_by_category[$category]}")"
    done

    print_status_table
    print_summary

    if ! is_dry_run; then
        generate_final_reports
    fi

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo
        echo "[INFO] Installed tools may not be available until you restart your shell or run:"
        echo "  export PATH=$BIN_DIR:\$PATH"
        echo
    fi
}

execute_check_command() {
    title "InSight Dev Bootstrap - Status Check"

    local category
    for category in "${SUPPORTED_CATEGORIES[@]}"; do
        if command_exists "${category}_check"; then
            log_debug "Checking category: $category"
            "${category}_check"
        else
            log_warn "No check function for category: $category"
        fi
    done

    print_status_table
    print_summary
    generate_final_reports
}

execute_upgrade_command() {
    title "InSight Dev Bootstrap - Upgrade"

    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY-RUN MODE: No changes will be made"
    fi

    ensure_path "$BIN_DIR"

    local category
    for category in "${SUPPORTED_CATEGORIES[@]}"; do
        if command_exists "${category}_upgrade"; then
            log_info "Upgrading category: $category"
            "${category}_upgrade"
        fi
    done

    print_status_table
    print_summary

    if ! is_dry_run; then
        generate_final_reports
    fi
}

execute_remove_command() {
    title "InSight Dev Bootstrap - Remove Tools"

    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY-RUN MODE: No changes will be made"
    fi

    if [[ -n "$SELECTED_TOOLS" ]] && command_exists containers_remove; then
        containers_remove "$SELECTED_TOOLS"
    fi

    log_warn "Tool removal functionality is limited today"
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

    ensure_directory "$output_dir"
    generate_reports "$output_dir/$base_name" "$OUTPUT_FORMATS"

    if [[ "${GENERATE_COMPLIANCE:-false}" == "true" ]]; then
        generate_compliance_report "$output_dir/compliance_report_${timestamp}.json"
    fi

    if [[ "$VERIFY_SIGNATURES" == "true" || "$AUDIT_LOGGING" == "true" ]]; then
        generate_security_report "$output_dir/security_report_${timestamp}.json"
    fi
}

# ---------- Error Handling ----------
handle_error() {
    local exit_code=$?
    local line_number=$1

    log_error "Script failed at line $line_number with exit code $exit_code"
    cleanup_temp_files 2>/dev/null || true
    exit $exit_code
}
trap 'handle_error $LINENO' ERR

# ---------- Main Execution ----------
main() {
    parse_arguments "$@"

    if [[ -n "${LOG_FILE:-}" ]]; then
        log_message "INFO" "=== $SCRIPT_NAME v$SCRIPT_VERSION started (command=$COMMAND) ==="
    fi

    title "System Validation"
    initialize_distro_detection
    initialize_installer
    initialize_reporter
    initialize_security
    echo "OS: $(uname -s) $(uname -r)"
    echo "Architecture: $(detect_architecture)"
    echo "Distribution: ${DISTRO_ID:-unknown} ${DISTRO_VERSION:-}"
    echo "Package Manager: ${PKG_MGR:-unknown}"
    echo "Install mode: $INSTALL_MODE ($BIN_DIR)"

    # Make sure tools from a previous run (sitting in $BIN_DIR) are visible
    # to this process even if the current shell's PATH predates them. This
    # does not touch .bashrc/profile.d; install/upgrade do that separately
    # via ensure_path.
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) export PATH="$BIN_DIR:$PATH" ;;
    esac

    load_configuration
    load_tool_modules
    clear_results

    execute_command
}

# ---------- Script Execution ----------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
