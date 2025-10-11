# InSight Dev Bootstrap

A modular, enterprise-ready Linux development environment setup tool for automated installation and management of essential CLI development tools.

## 🚀 Quick Start

```bash
# System-wide installation (requires root)
sudo ./dev-environment-setup-new.sh install

# User-scope installation
./dev-environment-setup-new.sh install --user

# Dry run to see what would be installed
./dev-environment-setup-new.sh install --dry-run

# Check current status only
./dev-environment-setup-new.sh check

# Install specific categories
./dev-environment-setup-new.sh install --categories containers,cloud

# Install specific tools
./dev-environment-setup-new.sh install --tools docker,kubectl,terraform,powershell
```

## 📋 Features

### ✅ Current Features
- Modular architecture: lib/ libraries, modules/ for tool categories
- Enterprise-ready: dry-run, check-only, selective install, upgrade, compliance, security
- Multi-architecture: x86_64, aarch64, armv7l
- Cross-distribution: Ubuntu/Debian, RHEL/Fedora/CentOS, SUSE, Arch Linux
- Configuration-driven: YAML config for tool selection, version pinning, profiles
- Enhanced security: GPG signature verification, checksum validation, audit logging
- Comprehensive reporting: CSV, JSON, TXT, HTML, Markdown
- Idempotent operation: safe to run multiple times

### 🔧 Tool Categories & Supported Tools

#### Containers & Orchestration
- Docker Engine
- containerd
- Podman
- docker-compose

#### Kubernetes
- kubectl
- helm
- k9s

#### HashiCorp Stack
- terraform
- packer
- vault
- consul

#### Cloud Providers
- aws-cli
- gcloud
- azure-cli

#### Development Tools
- pyenv
- nvm
- rbenv
- PowerShell
- git
- jq

## 📁 Project Structure

```
dev-env-build-linux/
├── dev-environment-setup-new.sh    # Main entry point (modular)
├── lib/                           # Core library functions
│   ├── common.sh                  # Shared utilities
│   ├── distro.sh                  # OS/distribution detection
│   ├── installer.sh               # Installation helpers
│   ├── reporter.sh                # Status reporting
│   └── security.sh                # Security features
├── modules/                       # Tool category modules
│   ├── containers.sh              # Container tools
│   ├── kubernetes.sh              # Kubernetes tools
│   ├── hashicorp.sh               # HashiCorp tools
│   ├── cloud.sh                   # Cloud CLI tools
│   └── devtools.sh                # Developer tools
├── config/                        # Configuration files
│   ├── default.yml                # Default tool selection
│   ├── enterprise.yml             # Enterprise configuration
│   └── minimal.yml                # Minimal installation
├── docs/                          # Documentation
│   ├── ARCHITECTURE.md            # Architecture overview
│   └── examples/                  # Usage examples
├── tests/                         # Test suite
│   └── test-runner.sh             # Test automation
├── README.md                      # This file
└── CHANGELOG.md                   # Version history
```

## 🔧 Installation & Usage

### System-wide Installation
```bash
sudo ./dev-environment-setup-new.sh install
```

### User-scope Installation
```bash
./dev-environment-setup-new.sh install --user
```

### Configuration-based Installation
```bash
./dev-environment-setup-new.sh install --config config/enterprise.yml
./dev-environment-setup-new.sh install --config config/minimal.yml --tools +terraform
```

### Advanced Usage
- Dry run: `./dev-environment-setup-new.sh install --dry-run`
- Status check: `./dev-environment-setup-new.sh check`
- Selective install: `./dev-environment-setup-new.sh install --categories containers,cloud`
- Individual tools: `./dev-environment-setup-new.sh install --tools docker,kubectl,terraform,powershell`
- Version pinning: `./dev-environment-setup-new.sh install --versions terraform=1.5.0,kubectl=1.27.0`
- Upgrade: `./dev-environment-setup-new.sh upgrade`
- Force reinstall: `./dev-environment-setup-new.sh install --force`
- Security: `./dev-environment-setup-new.sh install --verify-signatures`
- Compliance: `./dev-environment-setup-new.sh install --compliance-report`

## 📊 Output & Reporting
- Console output: colored, real-time status
- Reports: CSV, JSON, TXT, HTML, Markdown
- Status: tool name, category, installed/latest version, PATH, location, verification

## 🔒 Security
- HTTPS downloads, GPG verification, checksum validation
- Audit logging, proxy support, timeout protection

## 🐛 Troubleshooting
- Permission issues: use `--user` mode
- Network issues: set proxy variables
- Unsupported distro: use `--list-distros` or specify package manager
- Logs: enable `--verbose` or `--debug`, check log files

## 🤝 Contributing
- Fork, branch, test, submit PR
- Add new tools: create module, update config/docs/tests

## 📄 License
MIT License

## 📞 Support
- Issues: GitHub
- Security: security@yourcompany.com

---
**Version**: 1.0.0  
**Last Updated**: October 2025  
**Maintainer**: Development Infrastructure Team
