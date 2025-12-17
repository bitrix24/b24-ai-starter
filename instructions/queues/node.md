# 🟢 Node.js + RabbitMQ

Integration example built on `amqplib`. Works with both JavaScript and TypeScript (examples below use TS).

## 1. Dependencies
```bash
pnpm add amqplib
pnpm add -D typescript tsx @types/node # if you use TS
```

## 2. Client (`src/queue/rabbitmq.ts`)
```typescript
import amqp, { Connection, Channel } from "amqplib";

export class RabbitMQClient {
  private connection?: Connection;
  private channel?: Channel;

  async connect(url: string): Promise<Channel> {
    this.connection = await amqp.connect(url);
    this.channel = await this.connection.createChannel();
    return this.channel;
  }

  async close(): Promise<void> {
    await this.channel?.close();
    await this.connection?.close();
  }
}
```

## 3. Publisher (`src/services/queuePublisher.ts`)
```typescript
import { RabbitMQClient } from "../queue/rabbitmq";

export const publishEvent = async (
  queue: string,
  payload: Record<string, unknown>,
): Promise<void> => {
  const client = new RabbitMQClient();
  const channel = await client.connect(process.env.RABBITMQ_DSN!);

  await channel.assertQueue(queue, { durable: true });
  channel.sendToQueue(queue, Buffer.from(JSON.stringify(payload)), {
    persistent: true,
  });

  await client.close();
};
```

## 4. Consumer (`workers/eventWorker.ts`)
```typescript
import { RabbitMQClient } from "../src/queue/rabbitmq";

const QUEUE = "bitrix24.events";

async function bootstrap() {
  const client = new RabbitMQClient();
  const channel = await client.connect(process.env.RABBITMQ_DSN!);

  await channel.assertQueue(QUEUE, { durable: true });
  channel.prefetch(Number(process.env.RABBITMQ_PREFETCH || "5"));

  channel.consume(QUEUE, async (message) => {
    if (!message) {
      return;
    }

    const payload = JSON.parse(message.content.toString());
    // TODO: handle Bitrix24 event here

    channel.ack(message);
  });
}

bootstrap().catch((error) => {
  console.error("Worker failed", error);
  process.exit(1);
});
```

## 5. Environment vars
```
RABBITMQ_DSN=amqp://queue_user:queue_password@rabbitmq:5672/
```

## 6. Running the worker
```bash
COMPOSE_PROFILES=node,queue docker compose --env-file .env run --rm \
  api-node node workers/eventWorker.js
```

> For long-running processes, add a dedicated Docker service or use pm2.

