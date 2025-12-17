# B24SelectMenu: filtered object picker

> ⚠️ **AI reminder**: use `B24SelectMenu` from Bitrix24 UI Kit, not Nuxt UI’s `USelectMenu`.

## 📋 Overview
`B24SelectMenu` handles searchable, multi-select pickers for contacts, companies, custom records, filters, or linking flows.

---

## 🎯 Basic snippet
```vue
<template>
  <B24SelectMenu
    v-model="selected"
    :options="options"
    multiple
    searchable
    placeholder="Choose items..."
  />
</template>

<script setup>
const options = [
  { value: 1, label: 'Record 1' },
  { value: 2, label: 'Record 2' }
]
const selected = ref<number[]>([])
</script>
```

---

## 💼 Full selector with filters
```vue
<template>
  <B24Container class="py-8">
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <B24Card>
        <template #header>
          <h3 class="text-lg font-semibold">Filters</h3>
        </template>
        <div class="space-y-4 p-4">
          <B24FormField label="Search">
            <B24Input v-model="filters.search" :icon="SearchIcon" @update:model-value="applyFilters" />
          </B24FormField>
          <B24FormField label="Category">
            <B24Select v-model="filters.category" :options="categoryOptions" @update:model-value="applyFilters" />
          </B24FormField>
          <div class="flex gap-2">
            <B24Button block color="air-primary" @click="applyFilters">Apply</B24Button>
            <B24Button block color="air-secondary-no-accent" @click="resetFilters">Reset</B24Button>
          </div>
        </div>
      </B24Card>

      <div class="lg:col-span-2 space-y-6">
        <B24Card>
          <template #header>
            <h3 class="text-lg font-semibold">Select items ({{ items.length }} available)</h3>
          </template>
          <div class="p-4">
            <B24SelectMenu
              v-model="selected"
              :options="options"
              :loading="loading"
              multiple
              searchable
              placeholder="Pick recipients"
            />
          </div>
        </B24Card>

        <B24Card v-if="selected.length">
          <template #header>
            <div class="flex justify-between">
              <h3 class="text-lg font-semibold">Selected: {{ selected.length }}</h3>
              <B24Button size="sm" color="air-tertiary" @click="selected = []">Clear</B24Button>
            </div>
          </template>
          <div class="p-4">
            <div class="flex gap-2">
              <B24Select v-model="bulkAction" :options="actionOptions" placeholder="Choose action" class="flex-1" />
              <B24Button color="air-primary" @click="performBulkAction">Run</B24Button>
            </div>
          </div>
        </B24Card>
      </div>
    </div>
  </B24Container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { SearchIcon } from '@bitrix24/b24icons'

const items = ref<Array<{ id: number; name: string }>>([])
const selected = ref<number[]>([])
const loading = ref(false)
const bulkAction = ref('')
const filters = ref({ search: '', category: '' })

const categoryOptions = [
  { value: 'all', label: 'All' },
  { value: 'vip', label: 'VIP' },
  { value: 'archive', label: 'Archived' },
]
const actionOptions = [
  { value: 'assign', label: 'Assign' },
  { value: 'email', label: 'Send email' },
  { value: 'delete', label: 'Delete' },
]

const options = computed(() => items.value.map(item => ({ value: item.id, label: item.name })))

const loadItems = async () => {
  loading.value = true
  try {
    const response = await fetch('/api/items')
    items.value = await response.json()
  } finally {
    loading.value = false
  }
}

const applyFilters = () => loadItems()
const resetFilters = () => { filters.value = { search: '', category: '' }; loadItems() }
const performBulkAction = () => console.log('Bulk action', bulkAction.value, selected.value)

onMounted(loadItems)
</script>
```

---

## 📚 Resources
- UI Kit doc: <https://bitrix24.github.io/b24ui/llms-full.txt> (see `B24SelectMenu` near line 29676)
- REST API reference: <https://apidocs.bitrix24.com/>

*Updated Oct 2025 · UI Kit 2.0 · Component: `B24SelectMenu`*
