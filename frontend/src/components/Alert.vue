<script setup lang="ts">
const props = withDefaults(
	defineProps<{
		title?: string
		message: string
		type?: 'default' | 'info' | 'success' | 'warning' | 'error'
		showIcon?: boolean
		closable?: boolean
	}>(),
	{
		type: 'default',
		showIcon: true,
		closable: false,
	},
)

const emit = defineEmits<{
	(e: 'close'): void
}>()
</script>

<template>
	<n-alert
		:title="props.title"
		:type="props.type"
		:show-icon="props.showIcon"
		:closable="props.closable"
		@close="emit('close')">
		{{ props.message }}
	</n-alert>
</template>
