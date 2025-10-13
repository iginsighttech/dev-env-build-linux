#!/usr/bin/env bash
# HashiCorp tools installer module
# Supports: terraform, packer, vault, consul

install_hashicorp_tools() {
    local tools="${1:-}" # comma-separated list
        local silent_mode="${SILENT:-0}"
        if [[ "$silent_mode" -eq 1 ]]; then
            log_info "Installing hashicorp tools silently: $tools"
            # ...actual install logic here, silent mode...
        else
            log_info "Installing hashicorp tools (verbose): $tools"
            # ...actual install logic here, verbose mode...
        fi
    IFS=',' read -ra tool_array <<< "$tools"
    for tool in "${tool_array[@]}"; do
        tool=$(trim "$tool")
        case "$tool" in
            terraform)
                local bin="$BIN_DIR/terraform"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    $PKG_MGR install -y terraform &>/dev/null || {
                        curl -sLo /tmp/terraform.zip https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip
                        unzip -qq /tmp/terraform.zip -d /tmp
                        mv -f /tmp/terraform "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/terraform.zip /tmp/terraform
                    }
                else
                    $PKG_MGR install -y terraform || {
                        curl -Lo /tmp/terraform.zip https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip
                        unzip /tmp/terraform.zip -d /tmp
                        mv -f /tmp/terraform "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/terraform.zip /tmp/terraform
                    }
                fi
                ;;
            packer)
                local bin="$BIN_DIR/packer"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    $PKG_MGR install -y packer &>/dev/null || {
                        curl -sLo /tmp/packer.zip https://releases.hashicorp.com/packer/1.10.2/packer_1.10.2_linux_amd64.zip
                        unzip -qq /tmp/packer.zip -d /tmp
                        mv -f /tmp/packer "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/packer.zip /tmp/packer
                    }
                else
                    $PKG_MGR install -y packer || {
                        curl -Lo /tmp/packer.zip https://releases.hashicorp.com/packer/1.10.2/packer_1.10.2_linux_amd64.zip
                        unzip /tmp/packer.zip -d /tmp
                        mv -f /tmp/packer "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/packer.zip /tmp/packer
                    }
                fi
                ;;
            vault)
                local bin="$BIN_DIR/vault"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    $PKG_MGR install -y vault &>/dev/null || {
                        curl -sLo /tmp/vault.zip https://releases.hashicorp.com/vault/1.16.2/vault_1.16.2_linux_amd64.zip
                        unzip -qq /tmp/vault.zip -d /tmp
                        mv -f /tmp/vault "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/vault.zip /tmp/vault
                    }
                else
                    $PKG_MGR install -y vault || {
                        curl -Lo /tmp/vault.zip https://releases.hashicorp.com/vault/1.16.2/vault_1.16.2_linux_amd64.zip
                        unzip /tmp/vault.zip -d /tmp
                        mv -f /tmp/vault "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/vault.zip /tmp/vault
                    }
                fi
                ;;
            consul)
                local bin="$BIN_DIR/consul"
                rm -f "$bin"
                if [[ "$silent_mode" -eq 1 ]]; then
                    $PKG_MGR install -y consul &>/dev/null || {
                        curl -sLo /tmp/consul.zip https://releases.hashicorp.com/consul/1.18.2/consul_1.18.2_linux_amd64.zip
                        unzip -qq /tmp/consul.zip -d /tmp
                        mv -f /tmp/consul "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/consul.zip /tmp/consul
                    }
                else
                    $PKG_MGR install -y consul || {
                        curl -Lo /tmp/consul.zip https://releases.hashicorp.com/consul/1.18.2/consul_1.18.2_linux_amd64.zip
                        unzip /tmp/consul.zip -d /tmp
                        mv -f /tmp/consul "$bin"
                        chmod +x "$bin"
                        rm -f /tmp/consul.zip /tmp/consul
                    }
                fi
                ;;
            *)
                log_warn "Unknown hashicorp tool: $tool"
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f install_hashicorp_tools
fi
