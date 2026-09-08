# Changelog

All notable changes to the InSight Dev Bootstrap project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `install` now accepts `--categories` and `--tools` together (union of
  both, deduplicated) instead of `--tools` silently overriding
  `--categories`.
- `ensure_path "$BIN_DIR"` now runs *before* the install loop (and `check`
  now also puts `$BIN_DIR` on PATH for the current process). Previously it
  ran only after every category finished installing, so a tool installed
  earlier in the same run (e.g. kubectl) could fail its own
  post-install verification simply because `$BIN_DIR` wasn't on PATH yet.
- A single failed tool install no longer aborts the entire `install`/
  `upgrade` run. Category installers are now called from a tested (`if
  !`) context, which suspends `set -e` for their full execution (documented
  bash behavior) so one bad package falls through to that module's existing
  failure reporting instead of killing every category queued after it.
- `devtools.sh` was reporting `git`/`jq`/`powershell` as `"installed"` even
  when the install failed and the binary was nowhere to be found (that
  "not yet on PATH, may need a new shell" allowance only makes sense for
  `pyenv`/`nvm`/`rbenv`, which install via shell-rc-modifying scripts).
- `dev-environment-setup-new.sh` renamed to `dev-environment-setup.sh` and its
  `main()` now actually wires up `parse_arguments` → `load_configuration` →
  `load_tool_modules` → `execute_command`. Previously `main()` never called
  any of these; it ran a hardcoded inline "check" loop regardless of which
  subcommand was passed, so `install`, `upgrade`, `remove`, and `list` were
  silently no-ops and every module under `modules/` was dead code.
- Removed the legacy monolithic `dev-environment-setup.sh` (v0.9 script) and
  the ~100-line duplicate/corrupted copy of the old argument parser and
  entrypoint that had been left dead inside the new script.
- `kubernetes.sh`, `hashicorp.sh`, `cloud.sh`, and `devtools.sh` modules now
  implement `_check` and `_upgrade`, matching the interface `containers.sh`
  already had, and their installers now honor `--dry-run` (previously they
  would run real installs even in dry-run mode).
- Fixed a `set -e` bug in `get_local_version` (lib/common.sh) that aborted
  the entire script the moment it checked a tool that wasn't installed —
  this is why `check`/`install` never completed end-to-end before.
- Fixed `(( total++ ))`-style post-increment counters in `reporter.sh`
  aborting the script under `set -e` on their first (zero-valued) increment.
- Fixed modules invoking `$PKG_MGR install -y <pkg>` directly: `-y` isn't a
  valid zypper flag and pacman has no `install` subcommand. Modules now call
  the shared `install_system_packages` helper, which resolves the correct
  per-distro command and already handles dry-run.
- Fixed the same install calls silently no-op'ing on word-splitting: since
  `common.sh` sets `IFS=$'\n\t'` (no space) for safety, a bare
  `$PKG_INSTALL <pkg>` no longer splits into separate arguments. Routing
  through `install_system_packages` (which uses `eval`) sidesteps this.
- Fixed `jq`'s "latest version" lookup pointing at the archived
  `stedolan/jq` repo instead of `jqlang/jq`.
- Fixed a YAML formatting typo (`azure-cli : true`, extra space before the
  colon) in `config/default.yml` that silently excluded azure-cli from
  every install.
- Removed three stray zero-byte files (`--version.hwm`, `--version.pwd`,
  `--version.pwi`) accidentally committed at the repo root.

### Added
- Modular architecture with separated lib/ and modules/ directories
- Configuration system with YAML support
- Dry-run mode (`--dry-run`) for preview operations
- Status-only mode (`--check`) for current state inspection
- Selective installation by categories (`--categories`)
- Individual tool selection (`--tools`)
- Version pinning support (`--versions`)
- Upgrade mode (`--upgrade`) with smart update logic
- Force reinstallation option (`--force`)
- Cryptographic signature verification (`--verify-signatures`)
- Compliance reporting (`--compliance-report`)
- Corporate proxy support
- Enhanced security audit logging
- Comprehensive test suite
- Enterprise configuration templates
- PowerShell support as an optional development tool

### Changed
- Refactored monolithic script into modular components
- Improved error handling with detailed error codes
- Enhanced logging with configurable verbosity levels
- Restructured configuration system for better maintainability
- Updated documentation with comprehensive examples

### Security
- Added GPG signature verification for all downloads
- Implemented checksum validation for binary integrity
- Enhanced audit logging for security compliance
- Added support for corporate security policies

## [0.9.0] - 2025-10-10

### Added
- Initial release of InSight Dev Bootstrap
- Multi-architecture support (x86_64, aarch64, armv7l)
- Cross-distribution Linux compatibility (Ubuntu, RHEL, SUSE, Arch)
- Smart execution mode detection (root vs user)
- Comprehensive tool installation:
  - Docker Engine with repository setup
  - Kubernetes tools (kubectl, helm)
  - HashiCorp stack (Terraform, Packer, Vault)
  - Cloud CLIs (AWS CLI v2, Google Cloud SDK)
  - Python environment (pyenv)
- Version tracking and comparison
- Multiple output formats (CSV, JSON, TXT)
- PATH management and persistence
- Idempotent operation support
- Timeout protection for version checks
- Retry logic for network operations
- Color-coded console output
- Baseline package installation per distribution

### Technical Details
- Bash script with strict error handling (`set -euo pipefail`)
- Architecture-aware binary selection
- Package manager abstraction layer
- Graceful fallback mechanisms
- Session-persistent environment setup

### Known Issues
- Docker post-install requires manual user group configuration
- No cryptographic signature verification
- Limited to latest versions only
- No rollback or uninstall capability
- Fixed tool set with no customization options

### Dependencies
- Bash 4.0+
- curl
- Standard Linux utilities (tar, unzip, gpg)
- Internet connectivity for downloads

### Supported Systems
- **Ubuntu/Debian**: 18.04+ (apt-get)
- **RHEL/CentOS/Fedora**: 7+ (yum/dnf)
- **SUSE/openSUSE**: 15+ (zypper)
- **Arch Linux**: Current (pacman)

### Architecture Support
- x86_64 (Intel/AMD 64-bit)
- aarch64 (ARM 64-bit)
- armv7l (ARM 32-bit)

---

## Release Process

### Version Numbering
- **Major** (X.0.0): Breaking changes, new architecture
- **Minor** (0.X.0): New features, tool additions
- **Patch** (0.0.X): Bug fixes, security updates

### Release Checklist
- [ ] Update version in main script
- [ ] Update CHANGELOG.md with new features
- [ ] Run complete test suite
- [ ] Test on all supported distributions
- [ ] Update documentation
- [ ] Create GitHub release
- [ ] Update package repositories

### Security Releases
Security updates are released immediately and may not follow normal versioning if critical.

### Backward Compatibility
- Configuration file format changes trigger minor version bump
- CLI argument changes trigger major version bump
- Internal API changes do not affect versioning

---

## Migration Guides

### From 0.9.x to 1.0.0
The 1.0.0 release introduces breaking changes in configuration and command-line interface.

#### Configuration Migration
```bash
# Old format (0.9.x)
./dev-environment-setup.sh --user

# New format (1.0.0+)
./dev-environment-setup.sh --mode user
```

#### New Features in 1.0.0
- Modular architecture
- Configuration files
- Selective installation
- Enhanced security

#### Deprecated Features
- None in 1.0.0 (first stable release)

---

## Contributors

### Core Team
- Development Infrastructure Team
- Security Team
- Quality Assurance Team

### Special Thanks
- Community contributors
- Beta testers
- Documentation reviewers

---

## Support Matrix

| Version | Support Status | End of Life |
|---------|---------------|-------------|
| 1.0.x   | Active        | TBD         |
| 0.9.x   | Maintenance   | 2026-04-10  |

### Support Policy
- **Active**: Full feature development and security updates
- **Maintenance**: Security updates and critical bug fixes only
- **End of Life**: No updates provided

---

*For more information, see our [Contributing Guidelines](CONTRIBUTING.md) and [Security Policy](SECURITY.md).*