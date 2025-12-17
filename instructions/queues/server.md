# 🐇 RabbitMQ queue server

## Why you need it
- Stores Bitrix24 events and background jobs so the web app stays responsive.
- Lives inside the Docker `queue` profile, so it starts only when requested.

## How to enable it
1. Run `make dev-init`.
2. Answer “y” when asked “Enable RabbitMQ for background tasks?”.
3. Choose a mode:
   - **Automatic** – the script generates login, password and prefetch, prints them, and writes them to `.env`.
   - **Manual** – enter the values yourself.

Flags and variables:
```
ENABLE_RABBITMQ=1
RABBITMQ_USER=queue_xxx
RABBITMQ_PASSWORD=***
RABBITMQ_PREFETCH=5
RABBITMQ_DSN=amqp://queue_xxx:...@rabbitmq:5672/%2f
```

## Docker Compose
- Service `rabbitmq` uses the `rabbitmq:3.13-management-alpine` image with ports `5672` and `15672`.
- Volume `rabbitmq_data` keeps messages, `logs/rabbitmq/` keeps logs.
- Add the `queue` profile to any stack that needs messaging.

## Access
- AMQP: `amqp://rabbitmq:5672`
- Management UI: <http://localhost:15672> (use the credentials stored in `.env`)

## Manual start / stop
- `make queue-up` — launches only RabbitMQ (pulls in the `queue` profile even if the core stack is down).
- `make queue-down` — stops RabbitMQ only, other containers keep running.
- Before starting, make sure `.env` contains `ENABLE_RABBITMQ=1`, otherwise the service will come up but env vars will not be populated automatically.

## Next steps
- Configure your backend according to the selected stack:
  - [PHP + Messenger](./php.md)
  - [Python + Celery](./python.md)
  - [Node.js + amqplib](./node.md)

