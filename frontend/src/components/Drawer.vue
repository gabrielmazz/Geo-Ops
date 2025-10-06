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
		width: 502,
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
		<n-drawer-content :title="props.title" :closable="props.closable">
			<template v-if="$slots.header" #header>
				<slot name="header" />
			</template>
			<slot />
			<template v-if="$slots.footer" #footer>
				<slot name="footer" />
			</template>
		</n-drawer-content>
	</n-drawer>
</template>
