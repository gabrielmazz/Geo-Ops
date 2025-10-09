<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
	defineProps<{
		show: boolean
		title?: string
		width?: number | string
		size?: 'small' | 'medium' | 'large' | 'huge'
		bordered?: boolean
		closable?: boolean
		maskClosable?: boolean
		trapFocus?: boolean
		autoFocus?: boolean
		transformOrigin?: string
		segmented?: boolean | { content?: boolean; footer?: boolean }
	}>(),
	{
		title: '',
		width: 600,
		size: 'medium',
		bordered: false,
		closable: true,
		maskClosable: true,
		trapFocus: true,
		autoFocus: true,
		transformOrigin: 'center',
		segmented: false,
	},
)

const emit = defineEmits<{
	(e: 'update:show', value: boolean): void
	(e: 'open'): void
	(e: 'close'): void
	(e: 'after-enter'): void
	(e: 'after-leave'): void
}>()

const cardWidth = computed(() =>
	typeof props.width === 'number' ? `${props.width}px` : props.width,
)

const cardStyle = computed(() => ({
	width: cardWidth.value,
}))

const handleUpdateShow = (value: boolean) => {
	emit('update:show', value)
	if (value) {
		emit('open')
	} else {
		emit('close')
	}
}

const handleCardClose = () => {
	handleUpdateShow(false)
}

const handleAfterEnter = () => {
	emit('after-enter')
}

const handleAfterLeave = () => {
	emit('after-leave')
}
</script>

<template>
	<n-modal
		:show="props.show"
		:mask-closable="props.maskClosable"
		:trap-focus="props.trapFocus"
		:auto-focus="props.autoFocus"
		:transform-origin="props.transformOrigin"
		@update:show="handleUpdateShow"
		@after-enter="handleAfterEnter"
		@after-leave="handleAfterLeave">
		<n-card
			:title="props.title"
			:bordered="props.bordered"
			:size="props.size"
			:closable="props.closable"
			:segmented="props.segmented"
			:style="cardStyle"
			role="dialog"
			aria-modal="true"
			@close="handleCardClose">
			<template v-if="$slots.header" #header>
				<slot name="header" />
			</template>
			<template v-if="$slots.headerExtra" #header-extra>
				<slot name="headerExtra" />
			</template>

			<slot />

			<template v-if="$slots.footer" #footer>
				<slot name="footer" />
			</template>
		</n-card>
	</n-modal>
</template>
