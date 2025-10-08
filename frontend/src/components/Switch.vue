<script setup lang="ts">
const props = withDefaults(
	defineProps<{
		modelValue?: boolean
		disabled?: boolean
		size?: 'small' | 'medium' | 'large'
		label?: string
		description?: string
		textContent?: string
	}>(),
	{
		modelValue: false,
		disabled: false,
		size: 'medium',
	},
)

const emit = defineEmits<{
	(e: 'update:modelValue', value: boolean): void
	(e: 'change', value: boolean): void
}>()

const handleUpdateValue = (value: boolean) => {
	if (props.disabled) return
	emit('update:modelValue', value)
	emit('change', value)
}
</script>

<template>
	<div class="switch">
		<div class="switch__content">
			<p v-if="props.label" class="switch__label">
				{{ props.label }}
			</p>
			<p v-if="props.description" class="switch__description">
				{{ props.description }}
			</p>
		</div>
		<div class="switch__control">
			<n-switch
				:value="props.modelValue"
				:disabled="props.disabled"
				:size="props.size"
				@update:value="handleUpdateValue"
			/>
			<span v-if="props.textContent" class="switch__state">
				{{ props.modelValue ? 'Ativado' : 'Desativado' }}
			</span>
		</div>
	</div>
</template>

<style scoped>
.switch {
	display: flex;
	align-items: flex-start;
	justify-content: space-between;
	gap: 1rem;
	width: 100%;
}

.switch__content {
	display: flex;
	flex-direction: column;
	gap: 0.25rem;
	flex: 1;
}

.switch__label {
	font-weight: 600;
	color: var(--color-text-primary);
}

.switch__description {
	font-size: 0.875rem;
	color: var(--color-text-secondary);
	line-height: 1.4;
}

.switch__control {
	display: flex;
	align-items: center;
	gap: 0.5rem;
	color: var(--color-text-tertiary);
	flex-shrink: 0;
}

.switch__state {
	font-size: 0.75rem;
	font-weight: 500;
}
</style>
