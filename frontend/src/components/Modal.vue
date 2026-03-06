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
			class="app-modal-card"
			:bordered="props.bordered"
			:size="props.size"
			:segmented="props.segmented"
			:style="cardStyle"
			role="dialog"
			aria-modal="true">


			<slot />

			<template v-if="$slots.footer" #footer>
				<slot name="footer" />
			</template>
		</n-card>
	</n-modal>
</template>

<style scoped>
:deep(.app-modal-card.n-card) {
	border-radius: 12px !important;
	overflow: hidden;
	box-shadow: 0 18px 36px rgba(15, 23, 42, 0.16);
}

:deep(.app-modal-card .n-card__content) {
	position: relative;
}

.app-overlay-close {
	position: absolute;
	top: 1rem;
	right: 1rem;
	z-index: 1;
	border: 0;
	background: transparent;
	color: rgba(71, 85, 105, 0.9);
	font-size: 1.35rem;
	line-height: 1;
	cursor: pointer;
	padding: 0;
}
</style>
