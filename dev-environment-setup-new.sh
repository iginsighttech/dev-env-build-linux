# Enterprise-ready development environment setup for Linux
# =====================================================================

export DEBUG=${DEBUG:-0}
export LOG_LEVEL=${LOG_LEVEL:-3}
# Source core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/distro.sh"
source "$SCRIPT_DIR/lib/reporter.sh"
source "$SCRIPT_DIR/lib/installer.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/main.sh"

# Load modules
for module in containers kubernetes hashicorp cloud devtools versioncheck; do
    module_file="$SCRIPT_DIR/modules/${module}.sh"
    [[ -r "$module_file" ]] && source "$module_file"
done

# Argument parsing
parse_arguments() {
    local command="install"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            install|check|upgrade|remove|list)
                command="$1"
                shift
                ;;
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
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --profile)
                CONFIG_FILE="$SCRIPT_DIR/config/$2.yml"
                shift 2
                ;;
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
            *)
                shift
                ;;
        esac
    done
    export COMMAND="$command"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    cleanup_temp_files 2>/dev/null || true
    exit $exit_code
}
trap 'handle_error $LINENO' ERR

# Entrypoint
main() {
    parse_arguments "$@"
    load_configuration
    run_main_logic "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap v1.0.0
# Enterprise-ready development environment setup for Linux
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


            # Tool selection
# ...existing code...
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
        esac
    done



            # Source core libraries
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            source "$SCRIPT_DIR/lib/common.sh"
            source "$SCRIPT_DIR/lib/distro.sh"
            source "$SCRIPT_DIR/lib/reporter.sh"
            source "$SCRIPT_DIR/lib/installer.sh"
            # Source orchestration logic
            source "$SCRIPT_DIR/lib/main.sh"
            # Load modules
            for module in containers kubernetes hashicorp cloud devtools; do
                module_file="$SCRIPT_DIR/modules/${module}.sh"
                [[ -r "$module_file" ]] && source "$module_file"
            done

            # Parse arguments and config
            parse_arguments "$@"
            load_configuration

            # Main orchestration

            main() {
                run_main_logic "$@"
            }

            # Entrypoint
            if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
                main "$@"
            fi
}