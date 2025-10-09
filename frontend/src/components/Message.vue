<script setup lang="ts">
import { defineComponent, ref, watch, type PropType } from 'vue'
import { useMessage } from 'naive-ui'
import type { MessageApiInjection, MessagePlacement } from 'naive-ui'

const props = withDefaults(
	defineProps<{
		placement?: MessagePlacement
		duration?: number
		closable?: boolean
		keepAliveOnHover?: boolean
		max?: number
	}>(),
	{
		placement: 'top-right',
		duration: 3000,
		closable: false,
		keepAliveOnHover: true,
		max: 5,
	},
)

const emit = defineEmits<{
	(e: 'update:placement', value: MessagePlacement): void
	(e: 'placement-change', value: MessagePlacement): void
	(e: 'ready', value: MessageApiInjection): void
}>()

const placementRef = ref<MessagePlacement>(props.placement)
const messageApiRef = ref<MessageApiInjection | null>(null)

watch(
	() => props.placement,
	(value) => {
		if (!value || value === placementRef.value) return
		placementRef.value = value
	},
)

const changePlacement = (value: MessagePlacement) => {
	if (value === placementRef.value) return
	placementRef.value = value
	emit('update:placement', value)
	emit('placement-change', value)
}

const handleRegisterMessage = (api: MessageApiInjection) => {
	if (messageApiRef.value === api) return
	messageApiRef.value = api
	emit('ready', api)
}

const MessageBridge = defineComponent({
	name: 'MessageBridge',
	props: {
		onRegister: {
			type: Function as PropType<(api: MessageApiInjection) => void>,
			required: true,
		},
	},
	setup(props, { slots }) {
		const message = useMessage()
		props.onRegister(message)
		return () =>
			slots.default
				? slots.default({
						message,
					} satisfies { message: MessageApiInjection })
				: null
	},
})
</script>

<template>
	<n-message-provider
		:placement="placementRef"
		:duration="props.duration"
		:closable="props.closable"
		:keep-alive-on-hover="props.keepAliveOnHover"
		:max="props.max">
		<MessageBridge :on-register="handleRegisterMessage" v-slot="{ message }">
			<slot
				:message="message"
				:placement="placementRef"
				:change-placement="changePlacement" />
		</MessageBridge>
	</n-message-provider>
</template>
