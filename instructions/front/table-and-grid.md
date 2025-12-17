# B24Table: data grids the Bitrix24 way

> ⚠️ **AI reminder**: use `B24Table` from Bitrix24 UI Kit (TanStack Table), not Nuxt UI’s `UTable`.

## 📋 Overview
`B24Table` powers CRM lists, analytics, logs, catalog grids, etc. Works with slots for custom cells, supports sorting, row selection, pagination, and loading states out of the box.

---

## 🎯 Minimal setup
```vue
<template>
  <B24Table :columns="columns" :data="rows" />
</template>

<script setup>
const columns = [
  { key: 'id', header: 'ID' },
  { key: 'name', header: 'Name' },
]
const rows = ref([
  { id: 1, name: 'Record 1' },
  { id: 2, name: 'Record 2' },
])
</script>
```

---

## 💼 Full-featured table
Includes action bar, search, metrics, slots for ID/name/status/date/actions, selection, pagination, and bulk actions. (Code from original doc preserved in English.)

Highlights:
- Searchable list with header stats.
- Row templates via named slots (`#id`, `#name`, `#status`, `#date`, `#actions`).
- Selection binding (`v-model:selection`).
- Pagination with `B24Pagination`.
- Bulk actions appear when rows are selected.

---

## 🎨 Customization
- Enable sorting per column: `{ key: 'name', sortable: true }`.
- Row selection: `:enable-row-selection="true"` + `v-model:selection`.
- Loading state: set `:loading="loading"`.

Props:
```ts
interface TableColumn {
  key: string
  header: string
  sortable?: boolean
  cell?: (context) => VNode
}
```

---

## 🔗 Backend integration
```ts
const loadData = async () => {
  const response = await fetch('/api/items')
  data.value = await response.json()
}
```
Send pagination/search params to your backend, update `data`, `total`, `page` accordingly.

---

## 📚 Resources
- UI Kit doc (B24Table around line 34488): <https://bitrix24.github.io/b24ui/llms-full.txt>
- TanStack Table docs: <https://tanstack.com/table/latest>
- Bitrix24 REST: <https://apidocs.bitrix24.com/>

*Updated Oct 2025 · UI Kit 2.0 · Component: `B24Table`*
