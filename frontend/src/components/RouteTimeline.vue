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
	<n-timeline class="route-timeline">
		<n-timeline-item
			v-for="item in props.items"
			:key="item.key"
			:title="item.label"
			:type="roleTypes[item.role]">
			<template #default>
				<div class="route-timeline__body">
					<span :class="['route-timeline__badge', item.badgeClasses]">
						{{ roleLabels[item.role] }}
					</span>
					<span class="route-timeline__coords">
						{{ formatCoordinate(item.coordinate.lat) }},
						{{ formatCoordinate(item.coordinate.lon) }}
					</span>
				</div>
			</template>
		</n-timeline-item>
	</n-timeline>
</template>

<style scoped>
.route-timeline {
	width: 100%;
}

.route-timeline__body {
	display: grid;
	gap: 0.4rem;
	width: 100%;
}

.route-timeline__badge {
	display: flex;
	width: 100%;
	justify-content: flex-start;
}

.route-timeline__coords {
	font-size: 0.75rem;
	color: var(--color-text-tertiary);
}

:deep(.route-timeline .n-timeline-item) {
	width: 100%;
}

:deep(.route-timeline .n-timeline-item-content) {
	width: calc(100% - (var(--n-icon-size) + 12px));
}

:deep(.route-timeline .n-timeline-item-content__content) {
	width: 100%;
}

:deep(.route-timeline .n-timeline-item-content__title) {
	margin-bottom: 0.65rem;
}
</style>
