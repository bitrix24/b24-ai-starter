# AI playbook: @bitrix24/b24jssdk

## TL;DR
`@bitrix24/b24jssdk` is the official JS SDK for Bitrix24 REST. Use it to call API methods, control UI (sliders, dialogs, frame resize), stream events via Pull Client, and manage OAuth tokens automatically. Current release: `0.4.10` (ESM/UMD only, Node 18/20/22). License: MIT.

## Installation
```bash
npm install @bitrix24/b24jssdk
```
UMD build:
```html
<script src="https://unpkg.com/@bitrix24/b24jssdk@latest/dist/umd/index.min.js"></script>
```
Nuxt module:
```bash
npx nuxi module add @bitrix24/b24jssdk-nuxt
```
Docs: [Node](https://github.com/bitrix24/b24jssdk/blob/main/docs/guide/getting-started.md) · [UMD](https://github.com/bitrix24/b24jssdk/blob/main/docs/guide/getting-started-umd.md) · [Nuxt](https://github.com/bitrix24/b24jssdk/blob/main/docs/guide/getting-started-nuxt.md). Sample projects: [node hook](https://github.com/bitrix24/b24sdk-examples/tree/main/js/05-node-hook), [nuxt frame](https://github.com/bitrix24/b24sdk-examples/tree/main/js/02-nuxt-hook), [nuxt oauth](https://github.com/bitrix24/b24sdk-examples/tree/main/js/08-nuxt-oauth).

## Operating modes
### B24Frame — iframe apps inside Bitrix24
```ts
import { initializeB24Frame } from '@bitrix24/b24jssdk'
const $b24 = await initializeB24Frame()
const deals = await $b24.callMethod('crm.deal.list', { select: ['ID', 'TITLE'] })
$b24.destroy()
```
References: [frame.ts](https://github.com/bitrix24/b24jssdk/blob/main/packages/jssdk/src/frame/frame.ts), [init docs](https://github.com/bitrix24/b24jssdk/blob/main/docs/reference/frame-initialize-b24-frame.md).

### B24Hook — server/webhook integrations
```ts
import { B24Hook } from '@bitrix24/b24jssdk'
const $b24 = B24Hook.fromWebhookUrl('https://domain.bitrix24.com/rest/1/secret')
$b24.offClientSideWarning() // keep this server-side only
```
Docs: [controller](https://github.com/bitrix24/b24jssdk/blob/main/packages/jssdk/src/hook/controller.ts), [reference](https://github.com/bitrix24/b24jssdk/blob/main/docs/reference/hook-index.md). Never run B24Hook in the browser.

### B24OAuth — experimental OAuth controller
```ts
import { B24OAuth } from '@bitrix24/b24jssdk'
const $b24 = new B24OAuth({ clientId, clientSecret })
await $b24.auth.handleOAuthCallback(params)
```
Still experimental; prefer Frame/Hook in production.

## REST calls
```ts
const deal = await $b24.callMethod('crm.deal.get', { id: 123 })
const batch = await $b24.callBatch({
  deals: { method: 'crm.deal.list', params: { select: ['ID'] } },
  contacts: { method: 'crm.contact.list', params: { select: ['ID'] } },
}, true)
```
Large datasets: `callListMethod` (loads everything, <1k records) or `fetchListMethod` to stream chunks.

## Error handling
```ts
import { AjaxError } from '@bitrix24/b24jssdk'
try {
  const response = await $b24.callMethod('crm.deal.get', { id: 999 })
  if (response.isSuccess) {
    const data = response.getData()
  }
} catch (error) {
  if (error instanceof AjaxError) {
    console.error(error.code, error.message, error.requestInfo)
  }
}
```

## UI helpers (Frame only)
- **Sliders**: `slider.getUrl`, `slider.openPath`, `slider.openSliderAppPage()`.
- **Dialogs**: `dialog.selectUser()` / `selectUsers()`.
- **Parent window**: `parent.fitWindow()`, `resizeWindow`, `setTitle`, `closeApplication`.
- **Options**: `options.appSet/appGet`, `options.userSet/userGet`.

Docs: [slider](https://github.com/bitrix24/b24jssdk/blob/main/docs/reference/frame-slider.md), [dialog](https://github.com/bitrix24/b24jssdk/blob/main/docs/reference/frame-dialog.md), [parent](https://github.com/bitrix24/b24jssdk/blob/main/docs/reference/frame-parent.md), [options](https://github.com/bitrix24/b24jssdk/blob/main/docs/reference/frame-options.md).

## Helpers & Pull Client
```ts
import { useB24Helper, LoadDataType } from '@bitrix24/b24jssdk'
const helperApi = useB24Helper()
const $b24 = await initializeB24Frame()
await helperApi.initB24Helper($b24, [LoadDataType.Profile, LoadDataType.App, LoadDataType.Currency])
const profile = helperApi.getB24Helper().profileInfo.data
helperApi.useSubscribePullClient(msg => console.log(msg), 'application')
helperApi.startPullClient()
```

## Utilities
Type checking (`Type.isStringFilled`), text helpers (`Text.toDateTime`, `Text.getUuidRfc4122`, `Text.numberFormat`), logging (`LoggerBrowser.build('App', true)`), enums (`EnumCrmEntityTypeId`). Types live under `packages/jssdk/src/types` (Auth, HTTP, CRM entities, payloads, placement, etc.).

## REST limits
`RestrictionManager` throttles requests automatically (batch size defaults to 50). For Enterprise portals adjust via `http.setRestrictionManagerParams(RestrictionManagerParamsForEnterprise)`.

## Debug workflow
1. Inspect the source file (table of links provided in README).
2. Read the official docs: <https://bitrix24.github.io/b24jssdk/> (reference + README-AI).
3. Cross-check Bitrix24 REST docs (<https://apidocs.bitrix24.com/>).
4. Study real examples (b24sdk-examples repo).
5. Review `CHANGELOG.md` for breaking changes.
6. If blocked, open a GitHub issue.

## Common issues
| Symptom | Fix |
|--------|-----|
| `B24Frame is not initialized` | Always `await initializeB24Frame()` before using `$b24`. |
| `invalid_token` | Tokens auto-refresh; ensure `$b24.auth.refreshAuth()` is allowed to run. |
| Batch limit exceeded | Split payload or use `callBatchByChunk`. |
| Hook warning in browser | Move logic server-side; B24Hook is backend-only. |

## Best practices
- `await initializeB24Frame()` and call `$b24.destroy()` during teardown.
- Wrap API calls with `try/catch` and handle `AjaxError`.
- Prefer `fetchListMethod` for datasets > 1k rows.
- Check `response.isSuccess` before using payloads.
- Use TypeScript types (`TypeB24`, entity enums) for safety.
- Log via `LoggerBrowser` (and attach to B24Hook HTTP client).
- Never run B24Hook client-side or skip `await` on async calls.
- Respect REST limits; rely on `RestrictionManager` instead of ad-hoc throttling.

## Starter snippets
**Frontend**
```ts
import { initializeB24Frame } from '@bitrix24/b24jssdk'
import { useB24Helper, LoadDataType } from '@bitrix24/b24jssdk'

let $b24

async function init() {
  $b24 = await initializeB24Frame()
  const { initB24Helper } = useB24Helper()
  await initB24Helper($b24, [LoadDataType.Profile])
}

function cleanup() {
  const { destroyB24Helper } = useB24Helper()
  destroyB24Helper()
  $b24?.destroy()
}
```

**Backend**
```ts
import { B24Hook, LoggerBrowser } from '@bitrix24/b24jssdk'
const logger = LoggerBrowser.build('App', true)
const $b24 = B24Hook.fromWebhookUrl(process.env.B24_WEBHOOK_URL!)
$b24.setLogger(logger)

export async function fetchDeals() {
  try {
    const res = await $b24.callMethod('crm.deal.list', { select: ['ID'] })
    return res.getData()
  } catch (error) {
    logger.error('API error', error)
    throw error
  }
}
```

## Performance tips
1. Batch related methods where possible.
2. Use `fetchListMethod()` streams for large datasets.
3. Let `RestrictionManager` handle throttling instead of manual sleeps.
4. Cache expensive lookups through `options.appSet/userSet`.

## Resources
- Docs: <https://bitrix24.github.io/b24jssdk/>
- NPM: <https://www.npmjs.com/package/@bitrix24/b24jssdk>
- Repo: <https://github.com/bitrix24/b24jssdk>
- REST docs: <https://github.com/bitrix-tools/b24-rest-docs>
- Examples: <https://github.com/bitrix24/b24sdk-examples>

**Doc version:** 1.0 · **Updated:** 2025‑10‑23 · **SDK:** 0.4.10
