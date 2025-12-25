# 🚀 Bitrix24 AI Starter Automation Scripts

This directory packages every helper needed to bootstrap and maintain the Bitrix24 AI Starter stack.

## 📋 Script overview

| Script | Purpose | Command |
|--------|---------|---------|
| `dev-init.sh` | 🚀 Full project initialization | `make dev-init` |
| `security-tests.sh` | 🛡 Orchestrated security test suite | `make security-tests` |
| `fix-php.sh` | 🔧 Repair PHP dependencies | `make fix-php` |
| `test-ngrok.sh` | 🧪 Ngrok smoke test | `./scripts/test-ngrok.sh` |

---

## 🚀 dev-init.sh — primary initialization script

Interactive end-to-end setup with a two-phase Docker launch.

### ⚡ Capabilities

1. **🔑 Ngrok authtoken management** — reuse an existing key or prompt for a new one.
2. **🛠 Backend selection** — choose between PHP (Symfony), Python (Django), or Node.js (Express).
3. **📂 Version-aware** — when a `versions/` directory exists, you can pass `--version` / `DEV_INIT_VERSION` or pick a version interactively; initialization continues inside that working copy.
4. **🗂 Project cleanup** — remove unused backend and instruction folders:
   - Deletes unused subfolders in `backends/`.
   - Deletes unused language folders in `instructions/` (keeps `bitrix24/` and `front/`).
5. **🐳 Two-phase Docker launch**:
   - **Phase 1** — start Ngrok to obtain a public HTTPS domain.
   - **Phase 2** — restart the entire stack with the correct environment variables.
6. **🗄 Database init** — automatically prepares the chosen backend database.

### 🧩 “Chicken and egg” architecture

Docker Compose reads environment variables only on startup, yet the Ngrok public URL becomes available only after Ngrok is running. Two phases solve the loop:

1. **First run** — start only `frontend + ngrok` (database not required).
2. **Domain extraction** — query the Ngrok inspect API for `https://*.ngrok-free.app`.
3. **.env update** — write the discovered domain into `VIRTUAL_HOST`.
4. **Restart** — stop everything and relaunch with the updated env vars.

> **💡 Tip:** Ngrok only needs to reach `frontend:3000` inside the Docker network. The frontend does not need to respond successfully; the domain will still be issued.

### 💻 Usage

```bash
# Preferred via Makefile
make dev-init

# Direct call
./scripts/dev-init.sh
```

### 🔧 Recent fixes (December 2025)

#### ✅ Reliable Ngrok domain discovery

- **Issue:** legacy log parsing did not work with Ngrok.
- **Fix:** switched to the Ngrok inspect API (`http://localhost:4040/api/tunnels`) with JSON parsing via `python3`.

#### ✅ Cleaner tunnel lifecycle

- **Issue:** stale legacy tunnel containers kept ports busy during the migration.
- **Fix:** cleanup routines now remove lingering `ngrokFront` containers before relaunch.

#### ✅ Faster first phase

- **Issue:** earlier runs booted unnecessary services.
- **Fix:** phase one now launches only `frontend + ngrok`, keeping the tunnel lightweight.

#### 🚀 Result

`make dev-init` now provisions the Ngrok tunnel deterministically and restarts the stack with the detected domain automatically.

---

## 🛡 security-tests.sh — orchestrated security checks

This script runs a unified security test suite for the active parts of the project (frontend + chosen backend) inside Docker containers.

### ⚙ Features
1. **Profiles**:
   - `quick` — dependency audit + Semgrep OWASP Top 10
   - `full` — quick profile plus static analyzers, Gitleaks and Trivy
   - `custom` — interactive selection of steps
2. **Stack auto-detection**: after `make dev-init` only the selected backend remains, and the script figures out what to scan.
3. **Docker isolation**: every command runs inside its service (`php-cli`, `api-python`, `api-node`, `frontend`), so no host tooling is required.
4. **Reports**: JSON/log files are stored in `reports/security/<timestamp>/`.
5. **Friendly warnings**: in interactive runs vulnerabilities are shown as warnings (the script keeps going); in `--ci` mode the same exit code is treated as an error.
6. **CI mode**: `--ci` automatically enables the `full` profile and disables questions.

### 🔍 What runs
- **Dependency audit**: `composer audit`, `pip-audit`, `pnpm audit` (backend + frontend)
- **Static analysis**: `phpstan`, `bandit`, `eslint` (node/backend + frontend)
- **Semgrep**: `p/owasp-top-ten` ruleset
- **Secret scanning**: `gitleaks` (Docker image)
- **Filesystem scan**: `trivy fs` (Docker image)

### 💻 Usage
```bash
# Quick mode (default)
make security-tests

# Full profile without failing on findings
make security-tests SECURITY_TESTS_ARGS="--profile full --allow-fail"

# CI mode
./scripts/security-tests.sh --ci --profile full
```

Interactive runs show a profile menu and, for the `custom` profile, confirmations for each test category.

---

## 🔧 fix-php.sh — repair PHP dependencies

Utility script that recovers from composer conflicts inside the PHP backend.

### 🛠 Fixes

- ❌ Version conflicts between `phpstan/phpstan` and `rector/rector`.
- ❌ Missing or corrupted vendor files.
- ❌ Out-of-sync `composer.lock`.
- ❌ Autoload issues.

### 🔄 Flow

1. Stop containers.
2. Remove `vendor/` and `composer.lock`.
3. Restart PHP containers.
4. Reinstall dependencies with a clean slate.

### 💻 Usage

```bash
# Via Makefile
make fix-php

# Direct
./scripts/fix-php.sh
```

---

## 🧪 test-ngrok.sh — Ngrok smoke test

Run Ngrok in isolation to validate the authtoken and fetch a public domain without the rest of the stack.

### ⚙️ Features

- 🚀 Launch Ngrok + frontend only.
- 📡 Poll the Ngrok inspect API for the issued domain.
- 🔐 Update `.env` with the new `VIRTUAL_HOST`.
- ⏹️ Graceful shutdown after the test.

### 💻 Usage

```bash
./scripts/test-ngrok.sh
```

---

## 📋 Makefile integration

All scripts are wired into the root Makefile:

```bash
# Core
make dev-init          # Full project bootstrap
make fix-php           # Repair PHP dependencies
make help              # List commands

# Container control
make dev-php           # Start PHP stack
make down              # Stop everything
make logs              # Tail logs
```

---

## 🔧 System requirements

- **Docker & Docker Compose** — latest versions.
- **Ngrok authtoken** — obtain a token at [ngrok.com](https://dashboard.ngrok.com/get-started/your-authtoken).
- **Bash shell** — macOS, Linux, or WSL.
- **Open ports** — 3000 (frontend), 8000 (API), 5432 (PostgreSQL).

---

## 🎯 Typical workflow

### 1️⃣ First launch
```bash
make dev-init
```

### 2️⃣ PHP dependency issues
```bash
make fix-php
```

### 3️⃣ Daily development
```bash
make dev-php      # run services
make logs         # monitor logs
make down         # stop containers
```

---

## 🏗 Architectural notes

### 🌐 Environment variables

Scripts keep critical `.env` entries in sync:

```bash
NGROK_AUTHTOKEN=your-authtoken                 # Ngrok auth token
VIRTUAL_HOST=https://your-domain.ngrok-free.app   # Public HTTPS domain
SERVER_HOST=http://api-php:8000                # Backend URL for the frontend
```

### 🔀 Backend selection

Choosing a backend updates `SERVER_HOST` automatically:

| Backend | SERVER_HOST |
|---------|-------------|
| **PHP** | `http://api-php:8000` |
| **Python** | `http://api-python:8000` |
| **Node.js** | `http://api-node:8000` |

### 🌍 Ngrok integration

Ngrok exposes local containers via HTTPS:

```
Frontend (localhost:3000) → Ngrok → https://domain.ngrok-free.app
```

Perfect for Bitrix24 callbacks, robots, and webhooks.

### 📁 Development volume mounts

In dev mode code changes sync instantly between host and containers:

| Service | Host path | Container |
|---------|-----------|-----------|
| **Frontend** | `./frontend/` | `/app/` |
| **PHP API** | `./backends/php/` | `/var/www/` |
| **Python API** | `./backends/python/api/` | `/var/www/api/` |
| **Node.js API** | `./backends/node/api/` | `/app/` |

**Benefits:**
- ✅ Instant code reflection.
- ✅ No rebuilds on file changes.
- ✅ Hot reload everywhere.
- ✅ Keep using your local IDE.

---

## 🐛 Troubleshooting

### ❌ Ngrok domain missing
```bash
# Validate the token
./scripts/test-ngrok.sh

# Relaunch from scratch
make dev-init
```

### ❌ PHP dependencies broken
```bash
make fix-php
# or
rm -rf backends/php/vendor backends/php/composer.lock
make dev-php
```

### ❌ Containers refuse to start
```bash
make down
make clean
make dev-init
```

### ❌ “network not found”

If you encounter `failed to set up container networking: network ... not found`:

```bash
docker-compose down --remove-orphans --volumes
docker container rm -f $(docker container ls -aq --filter "name=b24") 2>/dev/null || true
docker network prune -f
docker volume prune -f
make dev-init
```

**Reason:** stale containers or networks. `dev-init.sh` already performs this cleanup, but manual steps can help during debugging.

### ❌ Ports already in use
```bash
lsof -i :3000
lsof -i :8000
lsof -i :5432
make down
```

---

## 📈 Monitoring & debugging

```bash
# Container status
docker ps

# Service logs
docker logs frontend -f
docker logs api -f
docker logs database-1 -f

# Shell inside a container
make php-cli-sh
```

---

## ✅ What’s next?

After `make dev-init` succeeds you get:

1. **🌐 Public HTTPS domain** connected to your stack.
2. **🚀 Running services** — frontend, API, database.
3. **⚙️ Configured environment** — all relevant `.env` values set.
4. **📊 Seeded database** — schema prepared.

### 🎯 Next steps

1. Open the public domain in a browser.
2. Create a local Bitrix24 application.
3. Point Bitrix24 callbacks to your Ngrok domain.
4. Start building! 🚀

---

*Built for the Bitrix24 AI Hackathon Starter Kit* 💙
