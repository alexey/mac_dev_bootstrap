# macOS M4 Developer Bootstrap

A practical bootstrap script for setting up a fresh Apple Silicon Mac for Ruby/Rails, Node.js, PostgreSQL, Docker, and AI-assisted development.

It is built around `mise`, so Ruby, Node.js, and PostgreSQL versions can be managed cleanly instead of being tied to one global Homebrew install.

The script should work on a normal Apple Silicon Mac and also on macOS running inside Parallels.

---

## Read this first

Before running the script:

1. Back up anything important.
2. Do not run it unless you understand what it does.
3. Read the script before executing it, especially if you got it from a fork.
4. Check for anything suspicious or unexpected.
5. You are responsible for what happens on your machine.
6. Feel free to clone it and change whatever you want.

This script installs developer tools, changes shell startup files, configures runtimes, and can generate an SSH key for GitHub. That is useful, but it also means you should not treat it as a random copy-paste command from the internet.

---

## Before

* Enable nested virtualization in the BIOS or in virtualization settings.

---

## Script

Built for zsh, quickstart but make sure to check the options before running it:

URL: `https://github.com/alexey/mac_dev_bootstrap`
You can download it from GitHub/zip file or by terminal:

```bash
git clone git@github.com:alexey/mac_dev_bootstrap.git ./mac-dev-bootstrap
cd mac-dev-bootstrap
chmod +x ./mac_dev_bootstrap.sh
mac_dev_bootstrap.sh --gh_email=you@example.com
```

Run it and start Redis after install:

```bash
./mac_dev_bootstrap.sh --start-services
```

Only regenerate the SSH key and upload it to GitHub:

```bash
./mac_dev_bootstrap.sh --ssh-only --regen-ssh --gh_email=you@example.com
```

---

## What it does

The script installs things in an order that avoids most of the usual setup pain:

1. Apple developer prerequisites
2. Homebrew
3. CLI tools and build dependencies
4. `mise`
5. Ruby, Node.js, and PostgreSQL through `mise`
6. Redis and Rails helper tools
7. GUI apps
8. GitHub SSH key setup through `gh`

---

## What it installs

### Apple / system prerequisites

| Tool                     | Purpose                                             |
| ------------------------ | --------------------------------------------------- |
| Xcode Command Line Tools | Compiler, SDK headers, `git`, and basic build tools |
| Full Xcode               | Optional. Enabled with `--with-xcode-app`           |
| Rosetta 2                | Optional. Enabled with `--with-rosetta`             |

---

### Package and runtime management

| Tool                   | Purpose                                                                                 |
| ---------------------- |-----------------------------------------------------------------------------------------|
| Homebrew               | macOS package manager                                                                   |
| mise                   | Runtime version manager, better than RVM, can also manage psql and node(instead of nvm) |
| mise PostgreSQL plugin | Installs PostgreSQL versions through `mise`                                             |

---

### Core CLI tools

| Tool                                        | Purpose                          |
| ------------------------------------------- | -------------------------------- |
| `git`                                       | Version control                  |
| `git-lfs`                                   | Git large-file support           |
| `gh`                                        | GitHub CLI                       |
| `awscli`                                    | AWS CLI                          |
| `mc`                                        | Midnight Commander               |
| `curl`, `wget`                              | Download/network tools           |
| `jq`, `yq`                                  | JSON/YAML command-line tools     |
| `tree`                                      | Directory tree viewer            |
| `ripgrep`, `fd`                             | Fast search/find tools           |
| `fzf`                                       | Fuzzy finder                     |
| `htop`                                      | Process monitor                  |
| `tmux`                                      | Terminal multiplexer             |
| `watch`                                     | Re-run commands repeatedly       |
| `coreutils`, `findutils`, `gnu-sed`, `grep` | GNU versions of common CLI tools |
| `gnupg`, `pinentry-mac`                     | GPG and key handling             |

---

### Build dependencies

| Tool                            | Purpose                                              |
| ------------------------------- | ---------------------------------------------------- |
| `openssl@3`                     | TLS/crypto dependency used by Ruby and native builds |
| `readline`                      | Readline support for shells and CLIs                 |
| `libyaml`                       | YAML support for Ruby                                |
| `gmp`                           | Math/native library dependency                       |
| `libffi`                        | FFI/native extension support                         |
| `autoconf`, `automake`, `bison` | Build tools                                          |
| `pkg-config`                    | Native dependency discovery                          |
| `cmake`                         | Build system                                         |
| `gcc`                           | Compiler toolchain                                   |
| `zlib`                          | Compression library                                  |
| `ossp-uuid`                     | UUID dependency used by some PostgreSQL builds       |
| `icu4c`                         | Unicode/i18n dependency                              |
| `libpq`                         | PostgreSQL client libraries and `psql` fallback      |

---

### Runtimes

| Runtime    | Managed by | Default                 |
| ---------- | ---------- | ----------------------- |
| Ruby       | `mise`     | `3.4.9`                 |
| Node.js    | `mise`     | `latest`                |
| PostgreSQL | `mise`     | `18`                    |
| Redis      | Homebrew   | latest Homebrew formula |

---

### Rails / web development helpers

| Tool          | Purpose                           |
| ------------- | --------------------------------- |
| `mailpit`     | Local email testing server and UI |
| `vips`        | Image processing dependency       |
| `imagemagick` | Image processing CLI              |
| `overmind`    | Procfile/process runner           |
| `foreman`     | Procfile/process runner           |

---

### AI / coding CLIs

| Tool             | Install method                                    |
| ---------------- | ------------------------------------------------- |
| Claude Code CLI  | `npm install -g @anthropic-ai/claude-code@latest` |
| OpenAI Codex CLI | `npm install -g @openai/codex@latest`             |

---

### GUI apps

| App                | Purpose                                                 |
| ------------------ | ------------------------------------------------------- |
| Google Chrome      | Browser                                                 |
| Docker Desktop     | Containers                                              |
| RubyMine           | Ruby/Rails IDE                                          |
| Warp               | Terminal                                                |
| Slack              | Communication                                           |
| Visual Studio Code | Editor                                                  |
| Postman            | API client                                              |
| 1Password          | Password manager                                        |
| 1Password CLI      | Secrets/account CLI                                     |
| pgAdmin 4          | PostgreSQL GUI                                          |
| Upwork Desktop App | Opens the official download page if it is not installed |

---

## Optional add-ons

Install optional tools with:

```bash
./mac_dev_bootstrap.sh --with-addons
```

| Tool            | Purpose                       |
| --------------- | ----------------------------- |
| `shellcheck`    | Shell script linting          |
| `shfmt`         | Shell script formatting       |
| `hadolint`      | Dockerfile linting            |
| `trivy`         | Dependency/container scanning |
| `dotenv-linter` | `.env` file linting           |
| `pre-commit`    | Git hook manager              |
| `watchman`      | File watching                 |
| `age`           | File encryption               |
| `sops`          | Secrets encryption            |
| `direnv`        | Per-project shell environment |
| `lazygit`       | Terminal Git UI               |
| `hyperfine`     | Benchmarking                  |
| `httpie`        | HTTP client                   |
| Raycast         | Productivity launcher         |
| Rectangle       | Window manager                |
| LM Studio       | Local LLM runner              |
| TablePlus       | Database GUI                  |
| OrbStack        | Docker Desktop alternative    |

---

## Options

| Option                 | Description                                                            |
| ---------------------- |------------------------------------------------------------------------|
| `--ssh-only`           | Only generate/regenerate the SSH key and upload it to GitHub with `gh` |
| `--gh_email X`         | GitHub email used for SSH key generation and upload                    |
| `--regen-ssh`          | Back up and regenerate the configured SSH key                          |
| `--ruby-version X`     | Ruby version installed through `mise`. Default: `3.4.9`                |
| `--node-version X`     | Node.js version installed through `mise`. Default: `latest`            |
| `--postgres-version X` | PostgreSQL version installed through `mise`. Default: `18`             |
| `--skip-ruby`          | Skip Ruby installation                                                 |
| `--skip-node`          | Skip Node.js installation                                              |
| `--skip-postgres-mise` | Skip PostgreSQL installation through `mise`                            |
| `--skip-ai-clis`       | Skip Claude/Codex npm CLIs                                             |
| `--skip-gh-ssh-upload` | Generate the local SSH key but do not upload it with `gh`              |
| `--no-gui`             | Skip GUI apps/casks                                                    |
| `--no-open-apps`       | Do not open GUI apps after installation                                |
| `--with-xcode-app`     | Try to install/update full Xcode through the App Store CLI             |
| `--with-rosetta`       | Install Rosetta 2                                                      |
| `--with-addons`        | Install optional quality/security/productivity tools                   |
| `--start-services`     | Start Redis after installation                                         |
| `--non-interactive`    | Avoid optional prompts where possible                                  |
| `-h`, `--help`         | Show help                                                              |

PostgreSQL is not started as one global Homebrew service. It is handled per project with `pg-project`.

---

## Environment variables

| Variable           | Default                             | Purpose                                           |
| ------------------ |-------------------------------------| ------------------------------------------------- |
| `BOOTSTRAP_EMAIL`  | `your_own_email@example.com`        | Email/comment used for Git and SSH key generation |
| `SSH_KEY_NAME`     | `id_ed25519_your_own_email`            | SSH key filename                                  |
| `SSH_KEY_PATH`     | `$HOME/.ssh/id_ed25519_your_own_email` | Full SSH private key path                         |
| `SSH_TITLE`        | auto-generated                      | GitHub SSH key title                              |
| `RUBY_VERSION`     | `3.4.9`                             | Default Ruby version                              |
| `NODE_VERSION`     | `latest`                            | Default Node.js version                           |
| `POSTGRES_VERSION` | `18`                                | Default PostgreSQL version                        |

Example:

```bash
BOOTSTRAP_EMAIL="your_own_email@example.com" RUBY_VERSION="3.4.9" NODE_VERSION="latest" ./mac_dev_bootstrap.sh
```

---

## Project-local PostgreSQL

The script installs a helper command:

```bash
pg-project
```

Use it to give each project its own PostgreSQL version, port, database name, and data directory.

That is useful when one app needs PostgreSQL 18, another still runs on PostgreSQL 16, and you do not want to keep fighting one global database service.

---

### Initialize PostgreSQL for a project

```bash
cd ~/src/my-rails-app
pg-project init 18
pg-project start
pg-project url
```

---

### Initialize a legacy project on a different version and port

```bash
cd ~/src/legacy-app
pg-project init 16 5436 legacy_app_development
pg-project start
```

---

### Export Rails database environment

```bash
eval "$(pg-project env)"
bin/rails db:prepare
```

---

### Created project files

| Path                 | Purpose                                 |
| -------------------- | --------------------------------------- |
| `.mise.toml`         | Project PostgreSQL version              |
| `.dev/postgres/data` | Project-local PostgreSQL data directory |
| `.dev/postgres/port` | Project-specific port                   |
| `.dev/postgres/db`   | Project database name                   |

---

## SSH behavior

The script creates an ed25519 SSH key and configures it for GitHub.

It does not print public or private keys.

The public key is uploaded through GitHub CLI:

```bash
gh ssh-key add "$HOME/.ssh/id_ed25519_your_own_key.pub"
```

If GitHub CLI is not authenticated yet, the script starts the browser-based login flow:

```bash
gh auth login -h github.com -p ssh -w
```

---

## Notes

* Docker Desktop may ask for macOS permissions on first launch.
* Docker Desktop inside a Parallels macOS VM may be less reliable than running Docker on the host Mac.
* PostgreSQL server versions are intentionally managed through `mise`, not Homebrew.
* Homebrew `libpq` is installed as a client/tooling fallback, not as the main PostgreSQL server.
* Redis is managed through Homebrew because it is simple and usually does not need per-project version switching.
* The Homebrew shell environment is added automatically to both `~/.zprofile` and `~/.zshrc`.

---

## MIT License

Copyright (c) 2026 Alexey Zatsepin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
