#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Common Library Functions
# Shared utilities used across all modules
# =====================================================================

# Prevent multiple inclusion
[[ "${COMMON_LIB_LOADED:-}" == "true" ]] && return 0
readonly COMMON_LIB_LOADED="true"

readonly CONFIG_DIR="${BASH_SOURCE[0]%/*}/../config"
readonly MODULES_DIR="${BASH_SOURCE[0]%/*}/../modules"
readonly DEFAULT_TIMEOUT=15
readonly MAX_RETRIES=3

# ---------- Color Output Functions ----------
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    readonly COLOR_CYAN=$(tput setaf 6)
    readonly COLOR_GREEN=$(tput setaf 2)  
    readonly COLOR_YELLOW=$(tput setaf 3)
    readonly COLOR_RED=$(tput setaf 1)
    readonly COLOR_BLUE=$(tput setaf 4)
    readonly COLOR_BOLD=$(tput bold)
    readonly COLOR_RESET=$(tput sgr0)
else
    readonly COLOR_CYAN=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_RED=""
    readonly COLOR_BLUE=""
    readonly COLOR_BOLD=""
    readonly COLOR_RESET=""
fi

# UI Functions
cyan()  { printf "%s%s%s\n" "$COLOR_CYAN" "$*" "$COLOR_RESET"; }
green() { printf "%s%s%s\n" "$COLOR_GREEN" "$*" "$COLOR_RESET"; }
yellow(){ printf "%s%s%s\n" "$COLOR_YELLOW" "$*" "$COLOR_RESET"; }
red()   { printf "%s%s%s\n" "$COLOR_RED" "$*" "$COLOR_RESET"; }
blue()  { printf "%s%s%s\n" "$COLOR_BLUE" "$*" "$COLOR_RESET"; }
bold()  { printf "%s%s%s\n" "$COLOR_BOLD" "$*" "$COLOR_RESET"; }

title() { echo; cyan "=== $* ==="; }
info()  { green "[INFO] $*"; }
warn()  { yellow "[WARN] $*"; }
error() { red "[ERROR] $*"; }
debug() { [[ "${DEBUG:-0}" == "1" ]] && blue "[DEBUG] $*" || true; }

# ---------- Logging Functions ----------
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2  
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4

LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}
LOG_FILE="${LOG_FILE:-}"

log_message() {
    local level="$1" 
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "$LOG_FILE" ]]; then
        printf "%s [%s] %s\n" "$timestamp" "$level" "$message" >> "$LOG_FILE"
    fi
}

log_error() { 
    [[ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ]] && error "$*"
    log_message "ERROR" "$*"
}

log_warn() { 
    [[ $LOG_LEVEL -ge $LOG_LEVEL_WARN ]] && warn "$*"
    log_message "WARN" "$*"
}

log_info() { 
    [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]] && info "$*"
    log_message "INFO" "$*"
}

log_debug() { 
    [[ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]] && debug "$*"
    log_message "DEBUG" "$*"
}

# ---------- Error Handling ----------
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_PERMISSION=2  
readonly EXIT_NETWORK=3
readonly EXIT_VERIFICATION=4
readonly EXIT_INSTALLATION=5
readonly EXIT_CONFIGURATION=6

die() {
    local exit_code=${1:-1}
    shift
    log_error "$*"
    exit "$exit_code"
}

# ---------- Utility Functions ----------
is_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

is_user_mode() {
    [[ "${USER_MODE:-0}" == "1" ]]
}

# The non-root human user who ran `sudo`, if any. Empty when not running
# under sudo (e.g. a genuine root login), since there's then no other
# account to fall back to for user-scoped tools.
sudo_invoking_user() {
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"
    fi
}

# Home directory for a given user account.
user_home_dir() {
    getent passwd "$1" 2>/dev/null | cut -d: -f6
}

# Runs a single command string as another user's login shell (so $HOME,
# profile files, etc. are that user's own). Only works when the caller is
# already root, which is always true wherever this is used.
run_as_user() {
    local user="$1"
    local cmd="$2"
    runuser -l "$user" -c "$cmd"
}

is_dry_run() {
    [[ "${DRY_RUN:-0}" == "1" ]]
}

is_check_only() {
    [[ "${CHECK_ONLY:-0}" == "1" ]]
}

# Command existence check
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Where-like resolver  
where_cmd() {
    local name="$1"
    command -v "$name" 2>/dev/null || true
}

# Version capture with timeout
run_with_timeout() {
    local timeout_sec="${1:-$DEFAULT_TIMEOUT}"
    local cmd="$2"
    shift 2
    
    # stdin is redirected from /dev/null so a tool that prompts on first run
    # (e.g. gcloud's survey opt-in) gets EOF instead of blocking on our TTY
    # until the timeout kills it and swallows its version output.
    if command_exists timeout; then
        timeout "$timeout_sec" "$cmd" "$@" < /dev/null 2>/dev/null || true
    else
        # Fallback for systems without timeout command
        "$cmd" "$@" < /dev/null 2>/dev/null || true
    fi
}

# Extract version from command output
get_version_from_output() {
    local output="$1"
    local regex="${2:-'[0-9]+(\.[0-9]+)+'}"
    
    if [[ "$output" =~ $regex ]]; then
        echo "${BASH_REMATCH[0]}"
    else
        echo ""
    fi
}

# Get local version of installed tool
get_local_version() {
    local cmd="$1"
    local args="$2"
    local regex="${3:-[0-9]+(\.[0-9]+)+}"
    local path

    path=$(where_cmd "$cmd")
    if [[ -z "$path" ]]; then
        echo ""
        return 0
    fi

    # Split on spaces explicitly rather than relying on unquoted-expansion
    # word-splitting: initialize_common() sets IFS=$'\n\t' (no space) for the
    # rest of the script, which would otherwise leave a multi-word args
    # string like "version --client" as a single argument.
    local -a args_array
    IFS=' ' read -ra args_array <<< "$args"

    local output
    output=$(run_with_timeout "$DEFAULT_TIMEOUT" "$path" "${args_array[@]}")
    get_version_from_output "$output" "$regex"
}

# ---------- Network Functions ----------
download_file() {
    local url="$1"
    local output_file="$2"
    local retries="${3:-$MAX_RETRIES}"
    
    log_debug "Downloading: $url -> $output_file"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would download $url"
        return 0
    fi
    
    local attempt=1
    while [[ $attempt -le $retries ]]; do
        if curl -fsSL --retry 3 --retry-delay 1 \
               -H 'User-Agent: InSight-DevBootstrap/1.0' \
               -o "$output_file" "$url"; then
            log_debug "Download successful on attempt $attempt"
            return 0
        fi
        
        log_warn "Download attempt $attempt failed for $url"
        attempt=$((attempt + 1))
        [[ $attempt -le $retries ]] && sleep $((attempt * 2))
    done
    
    log_error "Failed to download $url after $retries attempts"
    return 1
}

# ---------- File System Functions ----------
ensure_directory() {
    local dir="$1"
    local mode="${2:-755}"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would create directory $dir"
        return 0
    fi
    
    if [[ ! -d "$dir" ]]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir" || die $EXIT_INSTALLATION "Failed to create directory: $dir"
        chmod "$mode" "$dir" 2>/dev/null || true
    fi
}

install_binary() {
    local src="$1"
    local dst="$2"
    local mode="${3:-755}"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would install $src -> $dst"
        return 0
    fi
    
    log_debug "Installing binary: $src -> $dst"
    install -m "$mode" "$src" "$dst" || \
        die $EXIT_INSTALLATION "Failed to install binary: $src -> $dst"
}

# ---------- String Functions ----------
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

trim() {
    local var="$*"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace  
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Join array elements with delimiter
join_by() {
    local delimiter="$1"
    shift
    local first="$1"
    shift
    printf '%s' "$first" "${@/#/$delimiter}"
}

# ---------- Version Comparison ----------
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Remove 'v' prefix if present
    version1="${version1#v}"
    version2="${version2#v}"
    
    # Simple version comparison using sort -V
    if [[ "$version1" == "$version2" ]]; then
        echo "0"  # Equal
    elif printf '%s\n%s\n' "$version1" "$version2" | sort -V -C 2>/dev/null; then
        echo "-1" # version1 < version2
    else
        echo "1"  # version1 > version2
    fi
}

is_version_newer() {
    local current="$1"
    local latest="$2"
    [[ $(version_compare "$current" "$latest") -lt 0 ]]
}

# ---------- Configuration Functions ----------
load_config_file() {
    local config_file="$1"
    
    if [[ ! -r "$config_file" ]]; then
        log_warn "Configuration file not readable: $config_file"
        return 1
    fi
    
    log_debug "Loading configuration: $config_file"
        parse_yaml_config "$config_file"
    }

    parse_yaml_config() {
        local yaml_file="$1"
        # Only process lines with key: value, ignore comments and lists
        grep -E '^[a-zA-Z_][a-zA-Z0-9_]*:' "$yaml_file" | \
        sed -E 's/#.*$//' | \
        while IFS=: read -r key value; do
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            # Only export if key is a valid bash identifier
            if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                export "CONFIG_${key}=${value}"
            fi
        done
    }

    # Usage example (replace old config loading logic):
    # parse_yaml_config "$CONFIG_FILE"

# ---------- Cleanup Functions ----------
cleanup_temp_files() {
    if [[ -n "${TEMP_FILES:-}" ]]; then
        log_debug "Cleaning up temporary files"
        # shellcheck disable=SC2086
        rm -f $TEMP_FILES 2>/dev/null || true
    fi
}

# Set up signal handlers for cleanup
trap cleanup_temp_files EXIT
trap 'die $EXIT_INSTALLATION "Interrupted by user"' INT TERM

# ---------- Validation Functions ----------
validate_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]]
}

validate_file_hash() {
    local file="$1"
    local expected_hash="$2"
    local algorithm="${3:-sha256}"
    
    if ! command_exists "${algorithm}sum"; then
        log_warn "Hash validation skipped: ${algorithm}sum not available"
        return 0
    fi
    
    local actual_hash
    actual_hash=$("${algorithm}sum" "$file" | cut -d' ' -f1)
    
    if [[ "$actual_hash" == "$expected_hash" ]]; then
        log_debug "Hash validation successful: $file"
        return 0
    else
        log_error "Hash mismatch for $file: expected $expected_hash, got $actual_hash"
        return 1
    fi
}

# ---------- Progress Functions ----------
show_progress() {
    local current="$1"
    local total="$2" 
    local message="${3:-Processing}"
    
    if [[ -t 1 ]]; then
        local percent=$((current * 100 / total))
        printf "\r%s: %d%% (%d/%d)" "$message" "$percent" "$current" "$total"
        [[ $current -eq $total ]] && echo
    fi
}

# ---------- Module Loading ----------
load_module() {
    local module_name="$1"
    local module_file="$MODULES_DIR/${module_name}.sh"
    
    if [[ -r "$module_file" ]]; then
        log_debug "Loading module: $module_name"
        # shellcheck disable=SC1090
        source "$module_file"
    else
        die $EXIT_CONFIGURATION "Module not found: $module_name"
    fi
}

# ---------- Initialization ----------
initialize_common() {
    # Set up error handling
    set -euo pipefail
    IFS=$'\n\t'
    
    # Initialize logging if LOG_FILE is set
    if [[ -n "${LOG_FILE:-}" ]]; then
        ensure_directory "$(dirname "$LOG_FILE")"
        log_message "INFO" "=== $SCRIPT_NAME v$SCRIPT_VERSION started ==="
    fi
    
    log_debug "Common library initialized"
}

# Auto-initialize when sourced
initialize_common