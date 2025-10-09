<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from 'vue'
import L, { Map as LMap, type LeafletMouseEvent } from 'leaflet'
import 'leaflet/dist/leaflet.css'

type GeoPoint = [number, number]

const DEFAULT_ROUTE_COLOR = '#22c55e'
const DEFAULT_POINT_COLOR = '#22c55e'
const LIGHT_TILE_LAYER = {
	url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
	options: {
		maxZoom: 19,
		attribution:
			'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
	},
} as const
const DARK_TILE_LAYER = {
	url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
	options: {
		maxZoom: 19,
		subdomains: 'abcd',
		attribution:
			'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
	},
} as const

const props = defineProps<{
	maxPoints?: number
	routeCoordinates?: Array<{ lat: number; lon: number }>
	routeColor?: string
	pointColor?: string
	isDarkMode?: boolean
}>()
const emit = defineEmits<{
	(e: 'update:points', value: GeoPoint[]): void
}>()

const mapEl = ref<HTMLDivElement | null>(null)
let map: LMap | null = null
let markerLayer: L.LayerGroup | null = null
let routePolyline: L.Polyline | null = null
let tileLayer: L.TileLayer | null = null
let currentTileMode: 'light' | 'dark' | null = null
const selectedPoints = ref<GeoPoint[]>([])

const getRouteColor = () => {
	const color = props.routeColor?.trim()
	return color && color.length > 0 ? color : DEFAULT_ROUTE_COLOR
}

const getPointColor = () => {
	const color = props.pointColor?.trim()
	return color && color.length > 0 ? color : DEFAULT_POINT_COLOR
}

const applyTileLayer = (isDark: boolean) => {
	if (!map) return

	const mode: 'light' | 'dark' = isDark ? 'dark' : 'light'
	if (currentTileMode === mode && tileLayer) {
		return
	}

	const config = mode === 'dark' ? DARK_TILE_LAYER : LIGHT_TILE_LAYER
	const nextLayer = L.tileLayer(config.url, config.options)

	if (tileLayer) {
		map.removeLayer(tileLayer)
	}

	tileLayer = nextLayer.addTo(map)
	currentTileMode = mode
}

const refreshMarkers = () => {
	if (!map || !markerLayer) return

	const layer = markerLayer
	layer.clearLayers()

	const markerColor = getPointColor()
	selectedPoints.value.forEach((point, index) => {
		const [lat, lng] = point
		L.circleMarker([lat, lng], {
			radius: 8,
			color: markerColor,
			weight: 3,
			opacity: 1,
			fillColor: markerColor,
			fillOpacity: 0.85,
		})
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
		updated.length = 0
	}

	selectedPoints.value = [...updated, point]
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
			color: getRouteColor(),
			weight: 5,
			opacity: 0.85,
			lineJoin: 'round',
			lineCap: 'round',
		}).addTo(map)
	} else {
		routePolyline.setLatLngs(latLngs)
	}

	routePolyline.setStyle({ color: getRouteColor() })

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

	applyTileLayer(Boolean(props.isDarkMode))

	map.on('click', handleMapClick)
	updateRoutePolyline()
})

onBeforeUnmount(() => {
	if (map) {
		map.off('click', handleMapClick)
		markerLayer?.clearLayers()
		if (tileLayer) {
			map.removeLayer(tileLayer)
		}
		map.remove()
	}

	routePolyline?.remove()
	routePolyline = null
	markerLayer = null
	tileLayer = null
	currentTileMode = null
	map = null
})

watch(
	() => props.routeCoordinates,
	() => {
		updateRoutePolyline()
	},
	{ deep: true },
)

watch(
	() => props.routeColor,
	() => {
		if (routePolyline) {
			routePolyline.setStyle({ color: getRouteColor() })
		}
	},
)

watch(
	() => props.pointColor,
	() => {
		refreshMarkers()
	},
)

watch(
	() => props.isDarkMode,
	(value) => {
		applyTileLayer(Boolean(value))
	},
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
	background-color: var(--color-page-muted);
	transition: background-color 0.3s ease;
}
</style>
