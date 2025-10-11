#!/usr/bin/env bash
# =====================================================================
# InSight Dev Bootstrap (Linux, Non-GUI)
# Version: 0.9.0 (MVP)
# Purpose:
#   • Detect distro/arch; install CLI dev tools w/ versions & PATH checks
#   • System-wide when run as root; otherwise installs to $HOME/.local/bin
#   • Non-GUI tools only: git, curl prereqs, Docker Engine, kubectl, helm,
#     Terraform, Packer, Vault, AWS CLI v2, Google Cloud SDK, pyenv (optional)
#   • Latest stable for vendor tools (HashiCorp, kubectl, helm)
#   • Final status report: Name | Local | Latest | OnPath | Where
# =====================================================================

set -euo pipefail
IFS=$'\n\t'

# ---------- UI ----------
cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }

title(){ cyan "\n=== $* ==="; }
info() { green "[INFO] $*"; }
warn() { yellow "[WARN] $*"; }
err()  { red   "[ERR ] $*"; }

# ---------- Flags / scope ----------
USER_MODE=0
if [[ "${1:-}" == "--user" ]]; then USER_MODE=1; fi

IS_ROOT=0
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then IS_ROOT=1; fi

if [[ $USER_MODE -eq 0 && $IS_ROOT -ne 1 ]]; then
  warn "Not running as root; switching to user-scope installs (~/.local/bin). Use sudo for system-wide."
  USER_MODE=1
fi

if [[ $USER_MODE -eq 1 ]]; then
  PREFIX="${HOME}/.local"
  BIN_DIR="${PREFIX}/bin"
  OPT_DIR="${HOME}/.devtools"
  PROFILE_RC="${HOME}/.bashrc"
else
  PREFIX="/usr/local"
  BIN_DIR="${PREFIX}/bin"
  OPT_DIR="/opt/devtools"
  PROFILE_RC="/etc/profile.d/devtools-path.sh"
fi

mkdir -p "$BIN_DIR" "$OPT_DIR"

# ---------- Detect OS / Distro / PM ----------
title "Detecting Linux Environment"
OS=$(uname -s)
ARCH=$(uname -m)  # x86_64, aarch64, armv7l...
info "Kernel: $OS  Arch: $ARCH"

# map arch for vendor assets
case "$ARCH" in
  x86_64)  HC_ARCH="amd64"; K8S_ARCH="amd64"; HELM_ARCH="amd64"; AWS_ARCH="x86_64";;
  aarch64) HC_ARCH="arm64"; K8S_ARCH="arm64"; HELM_ARCH="arm64"; AWS_ARCH="aarch64";;
  armv7l)  HC_ARCH="arm";   K8S_ARCH="arm";   HELM_ARCH="arm";   AWS_ARCH="armv7l";;
  *)       HC_ARCH="amd64"; K8S_ARCH="amd64"; HELM_ARCH="amd64"; AWS_ARCH="x86_64"; warn "Unrecognized arch '$ARCH' → defaulting to amd64/x86_64";;
esac

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO_ID="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
else
  DISTRO_ID="unknown"
  DISTRO_LIKE=""
fi
info "Distro: ${DISTRO_ID} (like: ${DISTRO_LIKE})"

PKG=""
if command -v apt-get >/dev/null 2>&1; then
  PKG="apt";   UPDATE="apt-get update -y"; INSTALL="apt-get install -y"
elif command -v dnf >/dev/null 2>&1; then
  PKG="dnf";   UPDATE="dnf -y makecache";  INSTALL="dnf install -y"
elif command -v yum >/dev/null 2>&1; then
  PKG="yum";   UPDATE="yum -y makecache";  INSTALL="yum install -y"
elif command -v zypper >/dev/null 2>&1; then
  PKG="zypper";UPDATE="zypper -n refresh"; INSTALL="zypper -n install --no-confirm"
elif command -v pacman >/dev/null 2>&1; then
  PKG="pacman";UPDATE="pacman -Sy --noconfirm"; INSTALL="pacman -S --noconfirm --needed"
else
  err "Unsupported distro: no known package manager found"; exit 1
fi
info "Package manager: $PKG"

# ---------- PATH ensure ----------
ensure_path() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0;;
    *) export PATH="$dir:$PATH";;
  esac

  if [[ $USER_MODE -eq 1 ]]; then
    if ! grep -qs "$dir" "$PROFILE_RC" 2>/dev/null; then
      echo "export PATH=\"$dir:\$PATH\"" >> "$PROFILE_RC"
    fi
  else
    # system-wide profile snippet
    echo "export PATH=\"$dir:\$PATH\"" > "$PROFILE_RC"
  fi
}

ensure_path "$BIN_DIR"

# ---------- Baseline packages ----------
title "Installing Baseline Packages ($PKG)"
$UPDATE || true
case "$PKG" in
  apt)     $INSTALL ca-certificates curl wget git jq unzip tar xz-utils gnupg lsb-release;;
  dnf|yum) $INSTALL ca-certificates curl wget git jq unzip tar xz gzip gnupg2 redhat-lsb-core || true;;
  zypper)  $INSTALL ca-certificates curl wget git jq unzip tar xz gzip gpg2 lsb-release || true;;
  pacman)  $INSTALL ca-certificates curl wget git jq unzip tar xz gnupg lsb-release || true;;
esac

# ---------- Helpers ----------
# where-like resolver
where_cmd() {
  local name="$1"
  command -v "$name" 2>/dev/null || true
}

# version capture (with timeout)
run_cap() {
  local exe="$1"; shift
  local seconds="${TOOL_TIMEOUT:-15}"
  timeout "$seconds" "$exe" "$@" 2>/dev/null || true
}

get_local_ver() {
  local cmd="$1" args="$2" regex="$3"
  local path
  path=$(where_cmd "$cmd")
  [[ -z "$path" ]] && echo "" && return 0
  local out
  out=$(run_cap "$path" $args)
  [[ "$out" =~ $regex ]] && echo "${BASH_REMATCH[0]}" || echo ""
}

get_latest_hashicorp() {
  local product="$1"
  local url="https://releases.hashicorp.com/${product}/index.json"
  local ver
  ver=$(curl -fsSL -H 'User-Agent: DevBootstrap' "$url" | jq -r '.versions | keys[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)
  [[ -n "$ver" ]] && echo "$ver" || echo ""
}

get_latest_kubectl() {
  local v
  v=$(curl -fsSL https://dl.k8s.io/release/stable.txt | sed 's/^v//' || true)
  echo "$v"
}

get_latest_helm() {
  local v
  v=$(curl -fsSL -H 'User-Agent: DevBootstrap' https://api.github.com/repos/helm/helm/releases/latest | jq -r '.tag_name' | sed 's/^v//' || true)
  [[ -n "$v" ]] && echo "$v" || echo ""
}

dl() { curl -fsSL --retry 3 --retry-delay 1 -o "$2" "$1"; }
install_bin() {
  local src="$1" dst="$2"
  install -m 0755 "$src" "$dst"
}

# Track results
RESULTS=() # lines: "Name|Local|Latest|OnPath|Where"

record_result() {
  local name="$1" localv="$2" latest="$3" onpath="$4" where="$5"
  RESULTS+=("${name}|${localv}|${latest}|${onpath}|${where}")
}

# ---------- Installers ----------
install_hashicorp() {
  local name="$1" bin="$1" regex='\d+(\.\d+)+'
  local latest zip tmp
  latest=$(get_latest_hashicorp "$name")
  if [[ -z "$latest" ]]; then warn "Cannot resolve latest for $name"; latest=""; fi
  local current; current=$(get_local_ver "$bin" "version" "$regex")

  if [[ -n "$current" ]]; then
    info "$name already installed ($current)"
  else
    title "$name → Install"
    zip="${OPT_DIR}/${name}_${latest}_linux_${HC_ARCH}.zip"
    dl "https://releases.hashicorp.com/${name}/${latest}/${name}_${latest}_linux_${HC_ARCH}.zip" "$zip"
    tmp="${OPT_DIR}/${name}-${latest}"
    rm -rf "$tmp"; mkdir -p "$tmp"
    unzip -o "$zip" -d "$tmp" >/dev/null
    install_bin "$tmp/${name}" "${BIN_DIR}/${name}"
    rm -rf "$tmp"
  fi

  ensure_path "$BIN_DIR"
  local where current2
  where=$(where_cmd "$bin")
  current2=$(get_local_ver "$bin" "version" "$regex")
  record_result "$(tr '[:lower:]' '[:upper:]' <<< ${name:0:1})${name:1}" "$current2" "$latest" "$([[ -n "$where" ]] && echo true || echo false)" "$where"
}

install_kubectl() {
  local regex='\d+(\.\d+)+'
  local latest current where
  latest=$(get_latest_kubectl)
  current=$(get_local_ver "kubectl" "version --client --short" "$regex")
  if [[ -z "$current" ]]; then
    title "kubectl → Install"
    local out="${BIN_DIR}/kubectl"
    dl "https://dl.k8s.io/release/v${latest}/bin/linux/${K8S_ARCH}/kubectl" "$out"
    chmod +x "$out"
  else
    info "kubectl already installed ($current)"
  fi
  ensure_path "$BIN_DIR"
  where=$(where_cmd kubectl)
  current=$(get_local_ver "kubectl" "version --client --short" "$regex")
  record_result "kubectl" "$current" "$latest" "$([[ -n "$where" ]] && echo true || echo false)" "$where"
}

install_helm() {
  local regex='\d+(\.\d+)+'
  local latest current where
  latest=$(get_latest_helm)
  current=$(get_local_ver "helm" "version --short" "$regex")
  if [[ -z "$current" ]]; then
    title "helm → Install"
    local tgz="${OPT_DIR}/helm-v${latest}-linux-${HELM_ARCH}.tar.gz"
    dl "https://get.helm.sh/helm-v${latest}-linux-${HELM_ARCH}.tar.gz" "$tgz"
    local tmp="${OPT_DIR}/helm-${latest}"
    rm -rf "$tmp"; mkdir -p "$tmp"
    tar -xzf "$tgz" -C "$tmp"
    install_bin "$tmp/linux-${HELM_ARCH}/helm" "${BIN_DIR}/helm"
  else
    info "helm already installed ($current)"
  fi
  ensure_path "$BIN_DIR"
  where=$(where_cmd helm)
  current=$(get_local_ver "helm" "version --short" "$regex")
  record_result "helm" "$current" "$latest" "$([[ -n "$where" ]] && echo true || echo false)" "$where"
}

install_awscli() {
  local regex='\d+(\.\d+)+'
  local current where
  current=$(get_local_ver "aws" "--version" "$regex")
  if [[ -z "$current" ]]; then
    title "AWS CLI v2 → Install"
    local zip="${OPT_DIR}/awscli-linux-${AWS_ARCH}.zip"
    dl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" "$zip"
    local tmp="${OPT_DIR}/awscli"
    rm -rf "$tmp"; mkdir -p "$tmp"
    unzip -q "$zip" -d "$tmp"
    if [[ $USER_MODE -eq 1 ]]; then
      "${tmp}/aws/install" --update -i "${OPT_DIR}/aws-cli" -b "${BIN_DIR}" >/dev/null
    else
      "${tmp}/aws/install" --update >/dev/null
    fi
  else
    info "AWS CLI v2 already installed ($current)"
  fi
  ensure_path "$BIN_DIR"
  where=$(where_cmd aws)
  current=$(get_local_ver "aws" "--version" "$regex")
  record_result "AWS CLI v2" "$current" "" "$([[ -n "$where" ]] && echo true || echo false)" "$where"
}

install_gcloud() {
  local regex='\d+(\.\d+)+'
  local current where
  current=$(get_local_ver "gcloud" "--version" "$regex")
  if [[ -z "$current" ]]; then
    title "Google Cloud SDK → Install"
    local tgz="${OPT_DIR}/google-cloud-sdk.tar.gz"
    dl "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${HELM_ARCH}.tar.gz" "$tgz" || true
    if [[ ! -s "$tgz" ]]; then
      # Fallback universal
      dl "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz" "$tgz"
    fi
    local dir="${OPT_DIR}/google-cloud-sdk"
    rm -rf "$dir"; mkdir -p "$OPT_DIR"
    tar -xzf "$tgz" -C "$OPT_DIR"
    if [[ $USER_MODE -eq 1 ]]; then
      "${dir}/install.sh" --quiet --usage-reporting=false --command-completion=true --path-update=true >/dev/null || true
      ensure_path "${dir}/bin"
    else
      "${dir}/install.sh" --quiet --usage-reporting=false --command-completion=true --path-update=true >/dev/null || true
      ensure_path "${dir}/bin"
    fi
  else
    info "Google Cloud SDK already installed ($current)"
  fi
  where=$(where_cmd gcloud)
  current=$(get_local_ver "gcloud" "--version" "$regex")
  record_result "Google Cloud SDK" "$current" "" "$([[ -n "$where" ]] && echo true || echo false)" "$where"
}

install_docker_engine() {
  local current where
  current=$(get_local_ver "docker" "--version" '\d+(\.\d+)+')
  if [[ -z "$current" ]]; then
    title "Docker Engine (server + CLI) → Install"
    if [[ "$PKG" == "apt" ]]; then
      install -m 0755 -d /etc/apt/keyrings || true
      curl -fsSL https://download.docker.com/linux/"${DISTRO_ID:-ubuntu}"/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || true
      chmod a+r /etc/apt/keyrings/docker.gpg || true
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID:-ubuntu} \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list || true
      apt-get update -y || true
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    elif [[ "$PKG" == "dnf" || "$PKG" == "yum" ]]; then
      curl -fsSL https://get.docker.com | sh
    elif [[ "$PKG" == "zypper" ]]; then
      curl -fsSL https://get.docker.com | sh
    elif [[ "$PKG" == "pacman" ]]; then
      pacman -Sy --noconfirm docker || true
      systemctl enable --now docker || true
    fi
    if [[ $IS_ROOT -ne 1 ]]; then
      warn "To use docker as non-root: sudo usermod -aG docker $USER && re-login"
    fi
  else
    info "Docker already installed ($current)"
  fi
  ensure_path "$BIN_DIR"
  where=$(where_cmd docker)
  current=$(get_local_ver "docker" "--version" '\d+(\.\d+)+')
  record_result "Docker Engine" "$current" "" "$([[ -n "$where" ]] && echo true || echo false)" "$where"
}

install_pyenv() {
  local where
  where=$(where_cmd pyenv)
  if [[ -z "$where" ]]; then
    title "pyenv (user) → Install"
    # Always user-scope for pyenv
    curl -fsSL https://pyenv.run | bash
    # ensure shims on PATH
    ensure_path "$HOME/.pyenv/bin"
    if ! grep -qs 'pyenv init' "$PROFILE_RC" 2>/dev/null; then
      {
        echo 'export PYENV_ROOT="$HOME/.pyenv"'
        echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
        echo 'eval "$(pyenv init -)"'
      } >> "$PROFILE_RC"
    fi
  else
    info "pyenv already installed ($where)"
  fi
  where=$(where_cmd pyenv)
  local v; v=$(get_local_ver "pyenv" "--version" '\d+(\.\d+)+')
  record_result "pyenv" "$v" "" "$([[ -n "$where" ]] && echo true || echo false)" "$where"
}

# ---------- Catalog execution ----------
title "Installing System Tools"
install_docker_engine
install_kubectl
install_helm
install_hashicorp "terraform"
install_hashicorp "packer"
install_hashicorp "vault"
install_awscli
install_gcloud
install_pyenv

# ---------- Post: Status ----------
title "Post-Install Status"
printf "%-18s %-12s %-10s %-6s %s\n" "Name" "Local" "Latest" "PATH?" "Where"
printf "%-18s %-12s %-10s %-6s %s\n" "----" "-----" "------" "-----" "-----"
for line in "${RESULTS[@]}"; do
  IFS='|' read -r n l s p w <<<"$line"
  printf "%-18s %-12s %-10s %-6s %s\n" "$n" "${l:-"-"}" "${s:-"-"}" "$p" "${w:-"-"}"
done

# Write reports into current dir
STAMP=$(date +%Y%m%d_%H%M%S)
CSV="dev_setup_status_${STAMP}.csv"
JSON="dev_setup_status_${STAMP}.json"
TXT="dev_setup_log_${STAMP}.txt"

{
  echo "Name,Local,Latest,OnPath,Where"
  for line in "${RESULTS[@]}"; do
    IFS='|' read -r n l s p w <<<"$line"
    echo "\"$n\",\"${l}\",\"${s}\",\"${p}\",\"${w}\""
  done
} > "$CSV"

# minimal JSON
{
  echo "{"
  echo "  \"runAt\": \"$(date -Iseconds)\","
  echo "  \"arch\": \"${ARCH}\","
  echo "  \"distro\": \"${DISTRO_ID}\","
  echo "  \"binDir\": \"${BIN_DIR}\","
  echo "  \"tools\": ["
  first=1
  for line in "${RESULTS[@]}"; do
    IFS='|' read -r n l s p w <<<"$line"
    [[ $first -eq 0 ]] && echo "    ,"
    echo "    {\"name\": \"${n}\", \"local\": \"${l}\", \"latest\": \"${s}\", \"onPath\": ${p}, \"where\": \"${w}\"}"
    first=0
  done
  echo "  ]"
  echo "}"
} > "$JSON"

{
  echo "=== InSight Dev Bootstrap (Linux, Non-GUI) v0.9.0 ==="
  echo "Ran at: $(date -Iseconds)"
  echo "Arch: ${ARCH}  Distro: ${DISTRO_ID}"
  echo "BIN_DIR: ${BIN_DIR}"
  echo
  column -t -s' ' < <(
    printf "%-18s %-12s %-10s %-6s %s\n" "Name" "Local" "Latest" "PATH?" "Where"
    printf "%-18s %-12s %-10s %-6s %s\n" "----" "-----" "------" "-----" "-----"
    for line in "${RESULTS[@]}"; do
      IFS='|' read -r n l s p w <<<"$line"
      printf "%-18s %-12s %-10s %-6s %s\n" "$n" "${l:-"-"}" "${s:-"-"}" "$p" "${w:-"-"}"
    done
  )
} > "$TXT"

info "Status CSV  → $CSV"
info "Status JSON → $JSON"
info "Log         → $TXT"
