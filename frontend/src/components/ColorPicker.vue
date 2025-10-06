<script setup lang="ts">
import { computed, reactive, watch } from 'vue'

const DEFAULT_COLOR = '#18A058'

const props = withDefaults(
	defineProps<{
		modelValue?: string
		label?: string
		showAlpha?: boolean
		lockToDefault?: boolean
		expectedColor?: string
	}>(),
	{
		modelValue: DEFAULT_COLOR,
		label: 'Cor',
		showAlpha: false,
		lockToDefault: false,
	},
)

const emit = defineEmits<{
	(e: 'update:modelValue', value: string): void
	(e: 'invalid', message: string): void
}>()

const formModel = reactive({
	color: props.modelValue,
})

const expectedColor = computed(() => props.expectedColor ?? DEFAULT_COLOR)

const colorRule = computed(() => ({
	trigger: 'change',
	validator(_: unknown, value: string) {
		if (props.lockToDefault && value !== expectedColor.value) {
			const message = 'Não altere a cor definida.'
			emit('invalid', message)
			return new Error(message)
		}
		return true
	},
}))

const labelText = computed(() => `${props.label} (${expectedColor.value})`)

watch(
	() => props.modelValue,
	(value) => {
		if (value !== formModel.color) {
			formModel.color = value
		}
	},
)

watch(
	() => formModel.color,
	(value) => {
		if (value !== props.modelValue) {
			emit('update:modelValue', value)
		}
	},
)
</script>

<template>
	<n-form :model="formModel">
		<n-form-item :label="labelText" path="color" :rule="colorRule">
			<n-color-picker v-model:value="formModel.color" :show-alpha="props.showAlpha" />
		</n-form-item>
	</n-form>
</template>
