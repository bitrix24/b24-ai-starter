# 🟢 Node.js Backend: Общие знания для разработки с Битрикс24

## 📋 Обзор

Этот файл содержит **общую информацию по разработке Node.js-приложений** для Битрикс24, не зависящую от конкретных задач. Для специфических инструкций обратитесь к соответствующим файлам в этой папке.

---

## 🚀 Node.js экосистема для Битрикс24

### Основные инструменты

#### Bitrix24 JavaScript SDK
- **Библиотека**: `@bitrix24/b24jssdk`
- **Версия**: Последняя стабильная
- **Требования**: Node.js 18+, ES2022+ поддержка
- **Лицензия**: MIT

#### Типичные зависимости (package.json)
```json
{
  "dependencies": {
    "@bitrix24/b24jssdk": "^2.0.0",
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "winston": "^3.11.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/express": "^4.17.21",
    "typescript": "^5.2.2",
    "tsx": "^4.0.0",
    "eslint": "^8.0.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "prettier": "^3.0.0",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.0",
    "supertest": "^6.3.3",
    "nodemon": "^3.0.0"
  }
}
```

### Типичная архитектура Node.js проекта

```
project/
├── src/
│   ├── app.ts                 # Express приложение
│   ├── server.ts              # HTTP сервер
│   ├── config/                # Конфигурация
│   │   ├── index.ts
│   │   └── database.ts
│   ├── controllers/           # HTTP контроллеры
│   │   ├── dealController.ts
│   │   └── contactController.ts
│   ├── services/              # Бизнес-логика
│   │   ├── bitrix24Service.ts
│   │   └── dealService.ts
│   ├── models/                # TypeScript типы
│   │   ├── Deal.ts
│   │   └── Contact.ts
│   ├── middleware/            # Express middleware
│   │   ├── auth.ts
│   │   ├── validation.ts
│   │   └── errorHandler.ts
│   ├── routes/                # API маршруты
│   │   ├── index.ts
│   │   ├── deals.ts
│   │   └── contacts.ts
│   └── utils/                 # Утилиты
│       ├── logger.ts
│       └── helpers.ts
├── tests/                     # Тесты
├── dist/                      # Скомпилированный JS
├── package.json
├── tsconfig.json
├── .env
└── Dockerfile
```

---

## 🔧 Основные паттерны разработки

### 1. Инициализация SDK

#### Простая инициализация (TypeScript)
```typescript
// config/bitrix24.ts
import { Bitrix24 } from '@bitrix24/b24jssdk';

interface Bitrix24Config {
  webhookUrl?: string;
  domain?: string;
  clientId?: string;
  clientSecret?: string;
}

export class Bitrix24Service {
  private b24: Bitrix24;

  constructor(config: Bitrix24Config) {
    if (config.webhookUrl) {
      // Инициализация через webhook
      this.b24 = new Bitrix24({
        webhookUrl: config.webhookUrl
      });
    } else {
      // Инициализация для OAuth приложения
      this.b24 = new Bitrix24({
        domain: config.domain!,
        clientId: config.clientId!,
        clientSecret: config.clientSecret!
      });
    }
  }

  public getB24Instance(): Bitrix24 {
    return this.b24;
  }
}
```

#### С конфигурацией через переменные окружения
```typescript
// config/index.ts
import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  bitrix24: {
    webhookUrl: process.env.BITRIX24_WEBHOOK_URL,
    domain: process.env.BITRIX24_DOMAIN,
    clientId: process.env.BITRIX24_CLIENT_ID,
    clientSecret: process.env.BITRIX24_CLIENT_SECRET,
  },
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  }
};

// services/bitrix24Service.ts
import { config } from '../config';
import { Bitrix24Service } from '../config/bitrix24';

export const bitrix24Service = new Bitrix24Service(config.bitrix24);
```

### 2. Работа с данными CRM (с типизацией)

```typescript
// models/Deal.ts
export interface Deal {
  ID: string;
  TITLE: string;
  OPPORTUNITY?: string;
  CURRENCY_ID?: string;
  STAGE_ID?: string;
  DATE_CREATE?: string;
  DATE_MODIFY?: string;
  CONTACT_ID?: string;
  COMPANY_ID?: string;
}

export interface DealCreateData {
  TITLE: string;
  OPPORTUNITY?: number;
  CURRENCY_ID?: string;
  STAGE_ID?: string;
  CONTACT_ID?: string;
  COMPANY_ID?: string;
}

export interface DealUpdateData {
  TITLE?: string;
  OPPORTUNITY?: number;
  STAGE_ID?: string;
}

// services/dealService.ts
import { Bitrix24 } from '@bitrix24/b24jssdk';
import { Deal, DealCreateData, DealUpdateData } from '../models/Deal';

export class DealService {
  constructor(private b24: Bitrix24) {}

  async getDeals(filter?: Record<string, any>, select?: string[]): Promise<Deal[]> {
    try {
      const response = await this.b24.crm.deals.list({
        filter: filter || {},
        select: select || ['ID', 'TITLE', 'OPPORTUNITY', 'STAGE_ID', 'DATE_CREATE']
      });
      
      return response.data || [];
    } catch (error) {
      throw new Error(`Failed to fetch deals: ${error.message}`);
    }
  }

  async getDealById(id: string): Promise<Deal | null> {
    try {
      const response = await this.b24.crm.deals.get({ id });
      return response.data || null;
    } catch (error) {
      console.error(`Deal ${id} not found:`, error);
      return null;
    }
  }

  async createDeal(dealData: DealCreateData): Promise<string> {
    try {
      const response = await this.b24.crm.deals.add({ fields: dealData });
      return response.data;
    } catch (error) {
      throw new Error(`Failed to create deal: ${error.message}`);
    }
  }

  async updateDeal(id: string, updateData: DealUpdateData): Promise<boolean> {
    try {
      const response = await this.b24.crm.deals.update({
        id,
        fields: updateData
      });
      return !!response.data;
    } catch (error) {
      throw new Error(`Failed to update deal ${id}: ${error.message}`);
    }
  }

  async getActiveDealsByStage(): Promise<Record<string, Deal[]>> {
    const activeStages = ['NEW', 'PREPARATION', 'PROPOSAL'];
    const dealsByStage: Record<string, Deal[]> = {};

    for (const stage of activeStages) {
      const deals = await this.getDeals({ STAGE_ID: stage });
      dealsByStage[stage] = deals;
    }

    return dealsByStage;
  }
}
```

### 3. Express контроллеры с валидацией

```typescript
// controllers/dealController.ts
import { Request, Response, NextFunction } from 'express';
import { DealService } from '../services/dealService';
import { validateDealData } from '../middleware/validation';

export class DealController {
  constructor(private dealService: DealService) {}

  // Получение списка сделок
  public getDeals = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { stage, limit = '50' } = req.query;
      
      const filter: Record<string, any> = {};
      if (stage) {
        filter.STAGE_ID = stage;
      }

      const deals = await this.dealService.getDeals(filter);
      const limitedDeals = deals.slice(0, parseInt(limit as string, 10));

      res.json({
        success: true,
        data: limitedDeals,
        total: deals.length
      });
    } catch (error) {
      next(error);
    }
  };

  // Получение сделки по ID
  public getDealById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const deal = await this.dealService.getDealById(id);

      if (!deal) {
        res.status(404).json({
          success: false,
          message: 'Deal not found'
        });
        return;
      }

      res.json({
        success: true,
        data: deal
      });
    } catch (error) {
      next(error);
    }
  };

  // Создание новой сделки
  public createDeal = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const dealData = req.body;
      
      // Валидация происходит в middleware
      const dealId = await this.dealService.createDeal(dealData);

      res.status(201).json({
        success: true,
        data: { id: dealId },
        message: 'Deal created successfully'
      });
    } catch (error) {
      next(error);
    }
  };

  // Обновление сделки
  public updateDeal = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const updateData = req.body;

      const success = await this.dealService.updateDeal(id, updateData);
      
      if (!success) {
        res.status(404).json({
          success: false,
          message: 'Deal not found or update failed'
        });
        return;
      }

      res.json({
        success: true,
        message: 'Deal updated successfully'
      });
    } catch (error) {
      next(error);
    }
  };
}
```

### 4. Middleware и валидация

```typescript
// middleware/validation.ts
import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';

const dealCreateSchema = Joi.object({
  TITLE: Joi.string().min(1).max(255).required(),
  OPPORTUNITY: Joi.number().min(0).optional(),
  CURRENCY_ID: Joi.string().length(3).default('RUB'),
  STAGE_ID: Joi.string().optional(),
  CONTACT_ID: Joi.string().optional(),
  COMPANY_ID: Joi.string().optional()
});

const dealUpdateSchema = Joi.object({
  TITLE: Joi.string().min(1).max(255).optional(),
  OPPORTUNITY: Joi.number().min(0).optional(),
  STAGE_ID: Joi.string().optional()
});

export const validateDealCreate = (req: Request, res: Response, next: NextFunction): void => {
  const { error, value } = dealCreateSchema.validate(req.body);
  
  if (error) {
    res.status(400).json({
      success: false,
      message: 'Validation error',
      details: error.details.map(d => d.message)
    });
    return;
  }
  
  req.body = value;
  next();
};

export const validateDealUpdate = (req: Request, res: Response, next: NextFunction): void => {
  const { error, value } = dealUpdateSchema.validate(req.body);
  
  if (error) {
    res.status(400).json({
      success: false,
      message: 'Validation error',
      details: error.details.map(d => d.message)
    });
    return;
  }
  
  req.body = value;
  next();
};
```

---

## 🏗️ Архитектурные подходы

### 1. Dependency Injection

```typescript
// services/ServiceContainer.ts
export class ServiceContainer {
  private services: Map<string, any> = new Map();

  register<T>(name: string, service: T): void {
    this.services.set(name, service);
  }

  get<T>(name: string): T {
    const service = this.services.get(name);
    if (!service) {
      throw new Error(`Service ${name} not found`);
    }
    return service;
  }
}

// Инициализация контейнера
export const container = new ServiceContainer();

// Регистрация сервисов
import { bitrix24Service } from './bitrix24Service';
import { DealService } from './dealService';

const dealService = new DealService(bitrix24Service.getB24Instance());
container.register('dealService', dealService);

// Использование в контроллерах
import { container } from '../services/ServiceContainer';

export class DealController {
  private dealService: DealService;

  constructor() {
    this.dealService = container.get<DealService>('dealService');
  }
}
```

### 2. Repository паттерн с TypeScript

```typescript
// repositories/IDealRepository.ts
export interface IDealRepository {
  findById(id: string): Promise<Deal | null>;
  findByStage(stage: string): Promise<Deal[]>;
  create(data: DealCreateData): Promise<string>;
  update(id: string, data: DealUpdateData): Promise<boolean>;
  delete(id: string): Promise<boolean>;
}

// repositories/Bitrix24DealRepository.ts
import { Bitrix24 } from '@bitrix24/b24jssdk';
import { Deal, DealCreateData, DealUpdateData } from '../models/Deal';
import { IDealRepository } from './IDealRepository';

export class Bitrix24DealRepository implements IDealRepository {
  constructor(private b24: Bitrix24) {}

  async findById(id: string): Promise<Deal | null> {
    try {
      const response = await this.b24.crm.deals.get({ id });
      return response.data || null;
    } catch (error) {
      console.error(`Deal ${id} not found:`, error);
      return null;
    }
  }

  async findByStage(stage: string): Promise<Deal[]> {
    try {
      const response = await this.b24.crm.deals.list({
        filter: { STAGE_ID: stage },
        select: ['ID', 'TITLE', 'OPPORTUNITY', 'STAGE_ID', 'DATE_CREATE']
      });
      return response.data || [];
    } catch (error) {
      throw new Error(`Failed to fetch deals by stage ${stage}: ${error.message}`);
    }
  }

  async create(data: DealCreateData): Promise<string> {
    try {
      const response = await this.b24.crm.deals.add({ fields: data });
      return response.data;
    } catch (error) {
      throw new Error(`Failed to create deal: ${error.message}`);
    }
  }

  async update(id: string, data: DealUpdateData): Promise<boolean> {
    try {
      const response = await this.b24.crm.deals.update({ id, fields: data });
      return !!response.data;
    } catch (error) {
      throw new Error(`Failed to update deal ${id}: ${error.message}`);
    }
  }

  async delete(id: string): Promise<boolean> {
    try {
      const response = await this.b24.crm.deals.delete({ id });
      return !!response.data;
    } catch (error) {
      throw new Error(`Failed to delete deal ${id}: ${error.message}`);
    }
  }
}
```

### 3. Event-driven архитектура

```typescript
// events/EventEmitter.ts
import { EventEmitter } from 'events';

export interface DealEvents {
  'deal:created': (dealId: string, dealData: DealCreateData) => void;
  'deal:updated': (dealId: string, updateData: DealUpdateData) => void;
  'deal:deleted': (dealId: string) => void;
}

export class DealEventEmitter extends EventEmitter {
  emit<K extends keyof DealEvents>(
    event: K,
    ...args: Parameters<DealEvents[K]>
  ): boolean {
    return super.emit(event, ...args);
  }

  on<K extends keyof DealEvents>(
    event: K,
    listener: DealEvents[K]
  ): this {
    return super.on(event, listener);
  }
}

export const dealEvents = new DealEventEmitter();

// services/dealService.ts (с событиями)
import { dealEvents } from '../events/EventEmitter';

export class DealService {
  async createDeal(dealData: DealCreateData): Promise<string> {
    const dealId = await this.repository.create(dealData);
    
    // Эмитим событие
    dealEvents.emit('deal:created', dealId, dealData);
    
    return dealId;
  }
}

// Подписка на события
dealEvents.on('deal:created', async (dealId, dealData) => {
  console.log(`New deal created: ${dealId}`);
  
  // Отправляем уведомление, логируем, синхронизируем с другими системами
  // await notificationService.sendDealCreatedNotification(dealId, dealData);
});
```

---

## 🔐 Безопасность и best practices

### 1. Обработка ошибок

```typescript
// middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export interface AppError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export const errorHandler = (
  error: AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const { statusCode = 500, message, stack } = error;

  logger.error('Error occurred', {
    error: message,
    stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  // В production не показываем stack trace
  const response = {
    success: false,
    message: statusCode === 500 ? 'Internal Server Error' : message,
    ...(process.env.NODE_ENV === 'development' && { stack })
  };

  res.status(statusCode).json(response);
};

// Создание кастомных ошибок
export class ValidationError extends Error implements AppError {
  statusCode = 400;
  isOperational = true;

  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends Error implements AppError {
  statusCode = 404;
  isOperational = true;

  constructor(message: string = 'Resource not found') {
    super(message);
    this.name = 'NotFoundError';
  }
}
```

### 2. Rate limiting и кэширование

```typescript
// middleware/rateLimit.ts
import rateLimit from 'express-rate-limit';
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 минут
  max: 100, // лимит 100 запросов на IP
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
});

// services/CacheService.ts
export class CacheService {
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    try {
      const cached = await this.redis.get(key);
      return cached ? JSON.parse(cached) : null;
    } catch (error) {
      console.error(`Cache get error for key ${key}:`, error);
      return null;
    }
  }

  async set(key: string, value: any, ttl: number = 300): Promise<void> {
    try {
      await this.redis.setex(key, ttl, JSON.stringify(value));
    } catch (error) {
      console.error(`Cache set error for key ${key}:`, error);
    }
  }

  async del(key: string): Promise<void> {
    try {
      await this.redis.del(key);
    } catch (error) {
      console.error(`Cache delete error for key ${key}:`, error);
    }
  }
}

// Кэшированный сервис сделок
export class CachedDealService extends DealService {
  constructor(
    b24: Bitrix24,
    private cache: CacheService
  ) {
    super(b24);
  }

  async getDealById(id: string): Promise<Deal | null> {
    const cacheKey = `deal:${id}`;
    
    // Проверяем кэш
    const cached = await this.cache.get<Deal>(cacheKey);
    if (cached) {
      return cached;
    }

    // Получаем из API
    const deal = await super.getDealById(id);
    if (deal) {
      // Кэшируем на 5 минут
      await this.cache.set(cacheKey, deal, 300);
    }

    return deal;
  }
}
```

### 3. Валидация и санитизация

```typescript
// utils/sanitization.ts
import DOMPurify from 'isomorphic-dompurify';
import { escape } from 'html-escaper';

export class DataSanitizer {
  static sanitizeString(input: string): string {
    if (!input || typeof input !== 'string') {
      return '';
    }
    
    // Удаляем HTML теги
    const cleaned = DOMPurify.sanitize(input, { ALLOWED_TAGS: [] });
    
    // Экранируем специальные символы
    return escape(cleaned.trim());
  }

  static sanitizeDealData(data: any): DealCreateData {
    return {
      TITLE: this.sanitizeString(data.TITLE),
      OPPORTUNITY: this.sanitizeNumber(data.OPPORTUNITY),
      CURRENCY_ID: this.sanitizeString(data.CURRENCY_ID),
      STAGE_ID: this.sanitizeString(data.STAGE_ID),
      CONTACT_ID: this.sanitizeString(data.CONTACT_ID),
      COMPANY_ID: this.sanitizeString(data.COMPANY_ID)
    };
  }

  private static sanitizeNumber(input: any): number | undefined {
    if (input === null || input === undefined) {
      return undefined;
    }
    
    const num = Number(input);
    return isNaN(num) ? undefined : Math.max(0, num);
  }
}
```

---

## 🧪 Тестирование

### Unit тесты с Jest

```typescript
// tests/services/dealService.test.ts
import { DealService } from '../../src/services/dealService';
import { Bitrix24 } from '@bitrix24/b24jssdk';

// Mock Bitrix24 SDK
jest.mock('@bitrix24/b24jssdk');

describe('DealService', () => {
  let dealService: DealService;
  let mockB24: jest.Mocked<Bitrix24>;

  beforeEach(() => {
    mockB24 = {
      crm: {
        deals: {
          list: jest.fn(),
          get: jest.fn(),
          add: jest.fn(),
          update: jest.fn()
        }
      }
    } as any;

    dealService = new DealService(mockB24);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getDeals', () => {
    it('should return array of deals', async () => {
      const mockDeals = [
        { ID: '1', TITLE: 'Deal 1', OPPORTUNITY: '1000' },
        { ID: '2', TITLE: 'Deal 2', OPPORTUNITY: '2000' }
      ];

      mockB24.crm.deals.list.mockResolvedValue({ data: mockDeals });

      const result = await dealService.getDeals();

      expect(result).toEqual(mockDeals);
      expect(mockB24.crm.deals.list).toHaveBeenCalledWith({
        filter: {},
        select: ['ID', 'TITLE', 'OPPORTUNITY', 'STAGE_ID', 'DATE_CREATE']
      });
    });

    it('should handle API errors gracefully', async () => {
      mockB24.crm.deals.list.mockRejectedValue(new Error('API Error'));

      await expect(dealService.getDeals()).rejects.toThrow('Failed to fetch deals: API Error');
    });
  });

  describe('createDeal', () => {
    it('should create deal and return ID', async () => {
      const dealData = {
        TITLE: 'New Deal',
        OPPORTUNITY: 5000,
        CURRENCY_ID: 'RUB'
      };

      mockB24.crm.deals.add.mockResolvedValue({ data: '123' });

      const result = await dealService.createDeal(dealData);

      expect(result).toBe('123');
      expect(mockB24.crm.deals.add).toHaveBeenCalledWith({ fields: dealData });
    });
  });
});
```

### Integration тесты

```typescript
// tests/integration/deals.integration.test.ts
import request from 'supertest';
import { app } from '../../src/app';

describe('Deals API Integration', () => {
  describe('GET /api/deals', () => {
    it('should return list of deals', async () => {
      const response = await request(app)
        .get('/api/deals')
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('data');
      expect(Array.isArray(response.body.data)).toBe(true);
    });

    it('should filter deals by stage', async () => {
      const response = await request(app)
        .get('/api/deals?stage=NEW')
        .expect(200);

      expect(response.body.success).toBe(true);
      // Проверяем, что все возвращенные сделки имеют стадию NEW
      response.body.data.forEach((deal: any) => {
        expect(deal.STAGE_ID).toBe('NEW');
      });
    });
  });

  describe('POST /api/deals', () => {
    it('should create new deal', async () => {
      const newDeal = {
        TITLE: 'Integration Test Deal',
        OPPORTUNITY: 10000,
        CURRENCY_ID: 'RUB'
      };

      const response = await request(app)
        .post('/api/deals')
        .send(newDeal)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('id');
      expect(response.body.message).toBe('Deal created successfully');
    });

    it('should validate required fields', async () => {
      const invalidDeal = {
        OPPORTUNITY: 10000
        // TITLE отсутствует
      };

      const response = await request(app)
        .post('/api/deals')
        .send(invalidDeal)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toBe('Validation error');
    });
  });
});
```

---

## 📊 Мониторинг и производительность

### 1. Логирование с Winston

```typescript
// utils/logger.ts
import winston from 'winston';

const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: { service: 'bitrix24-api' },
  transports: [
    // Запись в файл для ошибок
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error'
    }),
    // Запись в файл для всех логов
    new winston.transports.File({
      filename: 'logs/combined.log'
    })
  ]
});

// В development режиме также выводим в консоль
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

// HTTP запросы middleware
export const requestLogger = (req: Request, res: Response, next: NextFunction): void => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });
  });

  next();
};
```

### 2. Метрики производительности

```typescript
// middleware/metrics.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

interface PerformanceMetrics {
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  averageResponseTime: number;
  responseTimes: number[];
}

class MetricsCollector {
  private metrics: PerformanceMetrics = {
    totalRequests: 0,
    successfulRequests: 0,
    failedRequests: 0,
    averageResponseTime: 0,
    responseTimes: []
  };

  collectMetrics = (req: Request, res: Response, next: NextFunction): void => {
    const startTime = process.hrtime();

    res.on('finish', () => {
      const [seconds, nanoseconds] = process.hrtime(startTime);
      const responseTime = seconds * 1000 + nanoseconds / 1e6; // в миллисекундах

      this.metrics.totalRequests++;
      this.metrics.responseTimes.push(responseTime);

      if (res.statusCode < 400) {
        this.metrics.successfulRequests++;
      } else {
        this.metrics.failedRequests++;
      }

      // Пересчитываем среднее время ответа
      this.metrics.averageResponseTime = 
        this.metrics.responseTimes.reduce((sum, time) => sum + time, 0) / 
        this.metrics.responseTimes.length;

      // Логируем медленные запросы
      if (responseTime > 1000) {
        logger.warn('Slow request detected', {
          url: req.url,
          method: req.method,
          responseTime,
          statusCode: res.statusCode
        });
      }
    });

    next();
  };

  getMetrics(): PerformanceMetrics {
    return { ...this.metrics };
  }

  resetMetrics(): void {
    this.metrics = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      averageResponseTime: 0,
      responseTimes: []
    };
  }
}

export const metricsCollector = new MetricsCollector();

// Endpoint для получения метрик
export const getMetricsHandler = (req: Request, res: Response): void => {
  const metrics = metricsCollector.getMetrics();
  
  res.json({
    success: true,
    data: {
      ...metrics,
      uptime: process.uptime(),
      memoryUsage: process.memoryUsage(),
      timestamp: new Date().toISOString()
    }
  });
};
```

### 3. Health check endpoints

```typescript
// routes/health.ts
import { Router, Request, Response } from 'express';
import { bitrix24Service } from '../services/bitrix24Service';
import { logger } from '../utils/logger';

const router = Router();

// Базовая проверка здоровья
router.get('/', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Проверка подключения к Bitrix24
router.get('/bitrix24', async (req: Request, res: Response) => {
  try {
    const b24 = bitrix24Service.getB24Instance();
    
    // Выполняем простой запрос для проверки соединения
    await b24.crm.deals.list({ limit: 1 });

    res.json({
      status: 'healthy',
      service: 'bitrix24',
      connection: 'ok',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Bitrix24 health check failed', { error: error.message });
    
    res.status(503).json({
      status: 'unhealthy',
      service: 'bitrix24',
      connection: 'failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

export { router as healthRouter };
```

---

## 🔧 DevOps и развертывание

### Docker

```dockerfile
# Dockerfile
FROM node:18-alpine

# Установка рабочей директории
WORKDIR /app

# Копирование файлов зависимостей
COPY package*.json ./

# Установка зависимостей
RUN npm ci --only=production

# Копирование исходного кода
COPY . .

# Компиляция TypeScript
RUN npm run build

# Создание пользователя без root прав
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Изменение владельца файлов
USER nextjs

# Экспорт порта
EXPOSE 3000

# Переменные окружения
ENV NODE_ENV=production

# Запуск приложения
CMD ["node", "dist/server.js"]
```

### docker-compose для разработки

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - BITRIX24_WEBHOOK_URL=${BITRIX24_WEBHOOK_URL}
      - REDIS_URL=redis://redis:6379
    volumes:
      - ./src:/app/src
      - ./tests:/app/tests
    depends_on:
      - redis
    
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

---

## 📚 Специфические инструкции

### Детальные руководства в этой папке:

**➡️ Code Review стандарты:** [`code-review.md`](code-review.md)

---

## ⚠️ Часто встречающиеся проблемы

### 1. Memory leaks в long-running приложениях

**Проблема:** Утечки памяти при обработке больших объемов данных
**Решение:** Правильное управление объектами, использование streams, мониторинг памяти

### 2. Callback hell и Promise chains

**Проблема:** Сложно читаемый асинхронный код
**Решение:** Использование async/await, правильная структура Promise chains

### 3. Unhandled Promise rejections

**Проблема:** Необработанные отклонения промисов приводят к падению приложения
**Решение:** Глобальные обработчики ошибок, правильное использование try/catch

```typescript
// Глобальная обработка необработанных промисов
process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
  logger.error('Unhandled Rejection', {
    reason: reason.toString(),
    promise: promise.toString()
  });
  
  // Graceful shutdown
  process.exit(1);
});

process.on('uncaughtException', (error: Error) => {
  logger.error('Uncaught Exception', { error: error.message, stack: error.stack });
  
  // Graceful shutdown
  process.exit(1);
});
```

---

*Обновлено: 25 ноября 2025*
*Версия: 2.0 - Модульная архитектура знаний*