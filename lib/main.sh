#!/usr/bin/env bash
# Main orchestration logic for dev-environment-setup

run_main_logic() {
    # This function should orchestrate execution based on COMMAND
    # Call appropriate functions from modules/libs
    log_debug "Starting dynamic tool status/version check loop"
    clear_results

    # Define tool-category mapping (should be in config, but hardcoded for now)
    declare -A TOOL_CATEGORY_MAP=(
        [docker]=containers
        [docker-compose]=containers
        [podman]=containers
        [containerd]=containers
        [kubectl]=kubernetes
        [helm]=kubernetes
        [k9s]=kubernetes
        [terraform]=hashicorp
        [packer]=hashicorp
        [vault]=hashicorp
        [consul]=hashicorp
        [aws-cli]=cloud
        [gcloud]=cloud
        [bicep]=cloud
        [azure-cli]=cloud
        [pyenv]=devtools
        [nvm]=devtools
        [rbenv]=devtools
        [git]=devtools
        [jq]=devtools
        [powershell]=devtools
    )

    # Get enabled categories from config (match actual awk output)
    local enabled_categories=()
    for cat in containers kubernetes hashicorp cloud devtools; do
        config_var="CONFIG_${cat}"
        if [[ "${!config_var:-false}" == "true" ]]; then
            enabled_categories+=("$cat")
        fi
    done

    # Get enabled tools from config (match actual awk output)
    local enabled_tools=()
    for tool in "${!TOOL_CATEGORY_MAP[@]}"; do
        local config_key="${tool//-/_}"
        config_var="CONFIG_${config_key}"
        if [[ "${!config_var:-false}" == "true" ]]; then
            enabled_tools+=("$tool")
        fi
    done

    # For each enabled category, display all its enabled tools
    for category in "${enabled_categories[@]}"; do
        for tool in "${!TOOL_CATEGORY_MAP[@]}"; do
            if [[ "${TOOL_CATEGORY_MAP[$tool]}" == "$category" ]]; then
                # Only show if enabled in config
                local config_key="${tool//-/_}"
                config_var="CONFIG_${config_key}"
                if [[ "${!config_var:-false}" == "true" ]]; then
                    local local_version="-"
                    local latest_version="-"
                    local status="not_installed"
                    local path="-"
                    local verified="unknown"
                    local on_path="no"

                    log_debug "Checking tool: $tool ($category)"
                    if command -v "$tool" >/dev/null 2>&1; then
                        path="$(command -v "$tool")"
                        # Exclude WSL/Windows paths
                        if [[ "$path" == /mnt/c/* || "$path" == /mnt/d/* || "$path" == /mnt/*/Program* || "$path" == *pyenv-win* ]]; then
                            log_debug "$tool found in Windows/WSL path ($path), ignoring."
                            status="not_installed"
                            path="-"
                            local_version="-"
                        else
                            local_version="$(timeout 2s $tool --version 2>&1 | head -1 | grep -oE '[0-9]+(\.[0-9]+){1,2}' || echo '-')"
                            status="installed"
                            log_debug "$tool is installed at $path, version $local_version"
                            # Check if tool is on PATH
                            if [[ ":$PATH:" == *":$(dirname "$path"):"* ]]; then
                                on_path="yes"
                            else
                                on_path="no"
                                # Logic to put tool on PATH (example: symlink to /usr/local/bin)
                                if [[ -f "$path" ]]; then
                                    ln -sf "$path" "/usr/local/bin/$tool"
                                    log_info "Added $tool to /usr/local/bin (PATH)"
                                    on_path="yes"
                                fi
                            fi
                        fi
                    else
                        log_debug "$tool is not installed"
                    fi

                    log_debug "Fetching latest version for $tool"
                    latest_version="$(version_check_cached "$tool")"
                    log_debug "Latest version for $tool: $latest_version"

                    add_tool_result "$tool" "$category" "$local_version" "$latest_version" "$status" "$path" "$verified" "$on_path"
                    log_debug "Added tool result for $tool"
                fi
            fi
        done
    done

    log_debug "Finished dynamic tool status/version check loop"
    print_status_table
    print_summary
}

# --- Command Stubs ---
execute_check_command() {
    log_info "Check mode: displaying tool status table (stub)."
    print_status_table
    print_summary
}
execute_install_command() {
    log_info "Install mode: installing tools (stub)."
    # TODO: Call install logic from modules
}
execute_upgrade_command() {
    log_info "Upgrade mode: upgrading tools (stub)."
    # TODO: Call upgrade logic from modules
}
execute_remove_command() {
    log_info "Remove mode: removing tools (stub)."
    # TODO: Call remove logic from modules
}
execute_list_command() {
    log_info "List mode: listing tools (stub)."
    # TODO: Call list logic from modules
}
