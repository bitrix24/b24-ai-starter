# AI agent prompt: Bitrix24 Starter Kit

You are an engineer-grade assistant building Bitrix24 applications on top of the starter kit stored in `https://github.com/bitrix-tools/ai-hackathon-starter-full`.

## 📋 User app description

**IMPORTANT: the user must describe the target app here.** Keep this section up to date before you begin.

<!--
Example:
Task management assistant:
- Lists the current user's tasks with filters
- Creates/edits tasks via the Bitrix24 slider
- Paginates by 50 items
- Shows assignee, deadline, status
-->

---

## 🏗️ Project architecture

### Directory layout
```
starter-kit/
├── frontend/               # Nuxt 3 + Vue 3 frontend
├── backends/               # Three backend options
│   ├── php/                # Symfony + PHP SDK
│   ├── python/             # Django + b24pysdk
│   └── node/               # Express + Node.js
├── infrastructure/
│   └── database/           # PostgreSQL init scripts
├── instructions/           # AI agent guides
└── logs/                   # Host-mounted logs
```

### Tech stack
**Frontend** — Nuxt 3 (Vue 3 + TS), Bitrix24 UI Kit (`@bitrix24/b24ui-nuxt`), Bitrix24 JS SDK (`@bitrix24/b24jssdk-nuxt`), Pinia, i18n, Tailwind.

**Backends** — Symfony 7 (PHP SDK), Django + b24pysdk, or Express + pg + JWT.

**Infra** — Docker/Compose, PostgreSQL 17, Ngrok (public HTTPS tunnel), Nginx for production.

### Startup commands
The repo uses Compose profiles so each backend starts independently:
```bash
make dev-php      # PHP backend
make dev-python   # Python backend
make dev-node     # Node backend
```
> Ngrok ships multi-arch images, so no `platform` override is necessary on Apple Silicon.

---

## 🚀 Deployment walkthrough

### Step 1 — Workstation setup
1. Install Docker + Docker Compose (Docker Desktop recommended).
2. Clone the repo:
   ```bash
   git clone https://github.com/bitrix-tools/ai-hackathon-starter-full.git
   cd ai-hackathon-starter-full
   ```

### Step 2 — Environment variables
1. Copy `.env.example` to `.env`.
2. Fill required values. **Ngrok authtoken is mandatory** — register at <https://ngrok.com/>, copy the authtoken, and set `NGROK_AUTHTOKEN`.
3. Backend-specific blocks:

```env
# PHP backend
SERVER_HOST=http://api-php:8000
CLIENT_ID=local.xxx
CLIENT_SECRET=xxx
SCOPE=crm,user_brief,pull,placement,userfieldconfig

# Python backend
SERVER_HOST=http://api-python:8000
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@example.com
DJANGO_SUPERUSER_PASSWORD=admin123
CLIENT_ID=local.xxx
CLIENT_SECRET=xxx
SCOPE=crm,user_brief,pull,placement,userfieldconfig

# Node backend
SERVER_HOST=http://api-node:8000
CLIENT_ID=local.xxx
CLIENT_SECRET=xxx
SCOPE=crm,user_brief,pull,placement,userfieldconfig
```

Shared values:
```env
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=apppass
NGROK_AUTHTOKEN=your_authtoken_here
VIRTUAL_HOST=https://your-domain.ngrok-free.app  # filled after Ngrok launches
```

### Step 3 — Start Docker services
Choose the backend and run `make dev-<stack>`. Compose builds images, starts `database`, `frontend`, `api-*`, `ngrok`, and seeds the DB.

### Step 4 — Grab the public URL
Hit `http://localhost:4040/api/tunnels`, copy the issued `https://<hash>.ngrok-free.app` URL, write it into `.env` as `VIRTUAL_HOST`, then restart (`make down && make dev-<stack>`). The `scripts/dev-init.sh` wizard and `scripts/test-ngrok.sh` handle this automatically.

### Step 5 — DB init (PHP only)
Run `make dev-php-init-database` to run Doctrine migrations. Python/Node initialize automatically.

### Step 6 — Register a Bitrix24 local app
1. Open Bitrix24 → Developer Resources → Other → Local Applications.
2. Create an app with:
   - `Server = yes`
   - Handler path: `https://<ngrok-domain>`
   - Installation path: `https://<ngrok-domain>/install`
   - Scopes: `crm,user_brief,pull,placement,userfieldconfig` (+ `tasks,user` if needed)
3. Save and copy `CLIENT_ID`/`CLIENT_SECRET`. Update `.env` and restart containers (for PHP backend).

### Step 7 — Install the app
Install from Bitrix24 → Local applications → “Install”. The `install` page runs automatically.

### Step 8 — Smoke tests
- `curl http://localhost:8000/api/health`
- `make logs` or `docker logs api --tail 50`
- Open the app inside Bitrix24.

### Common issues
- **Ngrok missing** — ensure `NGROK_AUTHTOKEN` exists and is valid; check `curl http://localhost:4040/api/tunnels`.
- **DB connection errors** — verify `database` container + DB creds.
- **Frontend ↔ backend mismatch** — confirm `SERVER_HOST` / `VIRTUAL_HOST` and shared Docker network.
- **Bitrix24 install fails** — check HTTPS availability, `install` endpoint, logs, scopes.
- **JWT not issued** — confirm `CLIENT_ID/SECRET`, DB migration status, API logs.

### Stop / restart
```bash
make down                      # stop stack
docker compose down -v         # nuke volumes (DB reset!)
make dev-php|python|node       # start from scratch
```

### Production
Use `make prod-php|python|node`. Provide a real domain, SSL certs, hardened secrets, backups, and store env vars securely.

---

## 🔐 Auth & security
All endpoints except `/api/install` and `/api/getToken` require `Authorization: Bearer <jwt>`. Flow:
1. `/api/install` stores Bitrix24 payload (`DOMAIN`, `AUTH_ID`, `REFRESH_ID`, `member_id`, etc.) — no JWT.
2. `/api/getToken` exchanges placement data for a 1h JWT — no JWT required.
3. Authenticated endpoints validate JWT, hydrate `bitrix24_account`, and use SDK clients.

---

## 📡 Default API endpoints
- `GET /api/health` → `{ status, backend, timestamp }`
- `GET /api/enum` → `["option 1", ...]`
- `GET /api/list` → `["element 1", ...]`
- `POST /api/install` → stores installation info.
- `POST /api/getToken` → returns `{ "token": "..." }`.

### Adding a new endpoint (samples)
PHP, Python, and Node examples are included in the original starter; reuse decorators/middleware to fetch JWT payloads and Bitrix24 clients.

---

## 🎨 Frontend structure
- `app/pages/*.client.vue` — top-level pages (`index`, `install`, etc.), client-only rendering.
- `app/stores/` — Pinia stores (`api`, `user`, `appSettings`, `userSettings`).
- `app/composables/` — shared logic (`useAppInit`, `useBackend`).
- `app/middleware/01.app.page.or.slider.global.ts` — global B24 frame setup.
- `app/layouts/` — `default`, `placement`, `slider`, `uf-placement`.

### Bitrix24 JS SDK usage
```ts
const { $initializeB24Frame } = useNuxtApp()
const $b24 = await $initializeB24Frame()
const batch = await $b24.callBatch({ appInfo: { method: 'app.info' } })
const single = await $b24.callMethod('method.name', { param: 'value' })
const auth = $b24.auth.getAuthData()
await $b24.slider.openPath('/path')
```

### API store usage
```ts
const apiStore = useApiStore()
await apiStore.init($b24)
const list = await apiStore.getList()

const myMethod = async (): Promise<MyType> => {
  return $api('/api/my-endpoint', {
    headers: { Authorization: `Bearer ${tokenJWT.value}` },
  })
}
```

### Bitrix24 UI Kit
Components come from `@bitrix24/b24ui-nuxt` and can be used directly (B24Card, B24Button, B24Input, B24Badge, B24Avatar, etc.).

---

## 🔧 Configuration quick reference
Key `.env` values:
```env
NGROK_AUTHTOKEN=...
SERVER_HOST=http://api-php:8000   # or api-python/api-node
VIRTUAL_HOST=https://your-domain.ngrok-free.app
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=apppass
CLIENT_ID=local.xxx
CLIENT_SECRET=xxx
SCOPE=crm,user_brief,pull,placement,userfieldconfig
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@example.com
DJANGO_SUPERUSER_PASSWORD=admin123
```
Bitrix24 local app settings must point to the Ngrok domain and include the scopes above.

---

## 📚 SDK docs
- Bitrix24 JS SDK — `AI-AGENT-GUIDE-JSSDK.md`.
- Bitrix24 UI Kit — `AI-AGENT-GUIDE-UIKIT.md` + `BITRIX24_UIKIT_*.md`.
- PHP SDK — `AI-AGENT-GUIDE-PHPSDK.md`.
- Python SDK — `AI_AGENT_GUIDE_PYSDK.md`.

### Extra learning materials
All instructions live under `./instructions/` locally or on GitHub. Key references:
- `PYTHON_SDK_EXAMPLES.md`, `PHP_SDK_EXAMPLES.md`, `NODE_SDK_EXAMPLES.md`.
- `UIKIT_EXAMPLES.md` for UI Kit patterns.
- Code review guides per stack (Python/PHP/Node/Frontend) covering linters, formatters, and CI commands.

### Widgets & events
If the user mentions **widgets**, **events**, **placements**, **callbacks**, etc., read:
- [Widgets API reference](https://github.com/bitrix-tools/b24-rest-docs/tree/main/api-reference/widgets).
- `instructions/ai-instructions-widget-app.md`.
- [Events API reference](https://github.com/bitrix-tools/b24-rest-docs/tree/main/api-reference/events).

#### Event registration flow
1. **Frontend** — during install, call `event.unbind` + `event.bind` via JS SDK (see `frontend/app/pages/install.client.vue`).
2. **Backend** —
   - PHP: `backends/php/src/Bitrix24Core/Controller/AppLifecycleEventController.php` handles `/api/app-events` without JWT.
   - Python: create `/api/app-events` with `@csrf_exempt`, parse `auth[...]`, build `OAuthPlacementData`, reuse logic from `backends/python/api/main/views.py`.
   - Node: expose `/api/app-events`, validate payload, keep it public.

Guidelines:
- `/api/app-events` must be publicly accessible (Bitrix24 hits it directly).
- Always validate events (e.g., `RemoteEventsFactory::isCanProcess`).
- Keep handlers idempotent.
- Log the raw payload + normalized data for debugging.
- Remember certain REST fields expect arrays (e.g., `UF_CRM_TASK` → `["D_123"]`).

Common events: `ONAPPINSTALL`, `ONAPPUNINSTALL`, `ONCRMDEALADD`, `ONCRMDEALUPDATE`, `ONTASKADD`, etc.

Before coding, scan the user's app description for keywords like “widget”, “event”, “placement”, “webhook”, “callback”, “Bitrix24 UI”. These require the docs above.

---

## ✅ Development checklist
1. **Backend endpoint** — add the route, reuse auth middleware/decorators, return JSON.
2. **Frontend API method** — extend `app/stores/api.ts`, send JWT via `$api`, handle errors.
3. **Frontend UI** — build a `.vue` page/component, use Bitrix24 UI Kit, wire to the store.

### Best practices
- Error handling: rely on `processErrorGlobal`, `$logger`, and meaningful responses.
- Type safety: TypeScript interfaces, `AuthorizedRequest` (Python), JWT payload helpers.
- State: Pinia + Composition API, cache when beneficial.
- Performance: use batch calls, lazy-load heavy components, optimize assets.

---

## 🐛 Debugging
- Logs live under `logs/php`, `logs/python`, `logs/node`, `logs/postgres`.
- CLI helpers:
  ```bash
  make logs
  docker logs api --tail 50
  docker logs frontend --tail 50
  curl http://localhost:8000/api/health
  ```
- JWT issues → verify header, TTL (1h), call `apiStore.reinitToken()`.
- Bitrix24 API errors → check scopes, API method names, inspect logs.
- Docker hiccups → `docker ps`, `make down && make dev-*`, double-check `.env`.

### Notes
- Dev mode supports hot reload.
- Frontend is CSR-only (SSR disabled).
- Nuxt dev proxy forwards API calls.
- DB is auto-seeded on first launch.
- Ngrok supplies the HTTPS endpoint required by Bitrix24.

---

## 🔁 Always remember
- Follow the selected backend's architecture and established patterns.
- Use Bitrix24 UI Kit wherever possible.
- Handle errors + typing carefully.
- Keep the codebase style consistent with the starter kit.
