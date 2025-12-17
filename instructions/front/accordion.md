# B24Accordion: expandable object list

> ⚠️ **AI-only warning**: use `B24Accordion` from Bitrix24 UI Kit, **not** Nuxt UI’s UAccordion.

## 📋 Overview
`B24Accordion` renders expandable panels for structured content:
- FAQ or knowledge bases
- Object lists with inline details
- Category grouping
- Drill-down views

---

## 🎯 Minimal example
```vue
<template>
  <B24Accordion :items="items" />
</template>

<script setup>
const items = ref([
  { label: 'Item 1', content: 'Description for item 1' },
  { label: 'Item 2', content: 'Description for item 2' }
])
</script>
```

---

## 💼 Full demo — object directory with actions
```vue
<template>
  <B24App>
    <B24Container class="py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">📚 Object Registry</h1>
        <p class="mt-2 text-gray-600 dark:text-gray-400">
          Expandable list with metadata and actions
        </p>
      </div>

      <B24Card class="mb-6">
        <div class="flex items-center justify-between">
          <div class="flex gap-2">
            <B24Button :icon="PlusIcon" color="air-primary" @click="addItem">
              Create
            </B24Button>
            <B24Button :icon="RefreshIcon" color="air-secondary-no-accent" @click="refreshItems">
              Refresh
            </B24Button>
          </div>
          <B24FormField label="" class="m-0">
            <B24Input v-model="searchQuery" :icon="SearchIcon" placeholder="Search..." class="w-64" />
          </B24FormField>
        </div>
      </B24Card>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <B24Card>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-gray-600 dark:text-gray-400">Total</p>
              <p class="text-2xl font-bold">{{ totalItems }}</p>
            </div>
            <B24Icon :icon="ChartIcon" class="w-8 h-8 text-primary" />
          </div>
        </B24Card>
        <B24Card>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-gray-600 dark:text-gray-400">Active</p>
              <p class="text-2xl font-bold text-green-600">{{ activeItems }}</p>
            </div>
            <B24Icon :icon="CheckIcon" class="w-8 h-8 text-green-500" />
          </div>
        </B24Card>
        <B24Card>
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-gray-600 dark:text-gray-400">Matched</p>
              <p class="text-2xl font-bold">{{ filteredItems.length }}</p>
            </div>
            <B24Icon :icon="SearchIcon" class="w-8 h-8 text-blue-500" />
          </div>
        </B24Card>
      </div>

      <B24Card v-if="loading" class="text-center py-8">
        <B24Icon :icon="LoadingIcon" class="w-8 h-8 animate-spin mx-auto text-primary" />
        <p class="mt-2 text-gray-600">Loading...</p>
      </B24Card>

      <B24Accordion v-else :items="accordionItems" multiple class="space-y-2">
        <template v-for="(item, index) in filteredItems" :key="item.id" #[`item-${index}`]>
          <div class="p-4 space-y-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <p class="text-sm text-gray-600 dark:text-gray-400">ID</p>
                <p class="font-semibold">#{{ item.id }}</p>
              </div>
              <div>
                <p class="text-sm text-gray-600 dark:text-gray-400">Status</p>
                <B24Badge :color="getStatusColor(item.status)">{{ item.status }}</B24Badge>
              </div>
            </div>

            <div>
              <p class="text-sm text-gray-600 dark:text-gray-400 mb-1">Description</p>
              <p class="text-gray-900 dark:text-white">{{ item.description }}</p>
            </div>

            <div class="grid grid-cols-2 gap-4 pt-4 border-t">
              <div>
                <p class="text-sm text-gray-600 dark:text-gray-400">Created</p>
                <p class="text-sm">{{ formatDate(item.createdAt) }}</p>
              </div>
              <div>
                <p class="text-sm text-gray-600 dark:text-gray-400">Updated</p>
                <p class="text-sm">{{ formatDate(item.updatedAt) }}</p>
              </div>
            </div>

            <div class="flex gap-2 pt-4 border-t">
              <B24Button :icon="EditIcon" color="air-primary" size="sm" @click="editItem(item)">Edit</B24Button>
              <B24Button :icon="TrashIcon" color="air-secondary-no-accent" size="sm" @click="deleteItem(item)">Delete</B24Button>
              <B24Button :icon="CopyIcon" color="air-tertiary" size="sm" @click="duplicateItem(item)">Duplicate</B24Button>
            </div>
          </div>
        </template>
      </B24Accordion>

      <B24Card v-if="!loading && filteredItems.length === 0" class="text-center py-8">
        <B24Icon :icon="InboxIcon" class="w-12 h-12 mx-auto text-gray-400 mb-4" />
        <h3 class="text-lg font-semibold mb-2">No records</h3>
        <p class="text-gray-600 mb-4">Create the first entry</p>
        <B24Button :icon="PlusIcon" color="air-primary" @click="addItem">Create</B24Button>
      </B24Card>
    </B24Container>
  </B24App>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useToast } from '@bitrix24/b24ui-nuxt'
import {
  PlusIcon, RefreshIcon, SearchIcon, ChartIcon, CheckIcon,
  LoadingIcon, EditIcon, TrashIcon, CopyIcon, InboxIcon
} from '@bitrix24/b24icons'

interface Item {
  id: number
  name: string
  description: string
  status: string
  createdAt: string
  updatedAt: string
}

const items = ref<Item[]>([])
const searchQuery = ref('')
const loading = ref(false)
const toast = useToast()

const loadItems = async () => {
  loading.value = true
  try {
    const response = await fetch('/api/items')
    const data = await response.json()
    items.value = data.items || []
  } catch (error) {
    console.error(error)
    toast.add({ title: 'Error', description: 'Failed to load data', color: 'red' })
  } finally {
    loading.value = false
  }
}

const filteredItems = computed(() => {
  if (!searchQuery.value) return items.value
  const query = searchQuery.value.toLowerCase()
  return items.value.filter(item =>
    item.name.toLowerCase().includes(query) ||
    item.description.toLowerCase().includes(query)
  )
})

const accordionItems = computed(() => filteredItems.value.map((item, index) => ({
  label: item.name,
  value: `item-${index}`,
  slot: `item-${index}`,
  icon: getStatusIcon(item.status)
})))

const totalItems = computed(() => items.value.length)
const activeItems = computed(() => items.value.filter(item => item.status === 'ACTIVE').length)

const formatDate = (value?: string) => value ? new Date(value).toLocaleDateString('en-US') : ''
const getStatusColor = (status: string) => ({
  ACTIVE: 'green', PENDING: 'yellow', INACTIVE: 'gray', ARCHIVED: 'red'
})[status] || 'gray'
const getStatusIcon = (status: string) => ({
  ACTIVE: CheckIcon,
  PENDING: LoadingIcon,
  INACTIVE: InboxIcon,
  ARCHIVED: TrashIcon
})[status] || InboxIcon

const refreshItems = () => loadItems()
const addItem = () => {/* implement */}
const editItem = (item: Item) => {/* implement */}
const deleteItem = async (item: Item) => {
  if (!confirm(`Delete "${item.name}"?`)) return
  try {
    await fetch(`/api/items/${item.id}`, { method: 'DELETE' })
    toast.add({ title: 'Removed', description: `${item.name} deleted`, color: 'green' })
    await loadItems()
  } catch (error) {
    toast.add({ title: 'Error', description: 'Delete failed', color: 'red' })
  }
}
const duplicateItem = (item: Item) => {/* implement */}

onMounted(loadItems)
</script>
```

---

## 🎨 Customization
- `multiple` prop allows several panels open at once.
- Provide `icon` / `trailingIcon` per item.
- Set `disabled: true` for read-only rows.
- Use slots (`#item-0`) for complex layouts.

---

## 💡 Use cases
1. **FAQ** — pass Q/A pairs to `items`.
2. **Grouped data** — set `slot` per group and render a custom list inside.

---

## 🔗 Backend integration
Fetch data from Bitrix24 REST, custom APIs, or SDK endpoints, normalize the payload, and assign to `items.value`. Always show loading states and error toasts.

---

## 📊 Props reference
```ts
interface AccordionItem {
  label?: string
  content?: string
  value?: string
  icon?: Component
  trailingIcon?: Component
  disabled?: boolean
  slot?: string
  class?: string
}
```

---

## 🎯 Best practices
**Do:**
- Use slots for anything beyond plain text.
- Add search/filter controls for large datasets.
- Render skeletons/spinners while loading.

**Avoid:**
- Deep nesting (keep to 2–3 levels max).
- Stuffing huge payloads into `content` strings — prefer slots.
- Missing `key` attributes in `v-for` loops.

---

## 📚 Resources
- UI Kit docs: <https://bitrix24.github.io/b24ui/llms-full.txt> (see `B24Accordion` around line 4020)
- Icons: <https://bitrix24.github.io/b24icons/>
- Bitrix24 REST: <https://apidocs.bitrix24.com/>

*Updated: Oct 2025 · UI Kit 2.0 · Component: `B24Accordion`*
