# Architecture Documentation

## Overview

The InSight Dev Bootstrap is designed as a modular, enterprise-ready development environment setup tool that provides automated installation and management of CLI development tools across Linux distributions.

## Design Principles

### 1. Modularity
- **Separation of Concerns**: Core functionality separated from tool-specific logic
- **Pluggable Architecture**: Easy addition of new tools and categories
- **Configuration-Driven**: Behavior controlled via YAML configuration files
- **Library-Based**: Reusable functions in shared libraries

### 2. Enterprise Readiness
- **Security First**: Signature verification, audit logging, compliance reporting
- **Scalability**: Support for bulk deployments and CI/CD integration
- **Maintainability**: Clear structure, comprehensive testing, documentation
- **Reliability**: Robust error handling, retry mechanisms, rollback capabilities

### 3. Cross-Platform Compatibility
- **Distribution Agnostic**: Abstracted package manager interface
- **Architecture Aware**: Native binary selection for x86_64, aarch64, armv7l
- **Environment Flexible**: Root and user-mode operation with appropriate paths

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    InSight Dev Bootstrap                        │
├─────────────────────────────────────────────────────────────────┤
│  CLI Interface (dev-environment-setup.sh)                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Argument Parser │  │ Config Loader   │  │ Mode Selector   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Core Libraries (lib/)                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ common.sh       │  │ distro.sh       │  │ installer.sh    │ │
│  │ • Utilities     │  │ • OS Detection  │  │ • Install Logic │ │
│  │ • Logging       │  │ • Pkg Mgr      │  │ • Path Mgmt     │ │
│  │ • Validation    │  │ • Arch Map      │  │ • Verification  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │ reporter.sh     │  │ security.sh     │                      │
│  │ • Status Report │  │ • Signature Ver │                      │
│  │ • Multi Format  │  │ • Checksum Val  │                      │
│  │ • Compliance    │  │ • Audit Log     │                      │
│  └─────────────────┘  └─────────────────┘                      │
├─────────────────────────────────────────────────────────────────┤
│  Tool Modules (modules/)                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ containers.sh   │  │ kubernetes.sh   │  │ hashicorp.sh    │ │
│  │ • Docker Engine │  │ • kubectl       │  │ • Terraform     │ │
│  │ • containerd    │  │ • helm          │  │ • Packer        │ │
│  │ • Podman        │  │ • k9s           │  │ • Vault         │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │ cloud.sh        │  │ devtools.sh     │                      │
│  │ • AWS CLI       │  │ • pyenv         │                      │
│  │ • Google Cloud  │  │ • nvm           │                      │
│  │ • Azure CLI     │  │ • rbenv         │                      │
│  │                 │  │ • PowerShell    │                      │
│  │                 │  │ • git           │                      │
│  │                 │  │ • jq            │                      │
│  └─────────────────┘  └─────────────────┘                      │
├─────────────────────────────────────────────────────────────────┤
│  Configuration System (config/)                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ default.yml     │  │ enterprise.yml  │  │ minimal.yml     │ │
│  │ • Standard Set  │  │ • Corp Policy   │  │ • Basic Tools   │ │
│  │ • Latest Ver    │  │ • Security Req  │  │ • Quick Setup   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. CLI Interface (`dev-environment-setup.sh`)

**Responsibilities:**
- Command-line argument parsing and validation
- Configuration file loading and merging
- Execution mode selection (install/check/dry-run)
- High-level orchestration of installation workflow

**Key Features:**
- Argument validation with help system
- Configuration precedence handling
- Error code standardization
- Signal handling for graceful shutdown

### 2. Core Libraries (`lib/`)

#### **common.sh**
```bash
# Core utilities used across all modules
- Logging functions (info, warn, error, debug)
- String manipulation utilities
- Network helpers (download, retry)
- File system operations
- Environment variable management
```

#### **distro.sh**
```bash
# Operating system and distribution detection
- OS identification (/etc/os-release parsing)
- Architecture mapping (x86_64 → amd64)
- Package manager detection and abstraction
- Distribution-specific customizations
```

#### **installer.sh**
```bash
# Installation orchestration and management
- Download and verification pipeline
- Binary installation with permissions
- PATH management and persistence
- Version comparison and upgrade logic
- Rollback and cleanup operations
```

#### **reporter.sh**
```bash
# Status reporting and output formatting
- Multi-format output (CSV, JSON, TXT)
- Progress tracking and display
- Compliance report generation
- Audit trail maintenance
```

#### **security.sh**
```bash
# Security verification and audit functions
- GPG signature verification
- Checksum validation (SHA256, SHA512)
- Security policy enforcement
- Audit logging for compliance
```

### 3. Tool Modules (`modules/`)

Each module follows a standard interface:

```bash
# Module interface contract
module_check()      # Check if tools are installed
module_install()    # Install tools in category  
module_upgrade()    # Upgrade tools to latest
module_verify()     # Verify installation integrity
module_remove()     # Uninstall tools (if supported)
```

#### **containers.sh**
- Docker Engine with repository setup
- containerd runtime
- Podman (rootless containers)
- Container runtime security configuration

#### **kubernetes.sh**  
- kubectl (official Kubernetes CLI)
- helm (package manager)
- k9s (cluster management)
- kubeconfig management

#### **hashicorp.sh**
- Terraform (infrastructure as code)
- Packer (image building)
- Vault (secrets management)
- Consul (service mesh)

#### **cloud.sh**
- AWS CLI v2 with profiles
- Google Cloud SDK
- Azure CLI
- Cloud provider authentication setup

#### **devtools.sh**
- pyenv (Python version management)
- nvm (Node.js version management)
- rbenv (Ruby version management)
- PowerShell
- git
- jq
- Development language runtimes

## Configuration System

### Configuration Hierarchy
```
1. Command-line arguments (highest priority)
2. Environment variables  
3. User configuration file (~/.config/devtools.yml)
4. System configuration (/etc/devtools/config.yml)
5. Default configuration (config/default.yml)
```

### Configuration Schema
```yaml
# Tool selection and versioning
tools:
  categories:
    - containers
    - kubernetes
    - hashicorp
  
  individual:
    - docker
    - kubectl
    - terraform
    
  versions:
    terraform: "1.5.0"
    kubectl: "latest"

# Installation preferences  
installation:
  mode: "system"          # system | user
  verify_signatures: true
  create_backups: true
  parallel_downloads: 4

# Security policies
security:
  require_signatures: true
  allowed_registries:
    - "releases.hashicorp.com"
    - "github.com"
  checksum_algorithms:
    - "sha256"
    - "sha512"

# Reporting configuration
reporting:
  formats: ["json", "csv"]
  compliance_mode: true
  audit_logging: true
```

## Data Flow

### Installation Workflow
```
1. CLI Parsing → Validate arguments and load configuration
2. Environment Detection → OS, distro, architecture, permissions  
3. Tool Selection → Apply filters and version constraints
4. Pre-flight Checks → Network, dependencies, disk space
5. Security Verification → Signatures, checksums, policies
6. Installation Execution → Download, verify, install, configure
7. Post-install Validation → Test functionality, update PATH
8. Reporting → Generate status reports and audit logs
```

### Dry-run Mode Flow
```
1-4. Same as installation workflow
5. Simulation → Calculate changes without execution
6. Report Generation → Show what would be installed/changed
7. Exit → No modifications made to system
```

## Security Architecture

### Trust Model
- **Signature Verification**: All downloads verified against known public keys
- **Checksum Validation**: Binary integrity checked via SHA256/SHA512
- **Source Validation**: Only official repositories and releases accepted
- **Audit Trail**: All operations logged for security review

### Corporate Integration
- **Proxy Support**: HTTP/HTTPS proxy configuration
- **Certificate Management**: Custom CA certificate handling  
- **Policy Enforcement**: Corporate security policy compliance
- **Compliance Reporting**: Automated security audit reports

## Error Handling Strategy

### Error Classification
```bash
# Exit codes standardization
EXIT_SUCCESS=0          # Successful completion
EXIT_INVALID_ARGS=1     # Invalid command-line arguments  
EXIT_PERMISSION=2       # Insufficient permissions
EXIT_NETWORK=3          # Network connectivity issues
EXIT_VERIFICATION=4     # Security verification failure
EXIT_INSTALLATION=5     # Installation/upgrade failure
EXIT_CONFIGURATION=6    # Configuration file errors
```

### Recovery Mechanisms
- **Automatic Retry**: Network operations with exponential backoff
- **Graceful Degradation**: Continue with available tools if some fail
- **Rollback Support**: Restore previous state on critical failures
- **Cleanup Operations**: Remove partially installed components

## Testing Strategy

### Test Categories
```
Unit Tests (tests/unit/)
├── lib/           # Core library function tests
├── modules/       # Individual tool module tests  
└── config/        # Configuration parsing tests

Integration Tests (tests/integration/)
├── distros/       # Cross-distribution compatibility
├── networks/      # Network failure scenarios
└── security/      # Security verification tests

End-to-End Tests (tests/e2e/)
├── workflows/     # Complete installation workflows
├── upgrades/      # Version upgrade scenarios
└── enterprise/    # Enterprise feature validation
```

### Continuous Integration
- **Matrix Testing**: All supported distributions × architectures
- **Security Scanning**: Static analysis and vulnerability scanning
- **Performance Testing**: Installation time and resource usage
- **Regression Testing**: Version compatibility validation

## Performance Considerations

### Optimization Strategies
- **Parallel Downloads**: Concurrent tool downloads when safe
- **Caching**: Local caching of downloaded binaries  
- **Incremental Updates**: Only update changed tools
- **Dependency Resolution**: Minimize redundant package installations

### Resource Management
- **Disk Space**: Pre-flight checks and cleanup operations
- **Memory Usage**: Streaming downloads for large files
- **Network Bandwidth**: Configurable download concurrency
- **CPU Utilization**: Parallel processing where appropriate

## Extensibility

### Adding New Tools
1. Create module in `modules/` following interface contract
2. Add tool definition to configuration schema (e.g., powershell)
3. Implement version detection and installation logic
4. Add security verification (signatures, checksums)
5. Create unit and integration tests
6. Update documentation (README, ARCHITECTURE, CHANGELOG)

### Adding New Distributions
1. Extend `distro.sh` with new package manager support
2. Add distribution-specific customizations
3. Update baseline package requirements  
4. Test installation workflow thoroughly
5. Add to CI/CD test matrix

### Configuration Extensions
1. Extend YAML schema with new options
2. Update configuration validation logic
3. Implement backward compatibility handling
4. Document new configuration options
5. Add migration utilities for breaking changes

---

This architecture provides a solid foundation for enterprise deployment while maintaining simplicity for individual developers. The modular design enables easy maintenance and extension as new tools and requirements emerge.