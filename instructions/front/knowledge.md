# Bitrix24 UI Kit — guide for AI agents

## Quick overview
**Bitrix24 UI Kit** (`@bitrix24/b24ui-nuxt`) is Nuxt + Vue UI middleware for REST-based Bitrix24 apps. The starter already wires Nuxt, Tailwind, Pinia, i18n, and the UI kit together; every new screen must keep that structure and reuse the provided components.

Project layout:
```
frontend/
├── app/
│   ├── app.config.ts          # B24UI config
│   ├── app.vue                # root shell with B24App
│   ├── assets/css/main.css    # Tailwind + kit styles
│   ├── components/            # local widgets (Logo, BackendStatus, ...)
│   ├── composables/           # shared logic
│   ├── pages/                 # *.client.vue pages (index, install, handler, slider)
│   └── stores/                # Pinia stores
├── nuxt.config.ts
├── package.json
└── i18n/
    ├── locales/
    └── i18n.map.ts
```

Highlights:
- Fork of Nuxt UI aligned with Bitrix24 design tokens.
- Tailwind CSS 4 + Tailwind Variants; 80+ components and composables.
- Works with Nuxt 4 / Vue 3 / Vite; bundles 1400+ icons via `@bitrix24/b24icons-vue`.
- **Always** consume components from `@bitrix24/b24ui-nuxt`, not plain Nuxt UI.

## Frontend setup recap
`nuxt.config.ts`:
```ts
export default defineNuxtConfig({
  modules: ['@bitrix24/b24ui-nuxt']
})
```
`assets/css/main.css`:
```css
@import 'tailwindcss';
@import '@bitrix24/b24ui-nuxt';
```
`app.vue`:
```vue
<template>
  <B24App :locale="locales[locale]">
    <NuxtLoadingIndicator color="var(--ui-color-design-filled-warning-bg)" :height="3" />
    <B24DashboardGroup>
      <NuxtLayout>
        <NuxtPage />
      </NuxtLayout>
    </B24DashboardGroup>
  </B24App>
</template>
```

## Baseline rules
1. **Wrap everything in `<B24App>`** so global providers (toast, tooltip, overlay) work.
2. **All components are `B24*`** (`B24Button`, `B24Input`, `B24Form`, `B24Modal`, ...).
3. **Icons** import from `@bitrix24/b24icons-vue/category/IconName`.
4. **Pages** live under `pages/` and end with `.client.vue` (renders only in the Bitrix24 iframe). Choose a layout (`default`, `placement`, `slider`, `uf-placement`) that matches the scenario.
5. **Styling** — use the `b24ui` prop for slot-level tweaks and `class` for wrapping element overrides; avoid global CSS hacks.
6. **Theme variants** — use predefined `color`/`size` tokens such as `air-primary`, `air-primary-success`, `md`, `lg`, etc.

## Component blueprints
For common flows prefer the dedicated docs (`accordion.md`, `calendar.md`, `form.md`, `selector.md`, `settings-page.md`, `table-and-grid.md`). Otherwise, rely on these building blocks:

### Actions
- `B24Button` — primary CTA ([code](https://github.com/bitrix24/b24ui/blob/main/src/runtime/components/Button.vue), [theme](https://github.com/bitrix24/b24ui/blob/main/src/theme/button.ts)).
- `B24FieldGroup` — grouped buttons.

### Forms
- `B24Input`, `B24Textarea`, `B24Select`, `B24Checkbox`, `B24RadioGroup`, `B24Switch` — typed controls.
- `B24Form` + `B24FormField` — schema-based validation (Zod/Valibot/Yup) with built-in layouts.

### Overlays & notifications
- `B24Modal`, `B24Slideover`, `B24Toast` (`useToast()`), `B24Tooltip`, `B24Popover`.

### Navigation
- `B24NavigationMenu`, `B24DropdownMenu`, `B24Tabs`, `B24Breadcrumb`.

### Layouts
- `B24SidebarLayout` (already used inside `layouts/default.vue` — don’t nest it again inside pages), plus `B24Sidebar*` helpers and `B24Navbar`.

### Data display
- `B24Avatar`, `B24AvatarGroup`, `B24Badge`, `B24Chip`, `B24Card`, `B24Alert`, `B24Advice`, `B24Table`/`B24TableWrapper`, `B24DescriptionList`, `B24Skeleton`, `B24Empty`.

### Misc components
- `B24Progress`, `B24Range`, `B24Calendar`, `B24Countdown`, `B24Accordion`/`B24Collapsible`, `B24Separator`, `B24Kbd`.

## Core composables
- `useToast()` — queued notifications (`add`, `update`, `remove`, `clear`).
- `useOverlay()` — programmatic modals/slideover with `create`, `open`, `close`, `patch`.
- `defineShortcuts()` — register global hotkeys.
- `useLocale()` / `defineLocale()` — i18n wiring.
- `useConfetti()` — celebratory animation.
- `useFormField()` — integrate custom inputs with `B24Form`.

## Troubleshooting checklist
1. Verify installation: module in `nuxt.config.ts`, CSS imports, `<B24App>` wrapper.
2. Inspect component source (`src/runtime/components`) and `theme` definitions for props/variants.
3. Confirm dependency versions (`@bitrix24/b24ui-nuxt` ≥ 2.0, `nuxt` ≥ 4).
4. Typical fixes:
   - Components missing → wrap with `<B24App>`.
   - Toast/Tooltip/Modal broken → `<B24App>` absent.
   - Icons missing → wrong import path.
   - Styles missing → CSS not imported.
   - TS errors → check component props in the source.

Useful links: [module source](https://github.com/bitrix24/b24ui/blob/main/src/module.ts), [components](https://github.com/bitrix24/b24ui/tree/main/src/runtime/components), [composables](https://github.com/bitrix24/b24ui/tree/main/src/runtime/composables), [themes](https://github.com/bitrix24/b24ui/tree/main/src/theme), [demo playground](https://github.com/bitrix24/b24ui/tree/main/playgrounds/demo/app).

## State management
Pinia drives shared state. Example (`useDealsStore`): keep refs for lists, filters, computed getters, async actions, and expose readonly state. For reusable data fetching logic leverage composables like `useApi()` that centralize loading/error state.

## Tailwind CSS 4 integration
Nuxt uses the Vite plugin version:
```ts
// nuxt.config.ts
import tailwindcss from '@tailwindcss/vite'
export default defineNuxtConfig({
  vite: { plugins: [tailwindcss()] }
})
```
`assets/css/main.css`:
```css
@import 'tailwindcss';
@import '@bitrix24/b24ui-nuxt';

@theme static {
  /* custom utilities */
}
```
Extend tokens via `@theme { ... }` blocks.

## Responsive patterns
Use Tailwind breakpoints (`md`, `lg`, `xl`) for grid layouts, and `B24Slideover` for mobile navigation. Example snippets show responsive grids, mobile nav toggles, and data tables with filters.

## Performance tips
- Lazy-load heavy components via `defineAsyncComponent`.
- Use list patterns from `B24Table` / `B24Card` combos.
- Memoize derived data (computed), debounce inputs, and prefer batch API calls.

## Utilities
Create shared formatters (currency, date, relative time, truncation) under `utils/formatters.ts` and import where needed.

## Best practices
1. Stick to B24 components, separate smart/dumb components, and document props/emits.
2. Manage state with Pinia + composables; avoid deep prop drilling (use provide/inject).
3. Prioritize performance (lazy loading, virtualization, memoization, debouncing).
4. Accessibility comes built-in, but preserve semantics and default color tokens.

## Resources
- Docs: <https://bitrix24.github.io/b24ui/>
- Icons: <https://bitrix24.github.io/b24icons/>
- Repository: <https://github.com/bitrix24/b24ui>
- Demo: <https://bitrix24.github.io/b24ui/demo/>
- Starter template: <https://github.com/bitrix24/starter-b24ui>
- Extended AI README: <https://github.com/bitrix24/b24ui/blob/main/README-AI.md>

> Version 2.1.0 — updated November 2025 — MIT license.
