#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Security Library
# Cryptographic verification and security audit functions
# =====================================================================

# Prevent multiple inclusion
[[ "${SECURITY_LIB_LOADED:-}" == "true" ]] && return 0
readonly SECURITY_LIB_LOADED="true"

# Source required libraries
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/common.sh"

# ---------- Security Configuration ----------
VERIFY_SIGNATURES="${VERIFY_SIGNATURES:-false}"
VERIFY_CHECKSUMS="${VERIFY_CHECKSUMS:-true}"
AUDIT_LOGGING="${AUDIT_LOGGING:-false}"
SECURITY_LOG_FILE="${SECURITY_LOG_FILE:-}"

# Trusted key servers
readonly GPG_KEYSERVERS=(
    "keyserver.ubuntu.com"
    "pgp.mit.edu"
    "keys.openpgp.org"
)

# ---------- GPG Functions ----------
ensure_gpg_keyring() {
    local keyring_dir="${HOME}/.gnupg"
    
    if [[ ! -d "$keyring_dir" ]]; then
        log_debug "Creating GPG keyring directory"
        mkdir -p "$keyring_dir"
        chmod 700 "$keyring_dir"
    fi
    
    # Initialize GPG if needed
    if ! gpg --list-keys >/dev/null 2>&1; then
        log_debug "Initializing GPG keyring"
        gpg --batch --generate-key << 'EOF' 2>/dev/null || true
%echo Generating temporary key for signature verification
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: DevBootstrap Temp
Name-Email: temp@devbootstrap.local
Expire-Date: 1d
%no-protection
%commit
%echo Done
EOF
    fi
}

import_gpg_key() {
    local key_id="$1"
    local key_file="${2:-}"
    
    ensure_gpg_keyring
    
    if [[ -n "$key_file" && -r "$key_file" ]]; then
        log_debug "Importing GPG key from file: $key_file"
        if gpg --import "$key_file" 2>/dev/null; then
            log_debug "Successfully imported key from file"
            return 0
        else
            log_warn "Failed to import key from file: $key_file"
        fi
    fi
    
    # Try to import from keyservers
    log_debug "Importing GPG key: $key_id"
    
    for keyserver in "${GPG_KEYSERVERS[@]}"; do
        log_debug "Trying keyserver: $keyserver"
        
        if gpg --keyserver "$keyserver" --recv-keys "$key_id" 2>/dev/null; then
            log_debug "Successfully imported key $key_id from $keyserver"
            return 0
        fi
        
        # Small delay between attempts
        sleep 1
    done
    
    log_warn "Failed to import GPG key: $key_id"
    return 1
}

verify_gpg_signature() {
    local file="$1"
    local signature_file="$2"
    local expected_key_id="${3:-}"
    
    if [[ "$VERIFY_SIGNATURES" != "true" ]]; then
        log_debug "Signature verification disabled"
        return 0
    fi
    
    if ! command_exists gpg; then
        log_warn "GPG not available, skipping signature verification"
        return 0
    fi
    
    if [[ ! -f "$signature_file" ]]; then
        log_warn "Signature file not found: $signature_file"
        return 1
    fi
    
    log_debug "Verifying GPG signature: $file"
    
    ensure_gpg_keyring
    
    local verify_output
    if verify_output=$(gpg --verify "$signature_file" "$file" 2>&1); then
        log_debug "Signature verification successful"
        
        # Check if specific key ID was expected
        if [[ -n "$expected_key_id" ]]; then
            if echo "$verify_output" | grep -q "$expected_key_id"; then
                log_debug "Signature matches expected key ID: $expected_key_id"
            else
                log_warn "Signature key ID mismatch (expected: $expected_key_id)"
                security_audit_log "signature_key_mismatch" "$file" "$expected_key_id"
                return 1
            fi
        fi
        
        security_audit_log "signature_verified" "$file" "success"
        return 0
    else
        log_error "Signature verification failed: $file"
        log_debug "GPG output: $verify_output"
        security_audit_log "signature_verification_failed" "$file" "failed"
        return 1
    fi
}

download_signature_file() {
    local file_url="$1"
    local signature_url="$2"
    local output_dir="$3"
    
    local file_name
    file_name=$(basename "$file_url")
    local sig_name
    sig_name=$(basename "$signature_url")
    
    local file_path="$output_dir/$file_name"
    local sig_path="$output_dir/$sig_name"
    
    # Download main file
    if ! download_file "$file_url" "$file_path"; then
        return 1
    fi
    
    # Download signature
    if ! download_file "$signature_url" "$sig_path"; then
        log_warn "Failed to download signature file: $signature_url"
        return 1
    fi
    
    echo "$file_path:$sig_path"
}

# ---------- Checksum Functions ----------
calculate_checksum() {
    local file="$1"
    local algorithm="${2:-sha256}"
    
    if ! command_exists "${algorithm}sum"; then
        log_warn "Checksum utility not available: ${algorithm}sum"
        return 1
    fi
    
    "${algorithm}sum" "$file" | cut -d' ' -f1
}

verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    
    if [[ "$VERIFY_CHECKSUMS" != "true" ]]; then
        log_debug "Checksum verification disabled"
        return 0
    fi
    
    if [[ -z "$expected_checksum" ]]; then
        log_debug "No checksum provided for verification"
        return 0
    fi
    
    log_debug "Verifying $algorithm checksum: $file"
    
    local actual_checksum
    actual_checksum=$(calculate_checksum "$file" "$algorithm")
    
    if [[ -z "$actual_checksum" ]]; then
        log_error "Failed to calculate checksum for: $file"
        return 1
    fi
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_debug "Checksum verification successful"
        security_audit_log "checksum_verified" "$file" "$algorithm:$actual_checksum"
        return 0
    else
        log_error "Checksum mismatch for $file"
        log_error "Expected: $expected_checksum"
        log_error "Actual:   $actual_checksum"
        security_audit_log "checksum_mismatch" "$file" "expected:$expected_checksum,actual:$actual_checksum"
        return 1
    fi
}

download_and_verify_checksum() {
    local file_url="$1"
    local checksum_url="$2"
    local output_dir="$3"
    local algorithm="${4:-sha256}"
    
    local file_name
    file_name=$(basename "$file_url")
    local file_path="$output_dir/$file_name"
    
    # Download main file
    if ! download_file "$file_url" "$file_path"; then
        return 1
    fi
    
    # Download and parse checksum file
    local checksum_file="$output_dir/$(basename "$checksum_url")"
    if ! download_file "$checksum_url" "$checksum_file"; then
        log_warn "Failed to download checksum file: $checksum_url"
        return 1
    fi
    
    # Extract expected checksum
    local expected_checksum
    if expected_checksum=$(grep "$file_name" "$checksum_file" | cut -d' ' -f1); then
        verify_checksum "$file_path" "$expected_checksum" "$algorithm"
    else
        log_warn "Checksum not found in file for: $file_name"
        return 1
    fi
}

# ---------- Certificate Functions ----------
verify_certificate_chain() {
    local cert_file="$1"
    local ca_bundle="${2:-/etc/ssl/certs/ca-certificates.crt}"
    
    if ! command_exists openssl; then
        log_warn "OpenSSL not available, skipping certificate verification"
        return 0
    fi
    
    if [[ ! -f "$ca_bundle" ]]; then
        log_warn "CA bundle not found: $ca_bundle"
        return 0
    fi
    
    log_debug "Verifying certificate chain: $cert_file"
    
    if openssl verify -CAfile "$ca_bundle" "$cert_file" >/dev/null 2>&1; then
        log_debug "Certificate verification successful"
        return 0
    else
        log_warn "Certificate verification failed: $cert_file"
        return 1
    fi
}

# ---------- Secure Download Functions ----------
secure_download() {
    local url="$1"
    local output_file="$2"
    local checksum="${3:-}"
    local signature_url="${4:-}"
    local key_id="${5:-}"
    
    local temp_dir
    temp_dir=$(mktemp -d)
    TEMP_FILES="$TEMP_FILES $temp_dir"
    
    # Download file
    local temp_file="$temp_dir/$(basename "$output_file")"
    if ! download_file "$url" "$temp_file"; then
        return 1
    fi
    
    # Verify checksum if provided
    if [[ -n "$checksum" ]]; then
        if ! verify_checksum "$temp_file" "$checksum"; then
            return 1
        fi
    fi
    
    # Verify signature if provided
    if [[ -n "$signature_url" ]]; then
        local sig_file="$temp_dir/signature"
        if download_file "$signature_url" "$sig_file"; then
            if [[ -n "$key_id" ]]; then
                import_gpg_key "$key_id"
            fi
            
            if ! verify_gpg_signature "$temp_file" "$sig_file" "$key_id"; then
                return 1
            fi
        else
            log_warn "Failed to download signature for verification"
        fi
    fi
    
    # Move verified file to final location
    mv "$temp_file" "$output_file"
    
    security_audit_log "secure_download_complete" "$output_file" "$url"
    return 0
}

# ---------- Security Audit Logging ----------
security_audit_log() {
    local event_type="$1"
    local resource="$2"
    local details="${3:-}"
    
    if [[ "$AUDIT_LOGGING" != "true" ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    local log_entry
    log_entry=$(printf '%s|%s|%s|%s|%s\n' \
        "$timestamp" \
        "$event_type" \
        "$resource" \
        "$details" \
        "$$")
    
    if [[ -n "$SECURITY_LOG_FILE" ]]; then
        echo "$log_entry" >> "$SECURITY_LOG_FILE"
    fi
    
    # Also log to syslog if available
    if command_exists logger; then
        logger -t "devbootstrap-security" "$log_entry"
    fi
    
    log_debug "Security audit: $event_type - $resource"
}

# ---------- Security Policy Enforcement ----------
check_security_policy() {
    local policy_file="${1:-/etc/devtools/security.policy}"
    
    if [[ ! -f "$policy_file" ]]; then
        log_debug "No security policy file found: $policy_file"
        return 0
    fi
    
    log_info "Enforcing security policy: $policy_file"
    
    # Parse security policy
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        key=$(trim "$key")
        value=$(trim "$value")
        
        case "$key" in
            require_signatures)
                export VERIFY_SIGNATURES="$value"
                ;;
            require_checksums)
                export VERIFY_CHECKSUMS="$value"
                ;;
            audit_logging)
                export AUDIT_LOGGING="$value"
                ;;
            allowed_domains)
                export ALLOWED_DOMAINS="$value"
                ;;
            blocked_domains)
                export BLOCKED_DOMAINS="$value"
                ;;
        esac
    done < "$policy_file"
    
    security_audit_log "security_policy_loaded" "$policy_file" "enforced"
}

validate_download_url() {
    local url="$1"
    
    # Check against allowed domains
    if [[ -n "${ALLOWED_DOMAINS:-}" ]]; then
        local domain
        domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')
        
        local allowed=false
        IFS=',' read -ra allowed_domains <<< "$ALLOWED_DOMAINS"
        for allowed_domain in "${allowed_domains[@]}"; do
            allowed_domain=$(trim "$allowed_domain")
            if [[ "$domain" == *"$allowed_domain"* ]]; then
                allowed=true
                break
            fi
        done
        
        if [[ "$allowed" != "true" ]]; then
            log_error "Download blocked by security policy: $url"
            security_audit_log "download_blocked" "$url" "domain_not_allowed"
            return 1
        fi
    fi
    
    # Check against blocked domains
    if [[ -n "${BLOCKED_DOMAINS:-}" ]]; then
        local domain
        domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')
        
        IFS=',' read -ra blocked_domains <<< "$BLOCKED_DOMAINS"
        for blocked_domain in "${blocked_domains[@]}"; do
            blocked_domain=$(trim "$blocked_domain")
            if [[ "$domain" == *"$blocked_domain"* ]]; then
                log_error "Download blocked by security policy: $url"
                security_audit_log "download_blocked" "$url" "domain_blocked"
                return 1
            fi
        done
    fi
    
    return 0
}

# ---------- Vulnerability Scanning ----------
scan_for_vulnerabilities() {
    local file="$1"
    local scanner="${2:-clamav}"
    
    case "$scanner" in
        clamav)
            if command_exists clamscan; then
                log_debug "Scanning file with ClamAV: $file"
                if clamscan --quiet "$file"; then
                    log_debug "File scan clean: $file"
                    security_audit_log "vulnerability_scan_clean" "$file" "clamav"
                    return 0
                else
                    log_error "File scan detected threat: $file"
                    security_audit_log "vulnerability_scan_threat" "$file" "clamav"
                    return 1
                fi
            else
                log_debug "ClamAV not available, skipping scan"
                return 0
            fi
            ;;
        *)
            log_warn "Unknown vulnerability scanner: $scanner"
            return 0
            ;;
    esac
}

# ---------- Security Report Generation ----------
generate_security_report() {
    local output_file="${1:-security_report.json}"
    
    log_info "Generating security report: $output_file"
    
    local signature_count=0
    local checksum_count=0
    local audit_count=0
    
    # Count security events from audit log
    if [[ -n "$SECURITY_LOG_FILE" && -f "$SECURITY_LOG_FILE" ]]; then
        signature_count=$(grep -c "signature_verified" "$SECURITY_LOG_FILE" 2>/dev/null || echo "0")
        checksum_count=$(grep -c "checksum_verified" "$SECURITY_LOG_FILE" 2>/dev/null || echo "0")
        audit_count=$(wc -l < "$SECURITY_LOG_FILE" 2>/dev/null || echo "0")
    fi
    
    {
        echo "{"
        echo "  \"security_report\": {"
        echo "    \"timestamp\": \"$(date -Iseconds)\","
        echo "    \"version\": \"$SCRIPT_VERSION\","
        echo "    \"configuration\": {"
        echo "      \"verify_signatures\": \"$VERIFY_SIGNATURES\","
        echo "      \"verify_checksums\": \"$VERIFY_CHECKSUMS\","
        echo "      \"audit_logging\": \"$AUDIT_LOGGING\""
        echo "    },"
        echo "    \"statistics\": {"
        echo "      \"signature_verifications\": $signature_count,"
        echo "      \"checksum_verifications\": $checksum_count,"
        echo "      \"total_audit_events\": $audit_count"
        echo "    },"
        echo "    \"status\": \"$([ "$VERIFY_SIGNATURES" == "true" ] && [ "$VERIFY_CHECKSUMS" == "true" ] && echo "secure" || echo "standard")\""
        echo "  }"
        echo "}"
    } > "$output_file"
    
    log_info "Security report generated: $output_file"
}

# ---------- Initialization ----------
initialize_security() {
    log_debug "Initializing security library"
    
    # Set up security audit logging
    if [[ "$AUDIT_LOGGING" == "true" && -z "$SECURITY_LOG_FILE" ]]; then
        SECURITY_LOG_FILE="${LOG_FILE%.log}_security.log"
        export SECURITY_LOG_FILE
    fi
    
    # Check for security policy
    check_security_policy
    
    # Log security configuration
    security_audit_log "security_initialized" "system" "signatures:$VERIFY_SIGNATURES,checksums:$VERIFY_CHECKSUMS"
}