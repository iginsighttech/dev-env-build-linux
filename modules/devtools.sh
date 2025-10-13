#!/usr/bin/env bash
# Developer tools installer module
# Supports: pyenv, nvm, rbenv, git, jq, powershell

install_devtools() {
    local tools="${1:-}" # comma-separated list
        local silent_mode="${SILENT:-0}"
        IFS=',' read -ra tool_array <<< "$tools"
        for tool in "${tool_array[@]}"; do
            tool=$(trim "$tool")
            case "$tool" in
                pyenv)
                    if [[ "$INSTALL_MODE" == "system" ]]; then
                        log_warn "pyenv should only be installed in user mode. Skipping system-wide install."
                    else
                        if [[ "$silent_mode" -eq 1 ]]; then
                            curl -s https://pyenv.run | bash
                        else
                            curl https://pyenv.run | bash
                        fi
                    fi
                    ;;
                nvm)
                    if [[ "$INSTALL_MODE" == "system" ]]; then
                        log_warn "nvm should only be installed in user mode. Skipping system-wide install."
                    else
                        if [[ "$silent_mode" -eq 1 ]]; then
                            curl -s https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
                        else
                            curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
                        fi
                    fi
                    ;;
                rbenv)
                    if [[ "$INSTALL_MODE" == "system" ]]; then
                        log_warn "rbenv should only be installed in user mode. Skipping system-wide install."
                    else
                        if [[ "$silent_mode" -eq 1 ]]; then
                            git clone -q https://github.com/rbenv/rbenv.git ~/.rbenv
                        else
                            git clone https://github.com/rbenv/rbenv.git ~/.rbenv
                        fi
                    fi
                    ;;
                git)
                    if [[ "$silent_mode" -eq 1 ]]; then
                        $PKG_MGR install -y git &>/dev/null
                    else
                        $PKG_MGR install -y git
                    fi
                    ;;
                jq)
                    if [[ "$silent_mode" -eq 1 ]]; then
                        $PKG_MGR install -y jq &>/dev/null
                    else
                        $PKG_MGR install -y jq
                    fi
                    ;;
                powershell)
                    if [[ "$silent_mode" -eq 1 ]]; then
                        $PKG_MGR install -y powershell &>/dev/null
                    else
                        $PKG_MGR install -y powershell
                    fi
                    ;;
                *)
                    log_warn "Unknown devtool: $tool"
                    ;;
            esac
        done
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_devtools
fi
