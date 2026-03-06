<script setup lang="ts">
const props = withDefaults(
	defineProps<{
		show: boolean
		title?: string
		width?: number | string
		placement?: 'top' | 'right' | 'bottom' | 'left'
		closable?: boolean
		maskClosable?: boolean
		nativeScrollbar?: boolean
	}>(),
	{
		title: '',
		width: 600,
		placement: 'right',
		closable: true,
		maskClosable: true,
		nativeScrollbar: true,
	},
)

const emit = defineEmits<{
	(e: 'update:show', value: boolean): void
}>()

const handleUpdateShow = (value: boolean) => {
	emit('update:show', value)
}
</script>

<template>
	<n-drawer
		:show="props.show"
		:width="props.width"
		:placement="props.placement"
		:mask-closable="props.maskClosable"
		:native-scrollbar="props.nativeScrollbar"
		@update:show="handleUpdateShow">
		<n-drawer-content class="app-drawer-content">
			<button
				v-if="props.closable"
				type="button"
				class="app-overlay-close"
				aria-label="Fechar painel"
				@click="handleUpdateShow(false)">
				x
			</button>
			<slot />
			<template v-if="$slots.footer" #footer>
				<slot name="footer" />
			</template>
		</n-drawer-content>
	</n-drawer>
</template>

<style scoped>
:deep(.app-drawer-content.n-drawer-content) {
	border-radius: 0 !important;
	box-shadow: none;
}

:deep(.app-drawer-content .n-drawer-body) {
	display: flex;
	flex: 1 1 auto;
	min-height: 0;
}

:deep(.app-drawer-content .n-drawer-body-content-wrapper) {
	position: relative;
	display: flex;
	flex: 1 1 auto;
	min-height: 0;
}

.app-overlay-close {
	position: absolute;
	top: 1rem;
	right: 1rem;
	z-index: 2;
	border: 0;
	background: transparent;
	color: rgba(71, 85, 105, 0.9);
	font-size: 1.35rem;
	line-height: 1;
	cursor: pointer;
	padding: 0;
}
</style>
