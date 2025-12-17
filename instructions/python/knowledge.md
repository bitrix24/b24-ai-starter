# 🐍 Python Backend: Django + Bitrix24 integration guide

## 📋 Overview

- The Python backend lives in `backends/python/api` and is built on Django. FastAPI is not used in this project.
- A single `main` app exposes REST endpoints under `/api*`, handles authentication, models, and helper decorators.
- Auth combines Bitrix24 OAuth (via `b24pysdk`) with internal JWTs issued from rows in the `bitrix24account` table.
- This document covers configuration, request lifecycle, and dev practices for maintaining and extending the current implementation.

---

## ⚙️ Stack and dependencies

### Core tech
- **Django** — framework responsible for middleware, ORM, admin, and WSGI/ASGI entrypoints.
- **b24pysdk==0.2.3a1** — SDK that wraps Bitrix24 OAuth, REST, and events.
- **PostgreSQL + psycopg2-binary** — default database accessed through Django ORM.
- **PyJWT** — generates and validates internal JWT tokens.
- **django-cors-headers** — sets CORS/X-Frame headers so the app can render inside Bitrix24.
- **environs** — loads configuration from `.env` / environment variables.
- **gunicorn** — production WSGI server (see `Dockerfile`).

### requirements.txt (`backends/python/api/requirements.txt`)
```txt
Django
psycopg2-binary
django-cors-headers
PyJWT
gunicorn
environs
b24pysdk==0.2.3a1
```

---

## 🗂️ Project structure
```text
backends/python/api/
├── asgi.py / wsgi.py          # standard Django entrypoints
├── config.py                  # Config dataclass + .env loader
├── Dockerfile                 # multi-stage (dev/prod)
├── manage.py                  # Django CLI
├── requirements.txt
├── settings.py / urls.py      # global settings and routing
└── main/
    ├── admin.py               # model registration
    ├── models.py              # Bitrix24Account, ApplicationInstallation
    ├── urls.py                # /api*, /api/health etc.
    ├── utils/
    │   ├── authorized_request.py
    │   └── decorators/
    │       ├── auth_required.py
    │       ├── collect_request_data.py
    │       └── log_errors.py
    └── views.py               # HTTP handlers
```

> Tables `bitrix24account` and `application_installation` are marked `managed = False`, so their schema is owned by another service (PHP backend). Django only works with pre-existing tables.

---

## 🔧 Configuration

### `config.py`
`Config` aggregates environment parameters via `environs.Env` and is exported as the singleton `config`. Every other module (including `settings.py` and models) reads values from here.

| Variable          | Purpose                                           | Default |
|-------------------|---------------------------------------------------|---------|
| `BUILD_TARGET`    | `dev` / `production`; controls `DEBUG`             | `dev`   |
| `DB_NAME`         | DB name                                           | `appdb` |
| `DB_USER`         | DB user                                           | `appuser` |
| `DB_PASSWORD`     | DB password                                       | `apppass` |
| `DB_HOST` / `PORT`| PostgreSQL address (`database` / `5432` in Docker) | `database` / `5432` |
| `NGROK_AUTHTOKEN` | Ngrok authtoken                                   | empty   |
| `JWT_SECRET`      | Used as Django `SECRET_KEY` and JWT secret         | `default_jwt_secret` |
| `JWT_ALGORITHM`   | JWT signing algorithm                             | `HS256` |
| `CLIENT_ID`       | Bitrix24 OAuth client ID                          | `client_id` |
| `CLIENT_SECRET`   | Bitrix24 OAuth client secret                      | `client_secret` |
| `VIRTUAL_HOST`    | External URL; populates `CSRF_TRUSTED_ORIGINS`     | `app_base_url` |

Extra variables (e.g. `ENABLE_RABBITMQ`) are read by the Makefile during docker compose runs.

### `settings.py`
- `SECRET_KEY = config.jwt_secret`, `DEBUG` comes from `BUILD_TARGET`.
- `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` are derived from `VIRTUAL_HOST`; fallback domains are `localhost`, `api-python`.
- `INSTALLED_APPS` contains Django defaults + `corsheaders` + `main`.
- `MIDDLEWARE` starts with `CorsMiddleware` to ensure headers are added first.
- `DATABASES['default']` uses `django.db.backends.postgresql_psycopg2` with config values.
- `CORS_ALLOW_ALL_ORIGINS = True` for convenience in dev; tighten it for prod.

```python
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "main",
]
```

---

## 🚀 Running locally

### Docker / Makefile
- `make dev-python` — main workflow, launches profiles `frontend,python,ngrok` (+ `queue` if `.env` sets `ENABLE_RABBITMQ=1`).
- `make prod-python` — build + run the Python backend in production mode only.

### Without Docker
```bash
cd backends/python/api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate --noinput
python manage.py runserver 0.0.0.0:8000
```
The `Dockerfile` pipeline automatically runs `makemigrations`, `migrate`, and `createsuperuser --noinput`, but you can execute them manually locally.

### Dockerfile quick tour
- **base**: `python:3.11-slim`, installs `postgresql-client` and Python deps.
- **dev**: mounts the project as a volume and runs `runserver` after migrations.
- **prod**: copies source into the image and starts Gunicorn (`gunicorn wsgi:application --bind 0.0.0.0:8000`).

---

## 🧱 The `main` app

### URL routes (`main/urls.py`)
| Method | Path           | View        | Description |
|--------|----------------|-------------|-------------|
| GET    | `/api`         | `root`      | Quick "Python Backend is running" response |
| GET    | `/api/health`  | `health`    | Health-check with status + timestamp |
| GET    | `/api/enum`    | `get_enum`  | Returns a static list of options |
| GET    | `/api/list`    | `get_list`  | Returns a static list of items |
| POST   | `/api/install` | `install`   | Creates/updates `ApplicationInstallation` |
| POST   | `/api/getToken`| `get_token` | Issues a new JWT |

All handlers are decorated with `@xframe_options_exempt` so Bitrix24 can embed them in an iframe.

### Views (`main/views.py`)
- The simple GET endpoints serve as templates — extend them as needed.
- `install` stores `ApplicationInstallation` entries for the Bitrix24 portal, using fields from `request.bitrix24_account`.
- `get_token` calls `Bitrix24Account.create_jwt_token()` (default TTL 60 minutes).
- Every view is wrapped in `@auth_required` and `@log_errors`, so exceptions become JSON 500 responses and are logged automatically.

### Decorators and `AuthorizedRequest`
- `AuthorizedRequest` extends `HttpRequest` with `bitrix24_account` to keep type hints clean.
- `collect_request_data` merges JSON body + query + form params into `request.data`, handling multi-value keys carefully.
- `auth_required`:
  1. Looks for header `Authorization: Bearer <jwt>`.
  2. If present, calls `Bitrix24Account.get_from_jwt_token()` and assigns it to `request.bitrix24_account`.
  3. If missing, parses `OAuthPlacementData` from `request.data` and calls `Bitrix24Account.update_or_create_from_oauth_placement_data()` (via the SDK). The resulting account is stored on the request as well.
  4. Errors (`DoesNotExist`, `ExpiredSignature`, `BitrixValidationError`) are converted into JSON responses with status 400/401.
- `log_errors("name")` captures exceptions and logs them through standard `logging`.

```python
@log_errors("get_token")
@auth_required
def get_token(request: AuthorizedRequest):
    return JsonResponse({"token": request.bitrix24_account.create_jwt_token()})
```

### Models (`main/models.py`)
- `Bitrix24Account` extends `AbstractBitrixToken` and maps to table `bitrix24account` (UUID PK). Key methods:
  - `bitrix_app` — class property that builds `BitrixApp` from `CLIENT_ID/CLIENT_SECRET`.
  - `client` — wrapper around `b24pysdk.Client` for REST calls.
  - `create_jwt_token(minutes=60)` / `get_from_jwt_token` — issue and verify internal tokens via PyJWT.
  - `update_or_create_from_oauth_placement_data` — main entrypoint used by `auth_required`, creates or updates an account based on OAuth payloads.
  - Signals (`portal_domain_changed_signal`, `oauth_token_renewed_signal`) keep the record in sync with Bitrix24 events.
- `ApplicationInstallation` stores installation status for a portal and has a `OneToOne` link to `Bitrix24Account`.

### Admin panel (`main/admin.py`)
- Both models are registered with dynamic `list_display`; `id` is read-only.
- Dev superuser is created automatically (`createsuperuser --noinput` inside Docker). Admin URL: `/api/admin/`.

---

## 🔄 Install + token lifecycle
1. Bitrix24 calls the backend and sends OAuth placement payload.
2. `collect_request_data` combines JSON + query params into `request.data`.
3. `auth_required` converts the payload into `OAuthPlacementData` and calls `Bitrix24Account.update_or_create_from_oauth_placement_data()` (SDK also fetches `app_info`).
4. After authorization:
   - `install` creates/updates `ApplicationInstallation`.
   - `get_token` issues a JWT and returns it to the client.
5. The frontend stores the JWT and sends it in the `Authorization` header on future requests; `auth_required` then just validates the token without calling Bitrix24 APIs.

---

## 🛡️ Security
- Keep `JWT_SECRET`, OAuth keys, and DB params inside `.env` / CI secrets. Do not ship defaults to production.
- Rotate JWTs regularly (TTL is the `minutes` argument of `create_jwt_token`). When it expires, the frontend should call `/api/getToken` or repeat the OAuth flow.
- `CSRF_TRUSTED_ORIGINS` is derived automatically, but if several Bitrix24 domains are involved, list them explicitly via `VIRTUAL_HOST` or extend the logic.
- For production set `CORS_ALLOWED_ORIGINS` / `CORS_ALLOW_CREDENTIALS` to restrict origins.
- Attach centralized logging (Sentry/ELK). Currently `log_errors` writes to standard logging only.

---

## 📦 Deployment
- The Docker image is based on `python:3.11-slim`. Keep `requirements.txt` minimal to avoid bloating the image.
- Before shipping, refresh `.env`: DB params, OAuth creds, JWT secret, `VIRTUAL_HOST`.
- `docker compose --env-file .env up --build` uses the selected profiles (`COMPOSE_PROFILES=python` for production).
- In Kubernetes or similar platforms, run `python manage.py migrate` as a separate job to prevent migration races.

---

## 🧪 Testing tips
- Use `pytest` + `pytest-django` or Django's built-in `manage.py test`.
- Cover:
  - `auth_required` (JWT vs OAuth branches, PyJWT errors, `BitrixValidationError`).
  - `Bitrix24Account.create_jwt_token` / `get_from_jwt_token` (invalid secret, expiry handling).
  - Views `install` / `get_token` with mocked models + SDK.
- For integration tests, rely on `django.test.Client` and monkeypatch `b24pysdk`.

---

## 🐞 Troubleshooting
- **`Invalid JWT token`** — `.env` secret differs from the one used to issue the token. Re-issue via `/api/getToken`.
- **`JWT token has expired`** — increase TTL or implement auto-renewal on the frontend.
- **CSRF / iframe issues** — verify `VIRTUAL_HOST` and the Bitrix24 portal domain.
- **`BitrixValidationError` during install** — ensure payload has required fields (`domain`, `member_id`, `auth[access_token]`, etc.).
- **Database errors** — confirm the `database` container is running and reachable via `DB_HOST`.

---

## 📚 Additional resources
- `instructions/python/bitrix24-python-sdk.md` — SDK usage details and REST examples.
- `instructions/python/code-review.md` — Python code review checklist.
- `instructions/queues/python.md` — background processing (Celery/RabbitMQ) guidelines.
- Root `README.md` and `makefile` describe docker profiles and run scenarios for the entire stack.

*Updated: 5 December 2025.*
