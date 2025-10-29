print_status_table() {
    printf "%-20s %-15s %-15s %-15s %-10s %-30s %-10s %-8s\n" "Tool" "Category" "Local Ver" "Latest Ver" "Status" "Path" "Verified" "On Path"
    for result in "${TOOL_RESULTS[@]}"; do
        IFS='|' read -r name category local_version latest_version status path verified on_path <<< "$result"
        printf "%-20s %-15s %-15s %-15s %-10s %-30s %-10s %-8s\n" "$name" "$category" "$local_version" "$latest_version" "$status" "$path" "$verified" "$on_path"
    done
}

print_summary() {
    local total=${#TOOL_RESULTS[@]}
    local installed=0
    for result in "${TOOL_RESULTS[@]}"; do
        IFS='|' read -r _ _ _ _ status _ _ <<< "$result"
        [[ "$status" == "installed" ]] && ((installed++))
    done
    echo "Summary: $installed/$total tools installed."
}
#!/usr/bin/env bash
log_info() {
    # Wrapper for info logging
    echo "[INFO] $@"
}

log_warn() {
    # Wrapper for warning logging
    echo "[WARN] $@"
}

log_error() {
    # Wrapper for error logging
    echo "[ERROR] $@"
}
#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Status Reporting Library
#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap - Status Reporting Library
# Multi-format status reporting and output generation
# =====================================================================

# Prevent multiple inclusion
[[ "${REPORTER_LIB_LOADED:-}" == "true" ]] && return 0
readonly REPORTER_LIB_LOADED="true"

# Source required libraries
# shellcheck disable=SC1091
source "${BASH_SOURCE[0]%/*}/common.sh"

# ---------- Report Data Structure ----------
declare -a TOOL_RESULTS=()  # Array to store tool results

# Tool result structure: "name|category|local_version|latest_version|status|path|verified"
add_tool_result() {
    local name="$1"
    local category="$2"
    local local_version="$3"
    local latest_version="$4"
    local status="$5"
    local path="$6"
    local verified="${7:-unknown}"
    
    local result="${name}|${category}|${local_version}|${latest_version}|${status}|${path}|${verified}|${on_path}"
    TOOL_RESULTS+=("$result")
    
    log_debug "Added result: $name ($status)"
}

# Clear all results
clear_results() {
    TOOL_RESULTS=()
    log_debug "Cleared all tool results"
}

# Get result count
get_result_count() {
    echo "${#TOOL_RESULTS[@]}"
}

# ---------- Status Calculation ----------
calculate_summary_stats() {
    local total=0
    local installed=0
    local outdated=0
    local failed=0
    local verified=0
    
    for result in "${TOOL_RESULTS[@]}"; do
        IFS='|' read -r name category local_ver latest_ver status path verified_status <<< "$result"
        ((total++))
        case "$status" in
            installed|current) ((installed++)) ;;
            outdated) ((outdated++)); ((installed++)) ;;
            failed|error) ((failed++)) ;;
        esac
        case "$verified_status" in
            verified|true) ((verified++)) ;;
        esac
    done
    SUMMARY_TOTAL=$total
    SUMMARY_INSTALLED=$installed
    SUMMARY_OUTDATED=$outdated
    SUMMARY_FAILED=$failed
    SUMMARY_VERIFIED=$verified
}

print_summary() {
    calculate_summary_stats
    
    echo
    title "Summary"
    echo "Total tools processed: $SUMMARY_TOTAL"
    echo "Successfully installed: $(green "$SUMMARY_INSTALLED")"
    
    if [[ $SUMMARY_OUTDATED -gt 0 ]]; then
        echo "Outdated versions: $(yellow "$SUMMARY_OUTDATED")"
    fi
    
    if [[ $SUMMARY_FAILED -gt 0 ]]; then
        echo "Failed installations: $(red "$SUMMARY_FAILED")"
    fi
    
    echo "Verified installations: $(green "$SUMMARY_VERIFIED")"
    
    # Calculate percentages
    if [[ $SUMMARY_TOTAL -gt 0 ]]; then
        local success_rate=$((SUMMARY_INSTALLED * 100 / SUMMARY_TOTAL))
        local verification_rate=$((SUMMARY_VERIFIED * 100 / SUMMARY_TOTAL))
        
        echo "Success rate: ${success_rate}%"
        echo "Verification rate: ${verification_rate}%"
    fi
}

# ---------- CSV Output ----------
generate_csv_report() {
    local output_file="$1"
    local include_metadata="${2:-false}"
    
    log_debug "Generating CSV report: $output_file"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would generate CSV report: $output_file"
        return 0
    fi
    
    {
        # CSV header
        echo "Name,Category,Installed Version,Latest Version,Status,Path,Verified,Timestamp"
        
        # Data rows
        local timestamp
        timestamp=$(date -Iseconds)
        
        for result in "${TOOL_RESULTS[@]}"; do
            IFS='|' read -r name category local_ver latest_ver status path verified_status <<< "$result"
            echo "\"$name\",\"$category\",\"${local_ver}\",\"${latest_ver}\",\"$status\",\"${path}\",\"$verified_status\",\"$timestamp\""
        done
        
        # Metadata rows if requested
        if [[ "$include_metadata" == "true" ]]; then
            calculate_summary_stats
            echo
            echo "# Metadata"
            echo "Total Tools,$SUMMARY_TOTAL"
            echo "Installed,$SUMMARY_INSTALLED"
            echo "Outdated,$SUMMARY_OUTDATED"
            echo "Failed,$SUMMARY_FAILED"
            echo "Verified,$SUMMARY_VERIFIED"
            echo "Generated,\"$timestamp\""
            echo "System,\"$(uname -s)\""
            echo "Architecture,\"$(uname -m)\""
            echo "Distribution,\"${DISTRO_ID:-unknown}\""
        fi
    } > "$output_file"
    
    log_info "CSV report generated: $output_file"
}

# ---------- JSON Output ----------
generate_json_report() {
    local output_file="$1"
    
    log_debug "Generating JSON report: $output_file"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would generate JSON report: $output_file"
        return 0
    fi
    
    calculate_summary_stats
    
    {
        echo "{"
        echo "  \"metadata\": {"
        echo "    \"version\": \"$SCRIPT_VERSION\","
        echo "    \"timestamp\": \"$(date -Iseconds)\","
        echo "    \"system\": {"
        echo "      \"os\": \"$(uname -s)\","
        echo "      \"architecture\": \"$(uname -m)\","
        echo "      \"distribution\": \"${DISTRO_ID:-unknown}\","
        echo "      \"kernel\": \"$(uname -r)\""
        echo "    },"
        echo "    \"installation\": {"
        echo "      \"mode\": \"${INSTALL_MODE:-unknown}\","
        echo "      \"binDir\": \"${BIN_DIR:-unknown}\","
        echo "      \"optDir\": \"${OPT_DIR:-unknown}\""
        echo "    }"
        echo "  },"
        echo "  \"summary\": {"
        echo "    \"total\": $SUMMARY_TOTAL,"
        echo "    \"installed\": $SUMMARY_INSTALLED,"
        echo "    \"outdated\": $SUMMARY_OUTDATED,"
        echo "    \"failed\": $SUMMARY_FAILED,"
        echo "    \"verified\": $SUMMARY_VERIFIED"
        echo "  },"
        echo "  \"tools\": ["
        
        local first=true
        for result in "${TOOL_RESULTS[@]}"; do
            IFS='|' read -r name category local_ver latest_ver status path verified_status <<< "$result"
            
            [[ "$first" != "true" ]] && echo "    ,"
            echo "    {"
            echo "      \"name\": \"$name\","
            echo "      \"category\": \"$category\","
            echo "      \"versions\": {"
            echo "        \"installed\": \"${local_ver}\","
            echo "        \"latest\": \"${latest_ver}\""
            echo "      },"
            echo "      \"status\": \"$status\","
            echo "      \"path\": \"${path}\","
            echo "      \"verified\": \"$verified_status\""
            echo -n "    }"
            
            first=false
        done
        
        echo
        echo "  ]"
        echo "}"
    } > "$output_file"
    
    log_info "JSON report generated: $output_file"
}

# ---------- Markdown Output ----------
generate_markdown_report() {
    local output_file="$1"
    
    log_debug "Generating Markdown report: $output_file"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would generate Markdown report: $output_file"
        return 0
    fi
    
    calculate_summary_stats
    
    {
        echo "# Development Environment Setup Report"
        echo
        echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "**System:** $(uname -s) $(uname -m)"
        echo "**Distribution:** ${DISTRO_ID:-unknown}"
        echo
        echo "## Summary"
        echo
        echo "- **Total tools:** $SUMMARY_TOTAL"
        echo "- **Successfully installed:** $SUMMARY_INSTALLED"
        
        if [[ $SUMMARY_OUTDATED -gt 0 ]]; then
            echo "- **Outdated versions:** $SUMMARY_OUTDATED"
        fi
        
        if [[ $SUMMARY_FAILED -gt 0 ]]; then
            echo "- **Failed installations:** $SUMMARY_FAILED"
        fi
        
        echo "- **Verified installations:** $SUMMARY_VERIFIED"
        echo
        echo "## Tool Details"
        echo
        echo "| Tool | Category | Installed | Latest | Status | Verified | Location |"
        echo "|------|----------|-----------|---------|---------|----------|----------|"
        
        for result in "${TOOL_RESULTS[@]}"; do
            IFS='|' read -r name category local_ver latest_ver status path verified_status <<< "$result"
            
            local status_emoji
            case "$status" in
                installed|current) status_emoji="✅" ;;
                outdated) status_emoji="⚠️" ;;
                failed|error) status_emoji="❌" ;;
                not_found) status_emoji="❌" ;;
                *) status_emoji="❓" ;;
            esac
            
            local verified_emoji
            case "$verified_status" in
                verified|true) verified_emoji="✅" ;;
                failed|false) verified_emoji="❌" ;;
                *) verified_emoji="❓" ;;
            esac
            
            echo "| $name | $category | ${local_ver:--} | ${latest_ver:--} | $status_emoji $status | $verified_emoji | \`${path:--}\` |"
        done
        
        echo
        echo "## Installation Paths"
        echo
        echo "- **Binary directory:** \`${BIN_DIR:-unknown}\`"
        echo "- **Data directory:** \`${OPT_DIR:-unknown}\`"
        echo "- **Profile configuration:** \`${PROFILE_RC:-unknown}\`"
        echo
        echo "---"
        echo "*Report generated by InSight Dev Bootstrap v$SCRIPT_VERSION*"
    } > "$output_file"
    
    log_info "Markdown report generated: $output_file"
}

# ---------- HTML Output ----------
generate_html_report() {
    local output_file="$1"
    
    log_debug "Generating HTML report: $output_file"
    
    if is_dry_run; then
        log_info "DRY-RUN: Would generate HTML report: $output_file"
        return 0
    fi
    
    calculate_summary_stats
    
    {
        cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Development Environment Setup Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-card { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-value { font-size: 2em; font-weight: bold; color: #2563eb; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; font-weight: 600; }
        .status-success { color: #16a34a; }
        .status-warning { color: #ca8a04; }
        .status-error { color: #dc2626; }
        .verified { color: #16a34a; }
        .not-verified { color: #dc2626; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Development Environment Setup Report</h1>
EOF
        echo "        <p><strong>Generated:</strong> $(date '+%Y-%m-%d %H:%M:%S %Z')</p>"
        echo "        <p><strong>System:</strong> $(uname -s) $(uname -m)</p>"
        echo "        <p><strong>Distribution:</strong> ${DISTRO_ID:-unknown}</p>"
        cat << EOF
    </div>

    <div class="summary">
        <div class="stat-card">
            <div class="stat-value">$SUMMARY_TOTAL</div>
            <div>Total Tools</div>
        </div>
        <div class="stat-card">
            <div class="stat-value status-success">$SUMMARY_INSTALLED</div>
            <div>Installed</div>
        </div>
EOF
        
        if [[ $SUMMARY_OUTDATED -gt 0 ]]; then
            cat << EOF
        <div class="stat-card">
            <div class="stat-value status-warning">$SUMMARY_OUTDATED</div>
            <div>Outdated</div>
        </div>
EOF
        fi
        
        if [[ $SUMMARY_FAILED -gt 0 ]]; then
            cat << EOF
        <div class="stat-card">
            <div class="stat-value status-error">$SUMMARY_FAILED</div>
            <div>Failed</div>
        </div>
EOF
        fi
        
        cat << EOF
        <div class="stat-card">
            <div class="stat-value status-success">$SUMMARY_VERIFIED</div>
            <div>Verified</div>
        </div>
    </div>

    <h2>Tool Details</h2>
    <table>
        <thead>
            <tr>
                <th>Tool</th>
                <th>Category</th>
                <th>Installed</th>
                <th>Latest</th>
                <th>Status</th>
                <th>Verified</th>
                <th>Location</th>
            </tr>
        </thead>
        <tbody>
EOF
        
        for result in "${TOOL_RESULTS[@]}"; do
            IFS='|' read -r name category local_ver latest_ver status path verified_status <<< "$result"
            
            local status_class
            case "$status" in
                installed|current) status_class="status-success" ;;
                outdated) status_class="status-warning" ;;
                failed|error|not_found) status_class="status-error" ;;
                *) status_class="" ;;
            esac
            
            local verified_class
            case "$verified_status" in
                verified|true) verified_class="verified" ;;
                failed|false) verified_class="not-verified" ;;
                *) verified_class="" ;;
            esac
            
            echo "            <tr>"
            echo "                <td><strong>$name</strong></td>"
            echo "                <td>$category</td>"
            echo "                <td>${local_ver:--}</td>"
            echo "                <td>${latest_ver:--}</td>"
            echo "                <td class=\"$status_class\">$status</td>"
            echo "                <td class=\"$verified_class\">$verified_status</td>"
            echo "                <td><code>${path:--}</code></td>"
            echo "            </tr>"
        done
        
        cat << EOF
        </tbody>
    </table>

    <div class="footer">
        <p><em>Report generated by InSight Dev Bootstrap v$SCRIPT_VERSION</em></p>
    </div>
</body>
</html>
EOF
    } > "$output_file"
    
    log_info "HTML report generated: $output_file"
}

# ---------- Multi-format Report Generation ----------
generate_reports() {
    local base_name="${1:-dev_setup_status}"
    local formats="${2:-csv,json,txt}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    log_info "Generating reports with base name: $base_name"
    
    # Parse requested formats
    IFS=',' read -ra format_array <<< "$formats"
    
    for format in "${format_array[@]}"; do
        format=$(trim "$format")
        local output_file="${base_name}_${timestamp}.${format}"
        
        case "$format" in
            csv)
                generate_csv_report "$output_file" true
                ;;
            json)
                generate_json_report "$output_file"
                ;;
            md|markdown)
                generate_markdown_report "$output_file"
                ;;
            html)
                generate_html_report "$output_file"
                ;;
            txt)
                {
                    echo "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
                    echo "Generated: $(date -Iseconds)"
                    echo "System: $(uname -s) $(uname -m)"
                    echo "Distribution: ${DISTRO_ID:-unknown}"
                    echo
                    print_status_table false
                    echo
                    print_summary
                } > "$output_file"
                log_info "Text report generated: $output_file"
                ;;
            *)
                log_warn "Unknown report format: $format"
                ;;
        esac
    done
}

# ---------- Compliance Reporting ----------
generate_compliance_report() {
    local output_file="${1:-compliance_report.json}"
    
    log_debug "Generating compliance report: $output_file"
    
    calculate_summary_stats
    
    local compliance_score=0
    if [[ $SUMMARY_TOTAL -gt 0 ]]; then
        compliance_score=$((SUMMARY_VERIFIED * 100 / SUMMARY_TOTAL))
    fi
    
    {
        echo "{"
        echo "  \"compliance\": {"
        echo "    \"version\": \"1.0\","
        echo "    \"timestamp\": \"$(date -Iseconds)\","
        echo "    \"score\": $compliance_score,"
        echo "    \"status\": \"$([ $compliance_score -ge 80 ] && echo "compliant" || echo "non-compliant")\""
        echo "  },"
        echo "  \"verification\": {"
        echo "    \"total_tools\": $SUMMARY_TOTAL,"
        echo "    \"verified_tools\": $SUMMARY_VERIFIED,"
        echo "    \"failed_verifications\": $((SUMMARY_TOTAL - SUMMARY_VERIFIED))"
        echo "  },"
        echo "  \"security\": {"
        echo "    \"signature_verification\": \"${VERIFY_SIGNATURES:-false}\","
        echo "    \"checksum_validation\": \"${VERIFY_CHECKSUMS:-false}\","
        echo "    \"audit_logging\": \"${AUDIT_LOGGING:-false}\""
        echo "  },"
        echo "  \"issues\": ["
        
        local first=true
        for result in "${TOOL_RESULTS[@]}"; do
            IFS='|' read -r name category local_ver latest_ver status path verified_status <<< "$result"
            
            if [[ "$verified_status" == "failed" || "$verified_status" == "false" || "$status" == "failed" ]]; then
                [[ "$first" != "true" ]] && echo "    ,"
                echo "    {"
                echo "      \"tool\": \"$name\","
                echo "      \"issue\": \"verification_failed\","
                echo "      \"status\": \"$status\","
                echo "      \"verified\": \"$verified_status\""
                echo -n "    }"
                first=false
            fi
        done
        
        echo
        echo "  ]"
        echo "}"
    } > "$output_file"
    
    log_info "Compliance report generated: $output_file (score: ${compliance_score}%)"
}

# ---------- Initialization ----------
initialize_reporter() {
    log_debug "Initializing reporter library"
    
    # Set default report formats if not specified
    REPORT_FORMATS="${REPORT_FORMATS:-csv,json,txt}"
    export REPORT_FORMATS
}