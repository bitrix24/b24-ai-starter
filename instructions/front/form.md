# B24Form: object editor

> ⚠️ **AI-only warning**: use `B24Form` + `B24FormField` from Bitrix24 UI Kit, not Nuxt UI’s UForm.* components.

## 📋 Overview
`B24Form` wraps form state + validation for record creation, update flows, settings, or multi-step wizards.

---

## 🎯 Minimal example
```vue
<template>
  <B24Form :state="state" @submit="onSubmit">
    <B24FormField label="Title" name="title">
      <B24Input v-model="state.title" />
    </B24FormField>

    <B24Button type="submit" color="air-primary">
      Save
    </B24Button>
  </B24Form>
</template>

<script setup>
const state = reactive({ title: '' })
const onSubmit = async data => console.log('Submitted', data)
</script>
```

---

## 💼 Full object card
```vue
<template>
  <B24App>
    <B24Container class="py-8">
      <div v-if="loading" class="flex items-center justify-center min-h-screen">
        <B24Icon :icon="LoadingIcon" class="w-8 h-8 animate-spin" />
      </div>

      <div v-else class="space-y-6">
        <B24Card>
          <div class="flex items-start justify-between gap-4 p-4">
            <div class="flex-1">
              <B24Input
                v-model="form.title"
                size="xl"
                placeholder="Object name"
                class="text-2xl font-bold"
              />
              <div class="flex items-center gap-4 mt-3 text-sm text-gray-600">
                <B24Icon :icon="CalendarIcon" />
                <span>Created: {{ formatDate(item.createdAt) }}</span>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <B24Button :icon="CheckIcon" color="air-primary" :loading="saving" @click="saveItem">
                Save
              </B24Button>
              <B24Button :icon="CloseIcon" color="air-secondary-no-accent" :disabled="saving" @click="cancelEdit">
                Cancel
              </B24Button>
            </div>
          </div>
        </B24Card>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-2 space-y-6">
            <B24Card>
              <template #header>
                <h3 class="text-lg font-semibold">Main info</h3>
              </template>
              <div class="space-y-4 p-4">
                <B24FormField label="Status" required>
                  <B24Select v-model="form.status" :options="statusOptions" placeholder="Select status" />
                </B24FormField>

                <B24FormField label="Amount">
                  <div class="flex gap-2">
                    <B24Input v-model="form.amount" type="number" placeholder="0" class="flex-1" />
                    <B24Select v-model="form.currency" :options="currencyOptions" class="w-32" />
                  </div>
                </B24FormField>

                <div class="grid grid-cols-2 gap-4">
                  <B24FormField label="Start date">
                    <B24Input v-model="form.startDate" type="date" />
                  </B24FormField>
                  <B24FormField label="End date">
                    <B24Input v-model="form.endDate" type="date" />
                  </B24FormField>
                </div>
              </div>
            </B24Card>

            <B24Card>
              <template #header>
                <h3 class="text-lg font-semibold">Additional</h3>
              </template>
              <div class="p-4">
                <B24FormField label="Description">
                  <B24Textarea v-model="form.description" :rows="4" placeholder="Add details..." />
                </B24FormField>
              </div>
            </B24Card>
          </div>

          <div class="space-y-6">
            <B24Card>
              <template #header>
                <h3 class="text-lg font-semibold">Info</h3>
              </template>
              <div class="space-y-3 text-sm p-4">
                <div class="flex justify-between">
                  <span class="text-gray-600">ID:</span>
                  <span class="font-semibold">#{{ item.id }}</span>
                </div>
              </div>
            </B24Card>

            <B24Card>
              <template #header>
                <h3 class="text-lg font-semibold">Actions</h3>
              </template>
              <div class="space-y-2 p-4">
                <B24Button block color="air-secondary-no-accent" :icon="CopyIcon" @click="duplicate">
                  Duplicate
                </B24Button>
                <B24Button block color="air-secondary-no-accent" :icon="TrashIcon" @click="deleteItem">
                  Delete
                </B24Button>
              </div>
            </B24Card>
          </div>
        </div>
      </div>
    </B24Container>
  </B24App>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useToast } from '@bitrix24/b24ui-nuxt'
import { LoadingIcon, CalendarIcon, CheckIcon, CloseIcon, CopyIcon, TrashIcon } from '@bitrix24/b24icons'

const toast = useToast()
const item = ref({ id: 1, createdAt: new Date().toISOString() })
const form = reactive({ title: '', status: '', amount: 0, currency: 'RUB', startDate: '', endDate: '', description: '' })
const loading = ref(false)
const saving = ref(false)

const statusOptions = [
  { value: 'NEW', label: 'New' },
  { value: 'IN_PROGRESS', label: 'In progress' },
  { value: 'COMPLETED', label: 'Done' }
]
const currencyOptions = [
  { value: 'RUB', label: '₽ RUB' },
  { value: 'USD', label: '$ USD' },
  { value: 'EUR', label: '€ EUR' }
]

const saveItem = async () => {
  saving.value = true
  try {
    await fetch(`/api/items/${item.value.id}`, { method: 'PUT', body: JSON.stringify(form) })
    toast.add({ title: 'Saved', color: 'green' })
  } finally {
    saving.value = false
  }
}
const cancelEdit = () => {/* reload original */}
const duplicate = () => console.log('Duplicate')
const deleteItem = () => console.log('Delete')
const formatDate = (value: string) => new Date(value).toLocaleString('en-US')
</script>
```

---

## 🎨 Nuxt UI vs Bitrix24 UI
Always use `B24FormField` instead of Nuxt UI’s `UFormGroup`:
```vue
<B24FormField label="Email">
  <B24Input />
</B24FormField>
```

---

## 📚 Resources
- Full UI Kit doc: <https://bitrix24.github.io/b24ui/llms-full.txt> (see `B24Form` around line 17044, `B24FormField` around 17902)
- REST API reference: <https://apidocs.bitrix24.com/>

*Updated Oct 2025 · UI Kit 2.0 · Components: `B24Form`, `B24FormField`*
