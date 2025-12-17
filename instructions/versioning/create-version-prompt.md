# 🤖 Prompt: Create a New Project Version

## Context
- Repository: `b24-ai-starter`
- Goal: prepare a new development stream (e.g. `v2`, `v3`) without touching the current one
- Tool: `scripts/create-version.sh` copies the working tree into `versions/<name>` and updates `APP_VERSION` in `.env`

## When to use this prompt
- Before large changes that might break the stable version
- When launching a new product iteration (V2, V3, …)
- When multiple implementations must exist simultaneously for demos or comparisons

## Procedure
1. **Check the working tree**
   - Run `git status`
   - Commit pending changes or make sure they’re safe to clone
2. **Launch the script**
   - `./scripts/create-version.sh` (or pass a name: `./scripts/create-version.sh v3`)
   - Provide a space-free version name (`v2`, `release-2025q1`, etc.)
3. **What the script does**
   - Creates `versions/<name>` and copies the project (frontend, backends, infra, `.env`, etc.)
   - Skips `.git`, existing `versions/`, and heavy folders (`node_modules`, `.nuxt`, `vendor`, `.venv`, `logs`)
   - Adds or updates `APP_VERSION=<name>` in `.env`
4. **Post-actions**
   - `cd versions/<name>`
   - Start the required stack (`make dev-php`, `make dev-python`, `make dev-node`)
   - Verify `/api/health` and the UI to confirm the copy works independently
   - `make dev-init` lists available versions; alternatively run `DEV_INIT_VERSION=<name> make dev-init` or `./scripts/dev-init.sh --version <name>`
   - Shortcuts: `make create-version VERSION=<name>` / `make delete-version VERSION=<name>` proxy the scripts (interactive if `VERSION` is missing)

## Checklist
- [ ] `versions/<name>` contains the full project
- [ ] Root `.env` now has `APP_VERSION=<name>`
- [ ] Containers/scripts run from the new folder
- [ ] Frontend/backend operate independently of the old version
- [ ] A note about the new version was added to docs or the task tracker

## Troubleshooting
- **Name already exists:** delete/rename the old copy or pick another name
- **rsync missing:** install it (`brew install rsync`, `sudo apt install rsync`, `sudo dnf install rsync`, `sudo pacman -S rsync`, …)
- **Need to rerun:** execute the script again — existing folders are not overwritten
- **Switch back:** open `versions/<old>` or reset `APP_VERSION` in `.env`
- **Delete a version:** `./scripts/delete-version.sh <name>` lists versions, asks for confirmation, and removes `APP_VERSION` if needed

## Important notes
- `versions/` is tracked by default — add it to `.gitignore` for local-only copies
- Each version is a complete project; deleting the folder removes that version
- The script copies the current state, including uncommitted changes
- `scripts/dev-init.sh` accepts `--version <name>` and `DEV_INIT_VERSION=<name>` so you can launch a copy without manual `cd`

Use this prompt whenever you need a safe new iteration of the starter. Follow the steps in order and tick every checklist item.

