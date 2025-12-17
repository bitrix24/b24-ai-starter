# Settings page with sidebar

> ⚠️ **AI reminder**: use `B24*` components from Bitrix24 UI Kit—no Nuxt UI `U*` widgets here.

## 📋 Overview
Classic Bitrix24-style settings layout with a navigation sidebar and dynamic content area, ideal for app settings, multi-step wizards, module toggles, and system configuration.

---

## 🎯 Minimal skeleton
```vue
<template>
  <div class="flex min-h-screen bg-gray-50">
    <aside class="w-64 bg-white border-r">
      <nav class="p-4">
        <div
          v-for="item in menuItems"
          :key="item.id"
          @click="currentSection = item.id"
          class="p-2 cursor-pointer rounded"
          :class="currentSection === item.id ? 'bg-blue-500 text-white' : 'text-gray-700'"
        >
          {{ item.label }}
        </div>
      </nav>
    </aside>

    <main class="flex-1 p-8">
      <h1 class="text-3xl font-bold mb-4">{{ currentTitle }}</h1>
      <p>Section content...</p>
    </main>
  </div>
</template>

<script setup>
const menuItems = ref([
  { id: 'settings1', label: 'Settings 1' },
  { id: 'settings2', label: 'Settings 2' },
  { id: 'settings3', label: 'Settings 3' },
])
const currentSection = ref('settings1')
const currentTitle = computed(() => menuItems.value.find(i => i.id === currentSection.value)?.label ?? '')
</script>
```

---

## 💼 Full Bitrix24 settings experience
Includes B24 sidebar, search, lazy-loaded section components, URL sync, and toast notifications. (Full code preserved from original doc.)

Sections (`Settings1Section.vue`, `Settings2Section.vue`, `Settings3Section.vue`) implement toggles, forms, and tables using Bitrix24 components (`B24Card`, `B24FormField`, `B24Textarea`, `B24Table`, etc.).

---

## 🎨 Styling tips
- Active menu items: apply `bg-blue-500 text-white font-semibold`.
- Toggle switches: use custom Tailwind-based markup to match Bitrix24 toggles.

---

## 💡 Use cases
- Persist current section in `localStorage` or query params.
- Integrate with Vue Router (update query `section` + watch route changes).
- Show breadcrumbs using `B24Icon` + titles.

---

## 📊 Types
```ts
interface MenuItem {
  id: string
  label: string
  component: string
  title: string
  description: string
  icon?: Component
}

interface SectionProps {
  sectionData: MenuItem
}
```

---

## 🔗 Backend integration
```ts
const loadSettings = sectionId => fetch(`/api/settings/${sectionId}`).then(res => res.json())
const saveSettings = (sectionId, data) => fetch(`/api/settings/${sectionId}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
})
```

---

## 🎯 Best practices
✅ Lazy-load section components (`defineAsyncComponent`).
✅ Reflect current section in the URL (`?section=settings1`).
✅ Show loading indicators when switching sections.

❌ Don’t load all sections eagerly.
❌ Don’t forget error handling and grouping when menus are long.

---

## 📚 Resources
- UI Kit reference: <https://bitrix24.github.io/b24ui/llms-full.txt>
- Toggle inspiration: <https://flowbite.com/docs/forms/toggle/>
- REST API: <https://apidocs.bitrix24.com/>

*Updated Oct 2025 · UI Kit 2.0 · Components: `B24App`, `B24Card`, `B24Input`, `B24Button`, `B24FormField`, etc.*
