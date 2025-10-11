# InSight Dev Bootstrap

A comprehensive Linux development environment setup tool that provides automated installation and management of essential CLI development tools.

## 🚀 Quick Start

```bash
# System-wide installation (requires root)
sudo ./dev-environment-setup.sh

# User-scope installation
./dev-environment-setup.sh --user

# Dry run to see what would be installed
./dev-environment-setup.sh --dry-run

# Check current status only
./dev-environment-setup.sh --check

# Install specific categories
./dev-environment-setup.sh --categories containers,cloud

# Install specific tools
./dev-environment-setup.sh --tools docker,kubectl,terraform
```

## 📋 Features

### ✅ Current Features
- **Multi-architecture support**: x86_64, aarch64, armv7l
- **Cross-distribution compatibility**: Ubuntu/Debian, RHEL/Fedora/CentOS, SUSE, Arch Linux
- **Smart execution modes**: Automatic root/user detection with appropriate install paths
- **Version tracking**: Monitors installed vs latest versions
- **Comprehensive reporting**: CSV, JSON, and human-readable status reports
- **Idempotent operation**: Safe to run multiple times

### 🔧 Tool Categories

#### **Containers & Orchestration**
- Docker Engine (with proper repository setup)
- kubectl (Kubernetes CLI)
- helm (Kubernetes package manager)

#### **Infrastructure as Code**
- Terraform (Infrastructure automation)
- Packer (Image building)
- Vault (Secrets management)

#### **Cloud Providers**
- AWS CLI v2
- Google Cloud SDK

#### **Development Environment**
- pyenv (Python version management)
- PowerShell (cross-platform shell)
- git, curl, jq, unzip (baseline tools)

## 📁 Project Structure

```
dev-env-build-linux/
├── dev-environment-setup.sh    # Main entry point
├── lib/                        # Core library functions
│   ├── common.sh              # Shared utilities
│   ├── distro.sh              # OS/distribution detection
│   ├── installer.sh           # Installation helpers
│   └── reporter.sh            # Status reporting
├── modules/                    # Tool category modules
│   ├── containers.sh          # Docker, containerd
│   ├── kubernetes.sh          # kubectl, helm
│   ├── hashicorp.sh           # Terraform, Packer, Vault
│   ├── cloud.sh               # AWS CLI, gcloud
│   └── devtools.sh            # pyenv, development tools
├── config/                     # Configuration files
│   ├── default.yml            # Default tool selection
│   ├── enterprise.yml         # Enterprise configuration
│   └── minimal.yml            # Minimal installation
├── docs/                       # Documentation
│   ├── ARCHITECTURE.md        # Architecture overview
│   └── examples/              # Usage examples
├── tests/                      # Test suite
│   └── test-runner.sh         # Test automation
├── README.md                   # This file
└── CHANGELOG.md               # Version history
```

## 🔧 Installation Options

### System-wide Installation (Recommended for servers)
```bash
sudo ./dev-environment-setup.sh
```
- Installs to `/usr/local/bin`
- Updates system PATH via `/etc/profile.d/`
- Requires root privileges

### User-scope Installation
```bash
./dev-environment-setup.sh --user
```
- Installs to `~/.local/bin`
- Updates `~/.bashrc` PATH
- No root privileges required

### Configuration-based Installation
```bash
# Use predefined configuration
./dev-environment-setup.sh --config config/enterprise.yml

# Override specific settings
./dev-environment-setup.sh --config config/minimal.yml --tools +terraform
```

## 🎯 Advanced Usage

### Dry Run Mode
Preview what would be installed without making changes:
```bash
./dev-environment-setup.sh --dry-run
```

### Status Check
Check current installation status:
```bash
./dev-environment-setup.sh --check
```

### Selective Installation
Install only specific categories:
```bash
# Install container tools only
./dev-environment-setup.sh --categories containers

# Install cloud tools and HashiCorp stack
./dev-environment-setup.sh --categories cloud,hashicorp

# Install individual tools
./dev-environment-setup.sh --tools docker,kubectl,terraform
```

### Version Management
```bash
# Pin specific versions
./dev-environment-setup.sh --versions terraform=1.5.0,kubectl=1.27.0

# Upgrade all tools to latest
./dev-environment-setup.sh --upgrade

# Force reinstallation
./dev-environment-setup.sh --force
```

### Enterprise Features
```bash
# Enable security verification
./dev-environment-setup.sh --verify-signatures

# Generate compliance report
./dev-environment-setup.sh --compliance-report

# Use corporate configuration
./dev-environment-setup.sh --config /etc/devtools/corporate.yml
```

## 📊 Output & Reporting

The tool generates comprehensive reports in multiple formats:

### Console Output
Real-time colored output with progress indicators and status information.

### Generated Reports
- **CSV**: `dev_setup_status_YYYYMMDD_HHMMSS.csv` - Machine-readable data
- **JSON**: `dev_setup_status_YYYYMMDD_HHMMSS.json` - Structured metadata
- **TXT**: `dev_setup_log_YYYYMMDD_HHMMSS.txt` - Human-readable summary

### Status Information
Each tool reports:
- Name and category
- Installed version vs latest available
- PATH availability
- Installation location
- Verification status

## 🔒 Security

### Current Security Measures
- HTTPS downloads with retry logic
- GPG key verification for repository setup
- Timeout protection against hanging operations
- Secure field separation (`IFS=$'\n\t'`)

### Enhanced Security (Enterprise)
- Cryptographic signature verification
- Checksum validation
- Security audit logging
- Corporate proxy support

## 🐛 Troubleshooting

### Common Issues

**Permission denied**
```bash
# Switch to user mode
./dev-environment-setup.sh --user
```

**Network issues**
```bash
# Use corporate proxy
export HTTP_PROXY=http://proxy.corp.com:8080
export HTTPS_PROXY=http://proxy.corp.com:8080
./dev-environment-setup.sh
```

**Unsupported distribution**
```bash
# Check supported distributions
./dev-environment-setup.sh --list-distros

# Force package manager
./dev-environment-setup.sh --package-manager apt
```

### Logs and Debugging
```bash
# Enable verbose logging
./dev-environment-setup.sh --verbose

# Debug mode
./dev-environment-setup.sh --debug

# Check installation logs
cat dev_setup_log_*.txt
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-tool`
3. Make changes and add tests
4. Run the test suite: `./tests/test-runner.sh`
5. Submit a pull request

### Adding New Tools

1. Create module in `modules/` directory
2. Follow existing patterns for version detection and installation
3. Add configuration entries
4. Update documentation (including README, ARCHITECTURE, CHANGELOG)
5. Add tests

## 📄 License

MIT License - see LICENSE file for details.

## 🔗 Links

- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Changelog](CHANGELOG.md)
- [Issue Tracker](https://github.com/yourusername/insight-dev-bootstrap/issues)
- [Contributing Guidelines](CONTRIBUTING.md)

## 📞 Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Security**: security@yourcompany.com

---

**Version**: 1.0.0  
**Last Updated**: October 2025  
**Maintainer**: Development Infrastructure Team