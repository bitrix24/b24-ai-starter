# 📚 Bitrix24 Knowledge Hub

## 🎯 Purpose

This file is the **central knowledge hub** for AI agents working on Bitrix24 applications. It contains **language-agnostic guidelines** plus links to specialized documents.

## 🏗️ Knowledge Architecture

```
knowledge.md (this file) — central hub
├── backend/
│   ├── php/knowledge.md
│   ├── python/knowledge.md
│   └── node/knowledge.md
├── frontend/knowledge.md
└── queues/
    ├── server.md
    ├── php.md
    ├── python.md
    └── node.md
```

---

## 🌐 Bitrix24 Application Architecture

The starter provides a Bitrix24 app skeleton that uses a simplified OAuth 2.0 installation flow. Out of the box it registers two widgets: a CRM deal tab and a custom CRM field widget.

### System components

**REST API**
- Single entry point to portal data
- OAuth 2.0 authorization for apps
- Webhook notifications for events
- Batch requests for performance

**Bitrix24 JavaScript SDK**
- Client-side API wrapper
- Portal UI management
- UI event handling

**UI Kit / design system**
- Bitrix24-styled components
- Consistent UX across apps
- Responsive by design

---

## 📊 Core CRM Entities

- **Leads:** potential customers, first contact, can convert into deals or contacts
- **Deals:** sales opportunities with pipeline stages, linked to contacts/companies
- **Contacts:** individual clients, personal data, interaction history
- **Companies:** corporate clients, linked contacts, organization data
- **Activities:** calls, meetings, tasks, scheduling, CRM analytics

---

## 🔧 Choosing a Tech Stack

### Backend

- **PHP:** see [`php/knowledge.md`](php/knowledge.md)
- **Python:** see [`python/knowledge.md`](python/knowledge.md)
- **Node.js:** see [`node/knowledge.md`](node/knowledge.md) (recommended for full-stack JS)

### Frontend

Use the patterns documented in [`frontend/knowledge.md`](frontend/knowledge.md) regardless of backend choice.

## 🛡️ Manual Security Checks

- Run `make security-scan` to execute `scripts/security-scan.sh`.
- The script launches `composer audit --locked --format=json` (PHP backend) and `pnpm audit --prod --json` (Nuxt frontend) inside Docker containers.
- Reports are stored under `reports/security/` for easy sharing (CI, issue trackers, etc.).
- Non-zero exit on vulnerabilities; override via `SECURITY_SCAN_ALLOW_FAILURES=1 make security-scan` or `./scripts/security-scan.sh --allow-fail`.
- The script never runs automatically — developers decide when to audit dependencies.

---

## 🎯 Specialized Instructions

### Bitrix24 platform

- Entry point: [`instructions/bitrix24/`](bitrix24/)
  - **CRM robots:** [`bitrix24/crm-robot.md`](bitrix24/crm-robot.md)
  - **Widgets:** [`bitrix24/widget.md`](bitrix24/widget.md)

### Version management

- Prompt: [`versioning/create-version-prompt.md`](versioning/create-version-prompt.md)
  - How to run `scripts/create-version.sh`
  - Checklists, rollback scenarios, tips for new contributors

### Queues & background jobs

- Server setup: [`queues/server.md`](queues/server.md)
- Stack examples:
  - PHP + Messenger — [`queues/php.md`](queues/php.md)
  - Python + Celery — [`queues/python.md`](queues/python.md)
  - Node.js + amqplib — [`queues/node.md`](queues/node.md)
- Dedicated AI prompt — [`queues/prompt.md`](queues/prompt.md)

---

## 🔄 Workflow for AI Agents

### Step 1 — Understand the problem
1. What’s the primary functionality (CRM/tasks/calendar/reports)?
2. Which data types are involved (leads/deals/contacts/companies)?
3. Which Bitrix24 mechanisms are required (widgets/robots/event handlers)?

### Step 2 — Choose the stack
1. Pick PHP/Python/Node.js based on requirements.
2. Frontend must rely on Bitrix24 UI Kit for consistent UX.

### Step 3 — Read specialized docs
1. Open `[stack]/knowledge.md` for language-specific fundamentals.
2. Dive into subtopics only when needed.
3. Check `bitrix24/` for platform edge cases.

### Step 4 — Implement
1. Follow `[stack]/code-review.md` rules.
2. Respect typing and best practices of the language.
3. Test against the Bitrix24 API.

---

## 📚 Additional Resources

- **REST API:** <https://apidocs.bitrix24.com>  
- **JavaScript SDK:** <https://github.com/bitrix24/b24jssdk>
- **Bitrix24 UI Kit:** <https://bitrix24.github.io/b24ui/llms-full.txt>

---

## ⚠️ Guidelines for AI Agents

### 🎯 Focused learning
- Don’t load every document at once.
- Only read sections relevant to the task.
- Treat this file as a navigation center.

### 🔄 Iterative approach
- Understand architecture first.
- Pick technologies second.
- Study detailed docs third.

### 📖 Keep information fresh
- Verify SDK and API versions.
- Watch for deprecated methods.
- Use modern development practices.

---

*Updated: 25 November 2025*  
*Version: 2.0 — Modular knowledge architecture*
