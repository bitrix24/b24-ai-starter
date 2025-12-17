# 🐍 Python + RabbitMQ

Celery configuration example for background task handlers. Assumes the starter’s Django/ASGI backend is in place.

## 1. Dependencies
`backends/python/api/requirements.txt`:
```
celery==5.4.0
kombu==5.3.5
```

Install and rebuild the container:
```bash
docker compose build api-python
```

## 2. Celery config (`backends/python/api/celery.py`)
```python
import os
from celery import Celery

broker_url = os.getenv(
    "CELERY_BROKER_URL",
    os.getenv("RABBITMQ_DSN", "amqp://queue_user:queue_password@rabbitmq:5672//"),
)

celery_app = Celery("b24_app", broker=broker_url)
celery_app.conf.task_acks_late = True
celery_app.conf.worker_prefetch_multiplier = int(
    os.getenv("RABBITMQ_PREFETCH", "5")
)
```

Add to `backends/python/api/__init__.py`:
```python
from .celery import celery_app  # noqa
```

## 3. Tasks (`backends/python/api/tasks.py`)
```python
from .celery import celery_app

@celery_app.task(name="bitrix24.process_event")
def process_event(event_code: str, payload: dict) -> None:
    # Interact with Bitrix24, the DB, etc.
    ...
```

## 4. Publishing jobs
```python
from .tasks import process_event

def webhook_view(request):
    payload = request.data
    process_event.delay(payload.get("event"), payload)
    return Response({"status": "queued"})
```

## 5. Environment variables
```
CELERY_BROKER_URL=${RABBITMQ_DSN}
```

## 6. Starting a worker
```bash
COMPOSE_PROFILES=python,queue docker compose --env-file .env run --rm \
  api-python celery -A api.celery.celery_app worker --loglevel=info
```

> For production, run the worker as a dedicated Docker service or under Supervisor/systemd.

