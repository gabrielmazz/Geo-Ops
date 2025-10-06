<script setup lang="ts">
const props = withDefaults(
	defineProps<{
		label?: string
	}>(),
	{ label: 'Abrir ações' },
)

const emit = defineEmits<{
	(e: 'click'): void
}>()
</script>

<template>
	<n-button @click="emit('click')">
		<slot>{{ props.label }}</slot>
	</n-button>
</template>
