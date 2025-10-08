<script setup lang="ts">
const props = defineProps<{
	items: Array<{
		key: string
		label: string
		coordinate: { lat: number; lon: number }
		role: 'origin' | 'destination' | 'waypoint'
		badgeClasses: string
	}>
}>()

const roleTypes: Record<'origin' | 'destination' | 'waypoint', 'success' | 'error' | 'info'> = {
	origin: 'success',
	destination: 'error',
	waypoint: 'info',
}

const roleLabels: Record<'origin' | 'destination' | 'waypoint', string> = {
	origin: 'Origem',
	destination: 'Destino',
	waypoint: 'Ponto intermediário',
}

const formatCoordinate = (value: number) => value.toFixed(6)
</script>

<template>
	<n-timeline>
		<n-timeline-item
			v-for="item in props.items"
			:key="item.key"
			:title="item.label"
			:type="roleTypes[item.role]">
			<template #default>
				<div class="flex flex-col gap-1">
					<span :class="item.badgeClasses">{{ roleLabels[item.role] }}</span>
					<span class="text-xs text-tertiary">
						{{ formatCoordinate(item.coordinate.lat) }},
						{{ formatCoordinate(item.coordinate.lon) }}
					</span>
				</div>
			</template>
		</n-timeline-item>
	</n-timeline>
</template>
