<script setup lang="ts">
const props = withDefaults(
	defineProps<{
		label?: string
		buttonType?: 'text' | 'ghost'
		color?: string
	}>(),
	{ label: 'Abrir ações' },
)

const emit = defineEmits<{
	(e: 'click'): void
}>()
</script>

	<template>
		<n-button
			class="app-button"
			@click="emit('click')"
			:text="props.buttonType === 'text'"
			:ghost="props.buttonType === 'ghost'"
			:color="props.color">
			<slot>{{ props.label }}</slot>
		</n-button>
	</template>

<style scoped>
:deep(.app-button.n-button) {
	border-radius: 8px !important;
}
</style>
