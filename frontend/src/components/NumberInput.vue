<script setup lang="ts">
import { computed, ref, useSlots, watch } from 'vue'

const props = withDefaults(
	defineProps<{
		modelValue?: number | null
		min?: number
		max?: number
		step?: number
		precision?: number
		size?: 'small' | 'medium' | 'large'
		disabled?: boolean
		readonly?: boolean
		clearable?: boolean
		label?: string
		description?: string
		placeholder?: string
		status?: 'success' | 'warning' | 'error'
		buttonPlacement?: 'both' | 'right'
		showButton?: boolean
		feedback?: string
		format?: (value: number | null) => string
		parse?: (value: string) => number | null
		inputProps?: Record<string, unknown>
	}>(),
	{
		modelValue: null,
		step: 1,
		size: 'medium',
		disabled: false,
		readonly: false,
		clearable: false,
		placeholder: '',
		buttonPlacement: 'both',
		showButton: true,
	},
)

const emit = defineEmits<{
	(e: 'update:modelValue', value: number | null): void
	(e: 'change', value: number | null): void
	(e: 'focus', event: FocusEvent): void
	(e: 'blur', event: FocusEvent): void
	(e: 'clear'): void
}>()

const slots = useSlots()

const normalizeValue = (value: number | null | undefined) =>
	value === undefined ? null : value

const valuesAreEqual = (a: number | null, b: number | null) => {
	if (a === b) return true
	if (a === null || b === null) return false
	return Number.isNaN(a) && Number.isNaN(b)
}

const valueRef = ref<number | null>(normalizeValue(props.modelValue))

watch(
	() => props.modelValue,
	(value) => {
		const normalized = normalizeValue(value)
		if (!valuesAreEqual(normalized, valueRef.value)) {
			valueRef.value = normalized
		}
	},
)

const showHeader = computed(
	() =>
		Boolean(
			props.label ||
				props.description ||
				slots.label ||
				slots.description ||
				slots.extra,
		),
)

const showFeedback = computed(() => Boolean(props.feedback || slots.feedback))

const containerClasses = computed(() => ({
	'number-input': true,
	'number-input--disabled': props.disabled,
	[`number-input--${props.status}`]: Boolean(props.status),
}))

const feedbackClasses = computed(() => ({
	'number-input__feedback': true,
	[`number-input__feedback--${props.status}`]: Boolean(props.status),
}))

const handleUpdateValue = (value: number | null) => {
	const normalized = normalizeValue(value)
	if (!valuesAreEqual(normalized, valueRef.value)) {
		valueRef.value = normalized
	}
	emit('update:modelValue', normalized)
	emit('change', normalized)
}

const handleFocus = (event: FocusEvent) => {
	emit('focus', event)
}

const handleBlur = (event: FocusEvent) => {
	emit('blur', event)
}

const handleClear = () => {
	emit('clear')
	if (!valuesAreEqual(null, valueRef.value)) {
		valueRef.value = null
		emit('update:modelValue', null)
		emit('change', null)
	}
}
</script>

<template>
	<div :class="containerClasses">
		<div v-if="showHeader" class="number-input__header">
			<div class="number-input__titles">
				<label v-if="props.label || $slots.label" class="number-input__label">
					<slot name="label">
						{{ props.label }}
					</slot>
				</label>
				<p
					v-if="props.description || $slots.description"
					class="number-input__description">
					<slot name="description">
						{{ props.description }}
					</slot>
				</p>
			</div>
			<div v-if="$slots.extra" class="number-input__extra">
				<slot name="extra" />
			</div>
		</div>

		<n-input-number
			:value="valueRef"
			:min="props.min"
			:max="props.max"
			:step="props.step"
			:precision="props.precision"
			:size="props.size"
			:disabled="props.disabled"
			:readonly="props.readonly"
			:clearable="props.clearable"
			:placeholder="props.placeholder"
			:status="props.status"
			:button-placement="props.buttonPlacement"
			:show-button="props.showButton"
			:format="props.format"
			:parse="props.parse"
			v-bind="props.inputProps"
			@update:value="handleUpdateValue"
			@focus="handleFocus"
			@blur="handleBlur"
			@clear="handleClear">
			<template v-if="$slots.prefix" #prefix>
				<slot name="prefix" />
			</template>
			<template v-if="$slots.suffix" #suffix>
				<slot name="suffix" />
			</template>
		</n-input-number>

		<p v-if="showFeedback" :class="feedbackClasses">
			<slot name="feedback">
				{{ props.feedback }}
			</slot>
		</p>

		<div v-if="$slots.footer" class="number-input__footer">
			<slot name="footer" />
		</div>
	</div>
</template>

<style scoped>
.number-input {
	display: flex;
	flex-direction: column;
	gap: 0.5rem;
	width: 100%;
}

.number-input__header {
	display: flex;
	align-items: flex-start;
	justify-content: space-between;
	gap: 0.75rem;
}

.number-input__titles {
	display: flex;
	flex-direction: column;
	gap: 0.25rem;
	flex: 1;
}

.number-input__label {
	font-weight: 600;
	color: var(--color-text-primary);
}

.number-input__description {
	font-size: 0.875rem;
	color: var(--color-text-secondary);
	line-height: 1.4;
}

.number-input__extra {
	font-size: 0.75rem;
	color: var(--color-text-tertiary);
}

.number-input__feedback {
	font-size: 0.75rem;
	color: var(--color-text-tertiary);
}

.number-input__feedback--success {
	color: var(--color-success-600, #18a058);
}

.number-input__feedback--warning {
	color: var(--color-warning-600, #f0a020);
}

.number-input__feedback--error {
	color: var(--color-danger-600, #d03050);
}

.number-input__footer {
	font-size: 0.75rem;
	color: var(--color-text-tertiary);
}

.number-input--disabled {
	opacity: 0.7;
}
</style>
