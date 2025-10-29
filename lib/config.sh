#!/usr/bin/env bash
# Config parsing and environment setup

parse_arguments() {
    local command="install"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            install|check|upgrade|remove|list)
                command="$1"
                shift
                ;;
            --categories|--tools|--exclude|--versions|--config|--profile|--audit-log|--output-formats|--output-dir)
                opt="$1"
                val="$2"
                if [[ -z "$val" || "$val" == --* ]]; then
                    die $EXIT_INVALID_ARGS "Missing value for $opt"
                fi
                case "$opt" in
                    --categories) SELECTED_CATEGORIES="$val" ;;
                    --tools) SELECTED_TOOLS="$val" ;;
                    --exclude) EXCLUDE_TOOLS="$val" ;;
                    --versions) VERSION_CONSTRAINTS="$val" ;;
                    --config) CONFIG_FILE="$val" ;;
                    --profile) CONFIG_FILE="$SCRIPT_DIR/config/$val.yml" ;;
                    --audit-log) AUDIT_LOGGING="true"; SECURITY_LOG_FILE="$val" ;;
                    --output-formats) OUTPUT_FORMATS="$val" ;;
                    --output-dir) REPORT_OUTPUT_DIR="$val" ;;
                esac
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
            --force-latest)
                FORCE_LATEST=1
                shift
                ;;
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
            --*)
                die $EXIT_INVALID_ARGS "Unknown option: $1"
                ;;
            *)
                if [[ "$command" == "install" && "$1" != "install" ]]; then
                    command="$1"
                else
                    die $EXIT_INVALID_ARGS "Unknown argument: $1"
                fi
                shift
                ;;
        esac
    done
    export COMMAND="$command"
    export DRY_RUN CHECK_ONLY FORCE_INSTALL UPGRADE_MODE USER_MODE VERBOSE DEBUG
    export SELECTED_CATEGORIES SELECTED_TOOLS VERSION_CONSTRAINTS OUTPUT_FORMATS
}

load_configuration() {
    : "${CONFIG_FILE:=$SCRIPT_DIR/config/default.yml}"
    local config_files=(
        "$SCRIPT_DIR/config/default.yml"
        "/etc/devtools/config.yml"
        "$HOME/.config/devtools.yml"
    )
    if [[ -n "$CONFIG_FILE" ]]; then
        config_files+=("$CONFIG_FILE")
    fi
    log_info "Loading configuration files..."
    for config_file in "${config_files[@]}"; do
        if [[ -r "$config_file" ]]; then
            log_debug "Loading config: $config_file"
            log_debug "Starting config parsing for $config_file"
            while IFS=: read -r key value; do
                log_debug "Parsed config: $key = $value"
                export CONFIG_${key}="$value"
            done < <(awk '/^[ ]*[a-zA-Z0-9_-]+:[ ]*(true|auto)/ {gsub(/:/,"",$0); gsub(/[ \t]+/," ",$0); split($0,a," "); key=a[1]; value=a[2]; gsub("-","_",key); print key ":" value}' "$config_file")
            log_debug "Finished config parsing for $config_file"
        else
            log_debug "Config file not found: $config_file"
        fi
    done
}
