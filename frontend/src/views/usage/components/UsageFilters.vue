<script setup lang="ts">
import type { UsageRecordFilterField } from '../composables/useUsageRecordsTable'
import { ZIconButton, ZInput, ZSelect } from '@codex-proxy/ui'

import { RefreshCw, Search } from '@lucide/vue'

defineProps<{
  refreshing: boolean
  loading: boolean
}>()

const emit = defineEmits<{
  refresh: []
}>()

const field = defineModel<UsageRecordFilterField>('field', { required: true })
const value = defineModel<string>('value', { required: true })
const fieldOptions = [
  { value: 'key', label: '密钥名称' },
  { value: 'account', label: '账号' },
  { value: 'model', label: '模型' },
]
</script>

<template>
  <div class="flex w-full flex-wrap items-center gap-3" role="group" aria-label="使用记录筛选与操作">
    <div class="grid w-full min-w-0 grid-cols-[8rem_minmax(0,1fr)] gap-2 sm:w-md sm:flex-none">
      <ZSelect v-model="field" :options="fieldOptions" aria-label="请求明细筛选字段" />
      <ZInput
        v-model="value"
        placeholder="输入筛选内容"
        aria-label="请求明细筛选内容"
        class="w-full"
      >
        <template #prefix>
          <Search class="size-4.5 text-cp-text-tertiary" />
        </template>
      </ZInput>
    </div>

    <div class="ml-auto flex shrink-0 items-center justify-end gap-2">
      <slot name="actions" />
      <ZIconButton
        size="default"
        aria-label="刷新使用记录"
        :loading="refreshing"
        :disabled="loading || refreshing"
        @click="emit('refresh')"
      >
        <template #loading>
          <RefreshCw class="size-4.5 animate-spin motion-reduce:animate-none" />
        </template>
        <RefreshCw class="size-4.5" />
      </ZIconButton>
    </div>
  </div>
</template>
