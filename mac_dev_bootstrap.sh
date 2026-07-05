#!/usr/bin/env bash
# mac_dev_bootstrap.sh
# Apple Silicon macOS developer bootstrap, mise-first, shell-hook-free.
#
# Main choices:
#   - Homebrew: system packages, build dependencies, GUI apps, libpq client fallback.
#   - mise: Ruby, Node.js, and PostgreSQL versions.
#   - mise shims: added to PATH; no `eval "$(mise activate ...)"` in this script.
#   - pg-project helper: per-repo PostgreSQL version + data dir + port.
#   - Redis: Homebrew service.
#   - pgAdmin4: GUI PostgreSQL admin.
#   - GitHub CLI: auth + SSH key upload via `gh ssh-key add`.
#
# Usage:
#   chmod +x mac_dev_bootstrap.sh
#   ./mac_dev_bootstrap.sh --gh_email=you@example.com
#
# Common variants:
#   ./mac_dev_bootstrap.sh --gh_email=you@example.com --start-services
#   ./mac_dev_bootstrap.sh --gh_email=you@example.com --postgres-version 18
#   ./mac_dev_bootstrap.sh --gh_email=you@example.com --ruby-version latest --node-version latest
#   ./mac_dev_bootstrap.sh --gh_email=you@example.com --ssh-only --regen-ssh
#   ./mac_dev_bootstrap.sh --skip-ssh
#
# Per-project PostgreSQL after install:
#   cd ~/src/my-rails-app
#   pg-project init 18
#   pg-project start
#   pg-project url
#
# Notes:
#   - Homebrew install uses NONINTERACTIVE=1 where supported.
#   - Homebrew shellenv is added to ~/.zprofile and ~/.zshrc automatically.
#   - mise shell hooks are deliberately NOT used. Shims are used instead.
#   - SSH key generation requires --gh_email=you@example.com or BOOTSTRAP_GH_EMAIL.
#   - Public SSH key is uploaded through GitHub CLI.
#   - Public/private SSH keys are not printed.
#   - Safe to rerun: formula/cask installs are skipped when present, shell blocks are replaced, SSH keys are reused unless --regen-ssh is passed.

set -Eeuo pipefail
IFS=$'\n\t'

BOOTSTRAP_VERSION="2026-07-05-shims-safe"

GH_EMAIL="${BOOTSTRAP_GH_EMAIL:-}"

SSH_KEY_NAME="${SSH_KEY_NAME:-id_ed25519_github}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/$SSH_KEY_NAME}"
SSH_TITLE="${SSH_TITLE:-}"

RUBY_VERSION="${RUBY_VERSION:-3.4.9}"
NODE_VERSION="${NODE_VERSION:-latest}"
POSTGRES_VERSION="${POSTGRES_VERSION:-18}"

SSH_ONLY=0
REGEN_SSH=0
SKIP_SSH=0
NO_GUI=0
NO_OPEN_APPS=0
WITH_XCODE_APP=0
WITH_ROSETTA=0
WITH_ADDONS=0
START_SERVICES=0
SKIP_RUBY=0
SKIP_NODE=0
SKIP_POSTGRES_MISE=0
SKIP_AI_CLIS=0
SKIP_GH_SSH_UPLOAD=0
FORCE_GIT_EMAIL=0
NON_INTERACTIVE=0

usage() {
  cat <<USAGE
mac_dev_bootstrap.sh v${BOOTSTRAP_VERSION}

Usage:
  ./mac_dev_bootstrap.sh [options]

Main options:
  --gh_email=EMAIL          Required when generating SSH keys. Used as SSH key comment.
                            Alias: --gh-email=EMAIL
  --ssh-only                Only generate/regenerate SSH key and upload it to GitHub with gh.
  --skip-ssh                Do not generate/configure/upload SSH key.
  --regen-ssh               Backup and regenerate the configured SSH key.
  --skip-gh-ssh-upload      Generate local SSH key but do not upload it through gh.

Runtime options:
  --ruby-version X          Ruby version installed through mise. Default: ${RUBY_VERSION}
                            Examples: 3.4.9, latest
  --node-version X          Node.js version installed through mise. Default: ${NODE_VERSION}
                            Examples: latest, 24, 22
  --postgres-version X      PostgreSQL version installed through mise. Default: ${POSTGRES_VERSION}
                            Examples: 18, 17, 16
  --skip-ruby               Do not install Ruby through mise.
  --skip-node               Do not install Node.js through mise.
  --skip-postgres-mise      Do not install PostgreSQL through mise.
  --skip-ai-clis            Do not install Claude/Codex npm CLIs.

Install options:
  --no-gui                  Skip GUI apps/casks.
  --no-open-apps            Do not open GUI apps after installation.
  --with-xcode-app          Try to install/update full Xcode through the App Store CLI.
                            Command Line Tools are always handled.
  --with-rosetta            Install Rosetta 2. Usually not needed on native arm64.
  --with-addons             Install extra quality/security/productivity tools.
  --start-services          Start Redis after install. PostgreSQL is project-managed by pg-project.
  --non-interactive         Avoid optional prompts where possible.

Git options:
  --force-git-email         If --gh_email is passed, overwrite existing global git user.email.

Other:
  -h, --help                Show this help.

Environment overrides:
  BOOTSTRAP_GH_EMAIL        SSH key email/comment. Required for SSH key generation if --gh_email is not passed.
  SSH_KEY_NAME              SSH key filename. Default: ${SSH_KEY_NAME}
  SSH_KEY_PATH              Full SSH private key path. Default: ${SSH_KEY_PATH}
  SSH_TITLE                 GitHub SSH key title. Default: auto-generated.
  RUBY_VERSION              Default Ruby version when --ruby-version is not passed.
  NODE_VERSION              Default Node.js version when --node-version is not passed.
  POSTGRES_VERSION          Default PostgreSQL version when --postgres-version is not passed.

Examples:
  ./mac_dev_bootstrap.sh --gh_email=you@example.com
  ./mac_dev_bootstrap.sh --gh_email=you@example.com --with-addons --start-services
  ./mac_dev_bootstrap.sh --gh_email=you@example.com --force-git-email
  ./mac_dev_bootstrap.sh --gh_email=you@example.com --ssh-only --regen-ssh
  ./mac_dev_bootstrap.sh --skip-ssh
USAGE
}

log()  { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m⚠\033[0m %s\n" "$*" >&2; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

pause_for_user() {
  local message="$1"
  if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
    printf "\n%s\n" "$message"
    read -r -p "Press Enter to continue..."
  else
    warn "$message"
  fi
}

append_once() {
  local file="$1"
  local line="$2"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if ! grep -Fqs "$line" "$file"; then
    printf "\n%s\n" "$line" >> "$file"
  fi
}

remove_exact_line() {
  local file="$1"
  local line="$2"

  [[ -f "$file" ]] || return 0

  local tmp
  tmp="$(mktemp)"
  grep -Fvx "$line" "$file" > "$tmp" || true
  mv "$tmp" "$file"
}

remove_managed_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"

  [[ -f "$file" ]] || return 0

  local tmp
  tmp="$(mktemp)"

  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    skip != 1 { print }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

replace_managed_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local block="$4"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  remove_managed_block "$file" "$start_marker" "$end_marker"
  printf "\n%s\n" "$block" >> "$file"
}

prepend_path_once() {
  local file="$1"
  local dir="$2"
  [[ -n "$dir" ]] || return 0
  append_once "$file" "export PATH=\"${dir}:\$PATH\""
}

run_or_warn() {
  "$@" || warn "Command failed but bootstrap will continue: $*"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gh_email=*)
        GH_EMAIL="${1#--gh_email=}"
        ;;
      --gh-email=*)
        GH_EMAIL="${1#--gh-email=}"
        ;;
      --ssh-only) SSH_ONLY=1 ;;
      --skip-ssh) SKIP_SSH=1 ;;
      --regen-ssh|--regenerate-ssh) REGEN_SSH=1 ;;
      --ruby-version)
        shift
        [[ $# -gt 0 ]] || die "--ruby-version requires a value"
        RUBY_VERSION="$1"
        ;;
      --node-version)
        shift
        [[ $# -gt 0 ]] || die "--node-version requires a value"
        NODE_VERSION="$1"
        ;;
      --postgres-version)
        shift
        [[ $# -gt 0 ]] || die "--postgres-version requires a value"
        POSTGRES_VERSION="$1"
        ;;
      --skip-ruby) SKIP_RUBY=1 ;;
      --skip-node) SKIP_NODE=1 ;;
      --skip-postgres-mise) SKIP_POSTGRES_MISE=1 ;;
      --skip-ai-clis) SKIP_AI_CLIS=1 ;;
      --skip-gh-ssh-upload) SKIP_GH_SSH_UPLOAD=1 ;;
      --no-gui) NO_GUI=1 ;;
      --no-open-apps) NO_OPEN_APPS=1 ;;
      --with-xcode-app) WITH_XCODE_APP=1 ;;
      --with-rosetta) WITH_ROSETTA=1 ;;
      --with-addons) WITH_ADDONS=1 ;;
      --start-services) START_SERVICES=1 ;;
      --force-git-email) FORCE_GIT_EMAIL=1 ;;
      --non-interactive) NON_INTERACTIVE=1 ;;
      -h|--help) usage; exit 0 ;;
      *)
        die "Unknown option: $1. Use --help."
        ;;
    esac
    shift
  done
}

ensure_platform() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS only."

  if [[ "$EUID" -eq 0 ]]; then
    die "Do not run this as root. Run as your normal macOS user; sudo will be requested only where needed."
  fi

  local arch
  arch="$(uname -m)"
  if [[ "$arch" != "arm64" ]]; then
    warn "Detected architecture: ${arch}. Script is Apple Silicon-first but should mostly work on Intel."
  else
    ok "Apple Silicon arm64 detected."
  fi
}

install_rosetta_if_requested() {
  [[ "$WITH_ROSETTA" -eq 1 ]] || return 0

  log "Installing Rosetta 2"
  if /usr/bin/pgrep oahd >/dev/null 2>&1; then
    ok "Rosetta appears to be active already."
    return 0
  fi

  sudo softwareupdate --install-rosetta --agree-to-license \
    || warn "Rosetta installation failed or is unsupported in this environment."
}

install_xcode_command_line_tools() {
  log "Checking Xcode Command Line Tools"

  if xcode-select -p >/dev/null 2>&1; then
    ok "Command Line Tools are installed: $(xcode-select -p)"
  else
    warn "Command Line Tools are not installed. macOS will open an installer dialog."
    xcode-select --install || true
    pause_for_user "Complete the Apple installer dialog first. This cannot be fully automated on every macOS version."

    if xcode-select -p >/dev/null 2>&1; then
      ok "Command Line Tools installed."
    else
      warn "Command Line Tools still not detected. Homebrew may trigger Apple’s installer again."
    fi
  fi

  log "Checking for Command Line Tools updates"
  local clt_labels
  clt_labels="$(softwareupdate --list 2>/dev/null | awk -F': ' '/\* Label: Command Line Tools/{print $2}' || true)"

  if [[ -n "$clt_labels" ]]; then
    while IFS= read -r label; do
      [[ -n "$label" ]] || continue
      log "Installing CLT update: $label"
      sudo softwareupdate --install "$label" || warn "Failed to install CLT update: $label"
    done <<< "$clt_labels"
  else
    ok "No Command Line Tools updates found."
  fi

  if have xcodebuild; then
    run_or_warn sudo xcodebuild -license accept
    run_or_warn xcodebuild -runFirstLaunch
  fi
}

install_homebrew() {
  log "Checking Homebrew"

  if have brew; then
    ok "Homebrew already installed: $(brew --version | head -n 1)"
  else
    log "Installing Homebrew non-interactively where Homebrew supports it"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif have brew; then
    eval "$(brew shellenv)"
  else
    die "Homebrew installation completed but brew is not on PATH."
  fi

  local brew_prefix
  brew_prefix="$(brew --prefix)"

  append_once "$HOME/.zprofile" "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
  append_once "$HOME/.zshrc" "eval \"\$(${brew_prefix}/bin/brew shellenv)\""

  eval "$("${brew_prefix}/bin/brew" shellenv)"

  ok "Homebrew prefix: ${brew_prefix}"
  brew update
}

brew_install_formula() {
  local formula="$1"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    ok "Formula already installed: $formula"
  else
    log "Installing formula: $formula"
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "$formula" || warn "Formula failed: $formula"
  fi
}

brew_install_cask() {
  local cask="$1"

  if brew list --cask "$cask" >/dev/null 2>&1; then
    ok "Cask already installed: $cask"
  else
    log "Installing cask: $cask"
    HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask "$cask" || warn "Cask failed: $cask"
  fi
}

install_core_formulae() {
  log "Installing core developer CLI formulae"

  local formulae=(
    git
    git-lfs
    gnupg
    pinentry-mac
    curl
    wget
    openssl@3
    readline
    libyaml
    gmp
    libffi
    autoconf
    automake
    bison
    pkg-config
    cmake
    gcc
    zlib
    ossp-uuid
    icu4c
    jq
    yq
    tree
    ripgrep
    fd
    fzf
    htop
    tmux
    watch
    coreutils
    findutils
    gnu-sed
    grep
    mc
    gh
    awscli
    mise
    mailpit

    # PostgreSQL client/build support.
    # Versioned PostgreSQL server is managed by mise, not Homebrew.
    libpq

    # Redis is simple and stable enough as a Homebrew service.
    redis

    # Rails/media/process helpers.
    vips
    imagemagick
    overmind
    foreman
  )

  local formula
  for formula in "${formulae[@]}"; do
    brew_install_formula "$formula"
  done

  if brew list --formula fzf >/dev/null 2>&1; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc || true
  fi

  configure_build_and_client_paths
  configure_redis_service

  ok "Core formulae processed."
}

configure_build_and_client_paths() {
  log "Configuring build paths, psql client fallback, and PostgreSQL build dependencies"

  local brew_prefix openssl_prefix libpq_prefix readline_prefix zlib_prefix curl_prefix icu_prefix uuid_prefix
  brew_prefix="$(brew --prefix)"
  openssl_prefix="$(brew --prefix openssl@3 2>/dev/null || true)"
  libpq_prefix="$(brew --prefix libpq 2>/dev/null || true)"
  readline_prefix="$(brew --prefix readline 2>/dev/null || true)"
  zlib_prefix="$(brew --prefix zlib 2>/dev/null || true)"
  curl_prefix="$(brew --prefix curl 2>/dev/null || true)"
  icu_prefix="$(brew --prefix icu4c 2>/dev/null || true)"
  uuid_prefix="$(brew --prefix ossp-uuid 2>/dev/null || true)"

  append_once "$HOME/.zshrc" "export HOMEBREW_PREFIX=\"${brew_prefix}\""
  append_once "$HOME/.zprofile" "export HOMEBREW_PREFIX=\"${brew_prefix}\""

  mkdir -p "$HOME/.local/bin"
  prepend_path_once "$HOME/.zshrc" "$HOME/.local/bin"
  prepend_path_once "$HOME/.zprofile" "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  if [[ -n "$libpq_prefix" ]]; then
    prepend_path_once "$HOME/.zshrc" "${libpq_prefix}/bin"
    prepend_path_once "$HOME/.zprofile" "${libpq_prefix}/bin"
    export PATH="${libpq_prefix}/bin:${PATH}"
  fi

  [[ -n "$openssl_prefix" ]] && prepend_path_once "$HOME/.zshrc" "${openssl_prefix}/bin"

  local pkg_config_path_parts=()
  [[ -n "$openssl_prefix" ]] && pkg_config_path_parts+=("${openssl_prefix}/lib/pkgconfig")
  [[ -n "$libpq_prefix" ]] && pkg_config_path_parts+=("${libpq_prefix}/lib/pkgconfig")
  [[ -n "$readline_prefix" ]] && pkg_config_path_parts+=("${readline_prefix}/lib/pkgconfig")
  [[ -n "$zlib_prefix" ]] && pkg_config_path_parts+=("${zlib_prefix}/lib/pkgconfig")
  [[ -n "$curl_prefix" ]] && pkg_config_path_parts+=("${curl_prefix}/lib/pkgconfig")
  [[ -n "$icu_prefix" ]] && pkg_config_path_parts+=("${icu_prefix}/lib/pkgconfig")
  [[ -n "$uuid_prefix" ]] && pkg_config_path_parts+=("${uuid_prefix}/lib/pkgconfig")

  local joined_pkg_config_path
  joined_pkg_config_path="$(IFS=:; echo "${pkg_config_path_parts[*]}")"

  [[ -n "$joined_pkg_config_path" ]] && append_once "$HOME/.zshrc" "export PKG_CONFIG_PATH=\"${joined_pkg_config_path}:\${PKG_CONFIG_PATH:-}\""

  [[ -n "$openssl_prefix" ]] && append_once "$HOME/.zshrc" "export LDFLAGS=\"-L${openssl_prefix}/lib \${LDFLAGS:-}\""
  [[ -n "$openssl_prefix" ]] && append_once "$HOME/.zshrc" "export CPPFLAGS=\"-I${openssl_prefix}/include \${CPPFLAGS:-}\""

  if have psql; then
    ok "psql client visible: $(command -v psql)"
  else
    warn "psql is not visible yet. Restart terminal or run: source ~/.zshrc"
  fi
}

configure_redis_service() {
  log "Configuring Redis"

  if [[ "$START_SERVICES" -eq 1 ]]; then
    if brew services list 2>/dev/null | awk '$1 == "redis" {print $2}' | grep -qx "started"; then
      ok "Redis service already started."
    else
      run_or_warn brew services start redis
    fi
  else
    ok "Redis installed but not started. Start it with: brew services start redis"
  fi
}

configure_mise_shims_only() {
  log "Configuring mise shims only — no shell hooks"

  have mise || die "mise is not installed or is not on PATH."

  local shims_dir="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
  mkdir -p "$shims_dir"

  # Remove older fragile activation added by previous script versions.
  remove_exact_line "$HOME/.zshrc" 'eval "$(mise activate zsh)"'
  remove_exact_line "$HOME/.zprofile" 'eval "$(mise activate zsh)"'

  remove_managed_block "$HOME/.zshrc" '# >>> mise activation: bootstrap managed, nounset-safe >>>' '# <<< mise activation: bootstrap managed, nounset-safe <<<'
  remove_managed_block "$HOME/.zprofile" '# >>> mise activation: bootstrap managed, nounset-safe >>>' '# <<< mise activation: bootstrap managed, nounset-safe <<<'

  local start_marker='# >>> mise shims: bootstrap managed >>>'
  local end_marker='# <<< mise shims: bootstrap managed <<<'
  local block
  block="${start_marker}
# Shell-hook-free mise setup. Safer for scripts, IDEs, and shells using set -u.
export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\"
${end_marker}"

  replace_managed_block "$HOME/.zshrc" "$start_marker" "$end_marker" "$block"
  replace_managed_block "$HOME/.zprofile" "$start_marker" "$end_marker" "$block"

  export PATH="$shims_dir:$PATH"

  ok "mise shims configured: ${shims_dir}"
}

install_mise_runtimes() {
  log "Installing mise-managed runtimes"

  configure_mise_shims_only

  if [[ "$SKIP_RUBY" -eq 0 ]]; then
    install_mise_ruby
  else
    ok "Skipping Ruby because --skip-ruby was used."
  fi

  if [[ "$SKIP_NODE" -eq 0 ]]; then
    install_mise_node
  else
    ok "Skipping Node.js because --skip-node was used."
  fi

  if [[ "$SKIP_POSTGRES_MISE" -eq 0 ]]; then
    install_mise_postgres
  else
    ok "Skipping PostgreSQL mise install because --skip-postgres-mise was used."
  fi

  run_or_warn mise reshim
}

install_mise_ruby() {
  local openssl_prefix
  openssl_prefix="$(brew --prefix openssl@3)"

  log "Installing Ruby ${RUBY_VERSION} through mise"

  export RUBY_CONFIGURE_OPTS="--with-openssl-dir=${openssl_prefix}"
  export LDFLAGS="-L${openssl_prefix}/lib ${LDFLAGS:-}"
  export CPPFLAGS="-I${openssl_prefix}/include ${CPPFLAGS:-}"
  export PKG_CONFIG_PATH="${openssl_prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

  mise use -g "ruby@${RUBY_VERSION}" || warn "mise Ruby install failed for ruby@${RUBY_VERSION}"

  run_or_warn mise exec -- gem update --system
  run_or_warn mise exec -- gem install bundler
}

install_mise_node() {
  log "Installing Node.js ${NODE_VERSION} through mise"

  mise use -g "node@${NODE_VERSION}" || warn "mise Node.js install failed for node@${NODE_VERSION}"

  run_or_warn mise exec -- corepack enable
  run_or_warn mise exec -- corepack prepare pnpm@latest --activate
  run_or_warn mise exec -- corepack prepare yarn@stable --activate
}

install_mise_postgres() {
  log "Installing PostgreSQL ${POSTGRES_VERSION} through mise"

  local brew_prefix openssl_prefix readline_prefix zlib_prefix curl_prefix icu_prefix uuid_prefix
  brew_prefix="$(brew --prefix)"
  openssl_prefix="$(brew --prefix openssl@3 2>/dev/null || true)"
  readline_prefix="$(brew --prefix readline 2>/dev/null || true)"
  zlib_prefix="$(brew --prefix zlib 2>/dev/null || true)"
  curl_prefix="$(brew --prefix curl 2>/dev/null || true)"
  icu_prefix="$(brew --prefix icu4c 2>/dev/null || true)"
  uuid_prefix="$(brew --prefix ossp-uuid 2>/dev/null || true)"

  export HOMEBREW_PREFIX="${brew_prefix}"

  local pkg_config_path_parts=()
  [[ -n "$openssl_prefix" ]] && pkg_config_path_parts+=("${openssl_prefix}/lib/pkgconfig")
  [[ -n "$readline_prefix" ]] && pkg_config_path_parts+=("${readline_prefix}/lib/pkgconfig")
  [[ -n "$zlib_prefix" ]] && pkg_config_path_parts+=("${zlib_prefix}/lib/pkgconfig")
  [[ -n "$curl_prefix" ]] && pkg_config_path_parts+=("${curl_prefix}/lib/pkgconfig")
  [[ -n "$icu_prefix" ]] && pkg_config_path_parts+=("${icu_prefix}/lib/pkgconfig")
  [[ -n "$uuid_prefix" ]] && pkg_config_path_parts+=("${uuid_prefix}/lib/pkgconfig")
  export PKG_CONFIG_PATH="$(IFS=:; echo "${pkg_config_path_parts[*]}"):${PKG_CONFIG_PATH:-}"

  [[ -n "$openssl_prefix" ]] && export LDFLAGS="-L${openssl_prefix}/lib ${LDFLAGS:-}"
  [[ -n "$openssl_prefix" ]] && export CPPFLAGS="-I${openssl_prefix}/include ${CPPFLAGS:-}"

  if ! mise plugins ls 2>/dev/null | awk '{print $1}' | grep -qx "postgres"; then
    run_or_warn mise plugin install postgres https://github.com/mise-plugins/mise-postgres
  fi

  mise use -g "postgres@${POSTGRES_VERSION}" || warn "mise PostgreSQL install failed for postgres@${POSTGRES_VERSION}"

  if mise exec -- psql --version >/dev/null 2>&1; then
    ok "mise PostgreSQL available: $(mise exec -- psql --version)"
  elif have psql; then
    ok "libpq fallback psql available: $(command -v psql)"
  else
    warn "psql not visible after mise PostgreSQL install. Restart terminal and check: psql --version"
  fi
}

create_pg_project_helper() {
  log "Installing pg-project helper"

  mkdir -p "$HOME/.local/bin"

  cat > "$HOME/.local/bin/pg-project" <<'PGPROJECT'
#!/usr/bin/env bash
# pg-project: tiny per-project PostgreSQL helper for mise-managed PostgreSQL.
#
# Usage:
#   pg-project init [version] [port] [db_name]
#   pg-project start
#   pg-project stop
#   pg-project restart
#   pg-project status
#   pg-project psql
#   pg-project url
#   pg-project env

set -Eeuo pipefail
IFS=$'\n\t'

cmd="${1:-help}"
[[ $# -gt 0 ]] && shift || true

project_root="$(pwd)"
project_name="$(basename "$project_root" | tr '. -' '___' | tr -cd '[:alnum:]_')"
state_dir="${PG_PROJECT_STATE_DIR:-$project_root/.dev/postgres}"
pgdata="${PGDATA:-$state_dir/data}"
logfile="$state_dir/postgres.log"
port_file="$state_dir/port"
db_file="$state_dir/db"
version_file="$state_dir/version"

die() { printf "pg-project: %s\n" "$*" >&2; exit 1; }
ok() { printf "✓ %s\n" "$*"; }

default_port() {
  printf "%s" "$project_root" | cksum | awk '{print 5400 + ($1 % 600)}'
}

default_db() {
  printf "%s_development" "$project_name"
}

ensure_mise() {
  command -v mise >/dev/null 2>&1 || die "mise not found"
}

run_mise() {
  ensure_mise
  mise exec -- "$@"
}

read_port() {
  [[ -f "$port_file" ]] && cat "$port_file" || default_port
}

read_db() {
  [[ -f "$db_file" ]] && cat "$db_file" || default_db
}

ensure_initialized() {
  [[ -d "$pgdata" ]] || die "PostgreSQL data dir not initialized. Run: pg-project init 18"
}

rewrite_pg_conf_block() {
  local conf="$pgdata/postgresql.conf"
  local port="$1"
  local tmp
  tmp="$(mktemp)"

  if [[ -f "$conf" ]]; then
    awk '
      /# pg-project begin/ { skip=1; next }
      /# pg-project end/ { skip=0; next }
      skip == 0 { print }
    ' "$conf" > "$tmp"
    mv "$tmp" "$conf"
  fi

  cat >> "$conf" <<EOF

# pg-project begin
port = ${port}
listen_addresses = 'localhost'
# pg-project end
EOF
}

init_project() {
  local version="${1:-18}"
  local port="${2:-$(default_port)}"
  local db="${3:-$(default_db)}"

  mkdir -p "$state_dir"

  ensure_mise

  mise use "postgres@${version}"
  mise install

  command -v mise >/dev/null 2>&1 || die "mise not found"
  mise exec -- initdb --version >/dev/null 2>&1 || die "initdb not found after mise install"
  mise exec -- pg_ctl --version >/dev/null 2>&1 || die "pg_ctl not found after mise install"

  printf "%s\n" "$version" > "$version_file"
  printf "%s\n" "$port" > "$port_file"
  printf "%s\n" "$db" > "$db_file"

  if [[ ! -d "$pgdata" ]]; then
    mise exec -- initdb -D "$pgdata" -U "$(whoami)" --encoding=UTF8
  else
    ok "Data dir already exists: $pgdata"
  fi

  rewrite_pg_conf_block "$port"

  ok "Project PostgreSQL initialized"
  printf "  version: postgres@%s\n" "$version"
  printf "  port:    %s\n" "$port"
  printf "  db:      %s\n" "$db"
  printf "  data:    %s\n" "$pgdata"
  printf "\nNext:\n"
  printf "  pg-project start\n"
  printf "  pg-project url\n"
}

start_project() {
  ensure_initialized

  local port db
  port="$(read_port)"
  db="$(read_db)"

  rewrite_pg_conf_block "$port"

  if mise exec -- pg_ctl -D "$pgdata" status >/dev/null 2>&1; then
    ok "PostgreSQL already running on port $port"
  else
    mise exec -- pg_ctl -D "$pgdata" -l "$logfile" start
    ok "PostgreSQL started on port $port"
  fi

  mise exec -- createdb -h localhost -p "$port" "$db" >/dev/null 2>&1 || true
}

stop_project() {
  ensure_initialized

  if mise exec -- pg_ctl -D "$pgdata" status >/dev/null 2>&1; then
    mise exec -- pg_ctl -D "$pgdata" stop
    ok "PostgreSQL stopped"
  else
    ok "PostgreSQL is not running"
  fi
}

status_project() {
  ensure_initialized
  mise exec -- pg_ctl -D "$pgdata" status || true
  printf "port: %s\n" "$(read_port)"
  printf "db:   %s\n" "$(read_db)"
  printf "data: %s\n" "$pgdata"
}

psql_project() {
  ensure_initialized
  exec mise exec -- psql -h localhost -p "$(read_port)" -d "$(read_db)"
}

url_project() {
  printf "postgresql://localhost:%s/%s\n" "$(read_port)" "$(read_db)"
}

env_project() {
  printf "export DATABASE_URL=%q\n" "$(url_project)"
  printf "export PGHOST=localhost\n"
  printf "export PGPORT=%q\n" "$(read_port)"
  printf "export PGDATABASE=%q\n" "$(read_db)"
}

help_project() {
  cat <<HELP
pg-project commands:
  init [version] [port] [db]  Initialize project PostgreSQL. Defaults: version=18, port=stable hash, db=<project>_development
  start                       Start project PostgreSQL and create db if missing
  stop                        Stop project PostgreSQL
  restart                     Stop then start
  status                      Show pg_ctl status and project config
  psql                        Open psql for this project DB
  url                         Print DATABASE_URL
  env                         Print shell exports for DATABASE_URL/PG*

Examples:
  pg-project init 18
  pg-project init 17 5433 myapp_development
  pg-project start
  eval "\$(pg-project env)"
HELP
}

case "$cmd" in
  init) init_project "$@" ;;
  start) start_project ;;
  stop) stop_project ;;
  restart) stop_project; start_project ;;
  status) status_project ;;
  psql) psql_project ;;
  url) url_project ;;
  env) env_project ;;
  help|-h|--help) help_project ;;
  *) die "unknown command: $cmd. Run: pg-project help" ;;
esac
PGPROJECT

  chmod +x "$HOME/.local/bin/pg-project"
  prepend_path_once "$HOME/.zshrc" "$HOME/.local/bin"
  prepend_path_once "$HOME/.zprofile" "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  ok "Installed: $HOME/.local/bin/pg-project"
}

install_ai_clis() {
  [[ "$SKIP_AI_CLIS" -eq 0 ]] || { ok "Skipping AI CLIs because --skip-ai-clis was used."; return 0; }

  log "Installing AI coding CLIs through npm"

  if ! mise exec -- npm --version >/dev/null 2>&1; then
    warn "npm is missing. Node should have been installed through mise; skipping Claude/Codex CLI install."
    return 0
  fi

  run_or_warn mise exec -- npm install -g @anthropic-ai/claude-code@latest
  run_or_warn mise exec -- npm install -g @openai/codex@latest
  run_or_warn mise reshim

  run_or_warn mise exec -- claude --version
  run_or_warn mise exec -- codex --version
}

install_gui_apps() {
  [[ "$NO_GUI" -eq 0 ]] || { ok "Skipping GUI apps because --no-gui was used."; return 0; }

  log "Installing GUI apps and cask-based CLIs"

  local casks=(
    google-chrome
    docker-desktop
    rubymine
    warp
    slack
    visual-studio-code
    postman
    1password
    1password-cli
    pgadmin4
  )

  local cask
  for cask in "${casks[@]}"; do
    brew_install_cask "$cask"
  done

  log "Handling Upwork Desktop App"
  if [[ -d "/Applications/Upwork.app" || -d "/Applications/Upwork Desktop App.app" ]]; then
    ok "Upwork appears to be installed."
  else
    warn "Upwork is not currently available as a reliable Homebrew cask. Opening official download page."
    open "https://www.upwork.com/ab/downloads/os/mac/" || warn "Could not open Upwork download page."
  fi

  if [[ "$NO_OPEN_APPS" -eq 0 ]]; then
    log "Opening installed GUI apps so macOS can finish first-run permissions"
    open -a "Google Chrome" || true
    open -a "Docker" || true
    open -a "RubyMine" || true
    open -a "Warp" || true
    open -a "Slack" || true
    open -a "Visual Studio Code" || true
    open -a "Postman" || true
    open -a "1Password" || true
    open -a "pgAdmin 4" || open -a "pgAdmin4" || true
  fi
}

install_xcode_app_if_requested() {
  [[ "$WITH_XCODE_APP" -eq 1 ]] || return 0

  log "Installing/updating full Xcode through App Store CLI when possible"
  brew_install_formula mas

  if mas account >/dev/null 2>&1; then
    if mas list | awk '{print $1}' | grep -qx "497799835"; then
      log "Xcode is installed. Attempting App Store update."
      mas upgrade 497799835 || warn "Xcode App Store upgrade failed."
    else
      log "Attempting Xcode install from App Store."
      mas install 497799835 || warn "Xcode App Store install failed."
    fi
  else
    warn "Not logged into the Mac App Store CLI. Opening Xcode page in App Store."
    open "macappstore://itunes.apple.com/app/id497799835" || true
  fi

  if have xcodebuild; then
    run_or_warn sudo xcodebuild -license accept
    run_or_warn xcodebuild -runFirstLaunch
  fi
}

install_addons_if_requested() {
  [[ "$WITH_ADDONS" -eq 1 ]] || return 0

  log "Installing optional quality/security/productivity add-ons"

  local formulae=(
    shellcheck
    shfmt
    hadolint
    trivy
    dotenv-linter
    pre-commit
    watchman
    age
    sops
    direnv
    lazygit
    hyperfine
    httpie
  )

  local formula
  for formula in "${formulae[@]}"; do
    brew_install_formula "$formula"
  done

  append_once "$HOME/.zshrc" 'eval "$(direnv hook zsh)"'

  if [[ "$NO_GUI" -eq 0 ]]; then
    local casks=(
      raycast
      rectangle
      lm-studio
      tableplus
      orbstack
    )

    local cask
    for cask in "${casks[@]}"; do
      brew_install_cask "$cask"
    done
  fi
}

configure_git_identity() {
  log "Configuring Git identity"

  local current_email
  current_email="$(git config --global user.email || true)"

  if [[ -n "$GH_EMAIL" ]]; then
    if [[ -z "$current_email" ]]; then
      git config --global user.email "$GH_EMAIL"
      ok "git user.email set to ${GH_EMAIL}"
    elif [[ "$current_email" == "$GH_EMAIL" ]]; then
      ok "git user.email already set to ${GH_EMAIL}"
    elif [[ "$FORCE_GIT_EMAIL" -eq 1 ]]; then
      git config --global user.email "$GH_EMAIL"
      ok "git user.email changed from ${current_email} to ${GH_EMAIL}"
    else
      warn "git user.email is already set to ${current_email}. Use --force-git-email to replace it with ${GH_EMAIL}."
    fi
  else
    warn "No --gh_email provided. Leaving git user.email unchanged."
  fi

  if [[ -z "$(git config --global init.defaultBranch || true)" ]]; then
    git config --global init.defaultBranch main
    ok "git init.defaultBranch set to main"
  fi

  git config --global pull.rebase false
  git config --global fetch.prune true
  git config --global rerere.enabled true
}

require_gh_email_for_ssh() {
  if [[ -z "$GH_EMAIL" ]]; then
    die "SSH key generation requires --gh_email=you@example.com or BOOTSTRAP_GH_EMAIL=you@example.com. Or pass --skip-ssh."
  fi

  case "$GH_EMAIL" in
    *@*.*) ;;
    *) die "Invalid --gh_email value: ${GH_EMAIL}" ;;
  esac
}

backup_existing_ssh_key() {
  local key="$1"
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"

  if [[ -f "$key" ]]; then
    mv "$key" "${key}.backup.${ts}"
    ok "Backed up private key to ${key}.backup.${ts}"
  fi

  if [[ -f "${key}.pub" ]]; then
    mv "${key}.pub" "${key}.pub.backup.${ts}"
    ok "Backed up public key to ${key}.pub.backup.${ts}"
  fi
}

configure_local_ssh_key() {
  require_gh_email_for_ssh
  log "Generating/configuring local SSH key"

  mkdir -p "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.ssh"
  chmod 700 "$HOME/.ssh/config.d"

  if [[ "$REGEN_SSH" -eq 1 ]]; then
    backup_existing_ssh_key "$SSH_KEY_PATH"
  fi

  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    log "Generating new ed25519 SSH key: ${SSH_KEY_PATH}"
    ssh-keygen -t ed25519 -C "$GH_EMAIL" -f "$SSH_KEY_PATH" -N ""
  else
    ok "SSH key already exists: ${SSH_KEY_PATH}"
  fi

  chmod 600 "$SSH_KEY_PATH"
  chmod 644 "${SSH_KEY_PATH}.pub"

  eval "$(ssh-agent -s)" >/dev/null

  if ssh-add --apple-use-keychain "$SSH_KEY_PATH" >/dev/null 2>&1; then
    ok "SSH key added to ssh-agent and macOS keychain."
  elif ssh-add -K "$SSH_KEY_PATH" >/dev/null 2>&1; then
    ok "SSH key added to ssh-agent and macOS keychain using legacy -K flag."
  else
    run_or_warn ssh-add "$SSH_KEY_PATH"
  fi

  append_once "$HOME/.ssh/config" 'Include ~/.ssh/config.d/*.conf'

  cat > "$HOME/.ssh/config.d/github.conf" <<EOF
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ${SSH_KEY_PATH}
  IdentitiesOnly yes
EOF

  chmod 600 "$HOME/.ssh/config" "$HOME/.ssh/config.d/github.conf"

  if have ssh-keygen; then
    local fingerprint
    fingerprint="$(ssh-keygen -lf "${SSH_KEY_PATH}.pub" 2>/dev/null || true)"
    [[ -n "$fingerprint" ]] && ok "SSH public key fingerprint: ${fingerprint}"
  fi
}

ensure_gh_available_for_ssh_only() {
  if have gh; then
    return 0
  fi

  warn "GitHub CLI is missing. Installing minimal dependencies for SSH upload."
  install_xcode_command_line_tools
  install_homebrew
  brew_install_formula gh
}

ensure_github_auth() {
  have gh || die "GitHub CLI is required for GitHub SSH key upload."

  if gh auth status >/dev/null 2>&1; then
    ok "GitHub CLI is authenticated."
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    warn "GitHub CLI is not authenticated and --non-interactive was used. Skipping GitHub SSH upload."
    return 1
  fi

  log "GitHub CLI login required"
  printf "The script will run: gh auth login -h github.com -p ssh -w\n"
  printf "Use your GitHub account in the browser flow.\n"

  gh auth login -h github.com -p ssh -w || {
    warn "GitHub login failed. Skipping GitHub SSH upload."
    return 1
  }

  gh auth status >/dev/null 2>&1
}

github_ssh_title() {
  if [[ -n "$SSH_TITLE" ]]; then
    printf "%s" "$SSH_TITLE"
    return 0
  fi

  local computer
  computer="$(scutil --get ComputerName 2>/dev/null || hostname)"
  printf "%s-%s" "$computer" "$(date +%Y-%m-%d)"
}

upload_ssh_key_to_github() {
  [[ "$SKIP_GH_SSH_UPLOAD" -eq 0 ]] || { ok "Skipping GitHub SSH upload because --skip-gh-ssh-upload was used."; return 0; }

  log "Uploading SSH public key to GitHub through gh"

  if ! ensure_github_auth; then
    warn "Local SSH key is ready, but was not uploaded to GitHub."
    return 0
  fi

  local title fingerprint
  title="$(github_ssh_title)"
  fingerprint="$(ssh-keygen -lf "${SSH_KEY_PATH}.pub" | awk '{print $2}')"

  if gh ssh-key list 2>/dev/null | grep -Fq "$fingerprint"; then
    ok "This SSH key fingerprint already appears in GitHub."
    return 0
  fi

  gh ssh-key add "${SSH_KEY_PATH}.pub" --title "$title" || {
    warn "gh ssh-key add failed. You can retry manually:"
    printf "  gh ssh-key add %q --title %q\n" "${SSH_KEY_PATH}.pub" "$title"
    return 0
  }

  ok "SSH public key uploaded to GitHub with title: ${title}"

  run_or_warn ssh -T git@github.com
}

print_versions() {
  log "Installed versions summary"

  run_or_warn sw_vers
  run_or_warn git --version
  run_or_warn brew --version
  run_or_warn mc --version
  run_or_warn gh --version
  run_or_warn aws --version
  run_or_warn mise --version

  run_or_warn mise exec -- ruby --version
  run_or_warn mise exec -- bundle --version
  run_or_warn mise exec -- node --version
  run_or_warn mise exec -- npm --version
  run_or_warn mise exec -- pnpm --version
  run_or_warn mise exec -- psql --version
  run_or_warn mise exec -- pg_config --version

  run_or_warn redis-server --version
  run_or_warn op --version
  run_or_warn mailpit version
  run_or_warn mise exec -- claude --version
  run_or_warn mise exec -- codex --version
}

print_final_notes() {
  log "Final notes"

  cat <<NOTES
Done.

Important next steps:
  1. Restart your terminal, or run:
       source ~/.zshrc

  2. Check runtimes:
       mise list
       ruby -v
       node -v
       psql --version

  3. Per-project PostgreSQL:
       cd ~/src/my-rails-app
       pg-project init 18
       pg-project start
       pg-project url
       eval "\$(pg-project env)"

     That creates:
       .mise.toml              # project PostgreSQL version
       .dev/postgres/data      # project-local PostgreSQL data
       .dev/postgres/port      # stable per-project port
       .dev/postgres/db        # project db name

  4. Redis:
       brew services start redis

  5. Mailpit:
       mailpit
     Then open:
       http://localhost:8025

  6. Authenticate services when needed:
       gh auth status
       aws configure sso
       op account add
       claude
       codex

PostgreSQL admin:
  - pgAdmin4 was installed as the default GUI admin.
  - Optional heavier/fancier GUI in --with-addons: TablePlus.

mise:
  - This script uses shims only:
       \$HOME/.local/share/mise/shims
  - It intentionally avoids:
       eval "\$(mise activate zsh)"
       eval "\$(mise activate bash)"
  - Reason: shell hooks can be fragile in non-interactive bootstrap scripts.

Git:
  - Current global git email:
       $(git config --global user.email 2>/dev/null || printf "not set")
  - To overwrite it on next run:
       ./mac_dev_bootstrap.sh --gh_email=you@example.com --force-git-email

SSH:
  - SSH key generation skipped: ${SKIP_SSH}
  - SSH key comment/email: ${GH_EMAIL:-not provided}
  - Private key path: ${SSH_KEY_PATH}
  - Public key path:  ${SSH_KEY_PATH}.pub
  - Public key was not printed.
  - GitHub upload was attempted through:
       gh ssh-key add "${SSH_KEY_PATH}.pub"

Tiny future-you saver:
  If Docker Desktop inside Parallels macOS behaves weirdly or not supported, try Docker on host macOS,
  or install OrbStack with:
       brew install --cask orbstack
NOTES
}

main() {
  parse_args "$@"
  ensure_platform

  if [[ "$SSH_ONLY" -eq 1 ]]; then
    ensure_gh_available_for_ssh_only
    configure_local_ssh_key
    upload_ssh_key_to_github
    print_final_notes
    exit 0
  fi

  install_rosetta_if_requested
  install_xcode_command_line_tools
  install_homebrew
  install_core_formulae
  configure_git_identity
  install_mise_runtimes
  create_pg_project_helper
  install_ai_clis
  install_gui_apps
  install_xcode_app_if_requested
  install_addons_if_requested
  brew cleanup || true

  if [[ "$SKIP_SSH" -eq 1 ]]; then
    ok "Skipping SSH setup because --skip-ssh was used."
  else
    configure_local_ssh_key
    upload_ssh_key_to_github
  fi

  print_versions
  print_final_notes
}

main "$@"
