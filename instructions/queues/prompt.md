# 🧠 AI agent prompt: RabbitMQ setup

## Context
- Repository: `b24-ai-starter`
- Goal: enable and configure RabbitMQ for background jobs, and start/stop the service manually when needed.
- Infra references: `instructions/queues/server.md`, `README.md` (section “Queues and RabbitMQ”)

## Agent tasks
1. **Check whether RabbitMQ is enabled**
   - Inspect `.env` (or `versions/<name>/.env`) for `ENABLE_RABBITMQ=1`.
   - If missing, ask the user to enable it via `make dev-init` or manually.

2. **Configure credentials**
   - In automatic mode `dev-init` generates username/password and writes them to `.env`.
   - In manual mode ensure `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_PREFETCH`, `RABBITMQ_DSN` exist.

3. **Start and stop**
   - Use `make queue-up` for manual start.
   - Use `make queue-down` to stop.
   - Verify the main stack (e.g. `make dev-php`) includes the `queue` profile if RabbitMQ must run continuously.

4. **Validate availability**
   - AMQP: `amqp://rabbitmq:5672`
   - Admin UI: `http://localhost:15672` (credentials from `.env`)
   - Run `docker compose ps` to confirm the `rabbitmq` container is `Up`.

5. **Version synchronization**
   - If the user works inside `versions/<name>/`, run every command within that working copy.
   - Explain that `.env` changes in root vs versions are not synced automatically.

6. **Next steps**
   - Point to stack-specific guides (`queues/php.md`, `queues/python.md`, `queues/node.md`).
   - When workers appear, suggest adding dedicated Docker services or make targets.

## Warnings
- Never start RabbitMQ without `ENABLE_RABBITMQ=1`: the service will launch but stay unconfigured and agent commands can hang.
- While handling versions always confirm whether the queue should be enabled in root or `versions/v*`.
- After editing `.env` restart the Docker stack, otherwise the `queue` profile will not be picked up.

