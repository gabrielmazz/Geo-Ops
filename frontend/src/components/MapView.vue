<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from 'vue'
import L, { Map as LMap, type LeafletMouseEvent } from 'leaflet'
import 'leaflet/dist/leaflet.css'

type GeoPoint = [number, number]

const props = defineProps<{
	maxPoints?: number
	routeCoordinates?: Array<{ lat: number; lon: number }>
}>()
const emit = defineEmits<{
	(e: 'update:points', value: GeoPoint[]): void
}>()

const mapEl = ref<HTMLDivElement | null>(null)
let map: LMap | null = null
let markerLayer: L.LayerGroup | null = null
let routePolyline: L.Polyline | null = null
const selectedPoints = ref<GeoPoint[]>([])

const refreshMarkers = () => {
	if (!map || !markerLayer) return

	const layer = markerLayer
	layer.clearLayers()
	selectedPoints.value.forEach((point, index) => {
		const [lat, lng] = point
		L.marker([lat, lng])
			.addTo(layer)
			.bindTooltip(`Posição ${index + 1}`, {
				permanent: true,
				direction: 'top',
				offset: [0, -12],
			})
	})

	if (routePolyline) {
		updateRoutePolyline()
	}
}

const handleMapClick = (event: LeafletMouseEvent) => {
	const point: GeoPoint = [Number(event.latlng.lat.toFixed(6)), Number(event.latlng.lng.toFixed(6))]

	const maxPoints = props.maxPoints ?? 2
	const updated = selectedPoints.value.slice()

	if (updated.length >= maxPoints) {
		updated.shift()
	}

	updated.push(point)
	selectedPoints.value = updated
	refreshMarkers()
	emit('update:points', selectedPoints.value)
}

const updateRoutePolyline = () => {
	if (!map) return

	const coordinates = props.routeCoordinates ?? []

	if (coordinates.length < 2) {
		routePolyline?.remove()
		routePolyline = null
		return
	}

	const latLngs = coordinates.map(({ lat, lon }) => [lat, lon]) as [number, number][]

	if (!routePolyline) {
		routePolyline = L.polyline(latLngs, {
			color: '#2563eb',
			weight: 5,
			opacity: 0.85,
			lineJoin: 'round',
			lineCap: 'round',
		}).addTo(map)
	} else {
		routePolyline.setLatLngs(latLngs)
	}

	const bounds = L.latLngBounds(latLngs)
	selectedPoints.value.forEach((point) => {
		bounds.extend([point[0], point[1]])
	})

	if (bounds.isValid()) {
		map.fitBounds(bounds.pad(0.15))
	}
}

onMounted(() => {
	map = L.map(mapEl.value as HTMLDivElement, {
		zoomControl: true,
		attributionControl: true,
	}).setView([-15.78, -47.93], 4)

	markerLayer = L.layerGroup().addTo(map)

	L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
		maxZoom: 19,
		attribution:
			'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
	}).addTo(map)

	map.on('click', handleMapClick)
	updateRoutePolyline()
})

onBeforeUnmount(() => {
	if (map) {
		map.off('click', handleMapClick)
		markerLayer?.clearLayers()
		map.remove()
	}

	routePolyline?.remove()
	routePolyline = null
	markerLayer = null
	map = null
})

watch(
	() => props.routeCoordinates,
	() => {
		updateRoutePolyline()
	},
	{ deep: true },
)
</script>

<template>
	<div ref="mapEl" class="map-container"></div>
</template>

<style scoped>
.map-container {
	width: 100%;
	height: 100%;
	min-height: 60vh;
	border-radius: 12px;
	overflow: hidden;
}
</style>
