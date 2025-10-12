<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from 'vue'
import L, {
	Map as LMap,
	type LeafletMouseEvent,
	type Marker as LMarker,
	type LeafletEventHandlerFn,
} from 'leaflet'
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
	resetToken?: number
	enablePointEditing?: boolean
}>()
type PointMovedPayload = {
	index: number
	previous: GeoPoint
	current: GeoPoint
	label: string
}

const emit = defineEmits<{
	(e: 'update:points', value: GeoPoint[]): void
	(e: 'point-moved', payload: PointMovedPayload): void
}>()

const mapEl = ref<HTMLDivElement | null>(null)
let map: LMap | null = null
let markerLayer: L.LayerGroup | null = null
let routePolyline: L.Polyline | null = null
let tileLayer: L.TileLayer | null = null
let currentTileMode: 'light' | 'dark' | null = null
const selectedPoints = ref<GeoPoint[]>([])

const trimPointsToLimit = (points: GeoPoint[], limit: number): GeoPoint[] => {
	if (limit <= 0 || points.length === 0) {
		return []
	}

	if (points.length <= limit) {
		return [...points]
	}

	if (limit === 1) {
		return [points[0] as GeoPoint]
	}

	const origin = points[0] as GeoPoint
	const lastIndex = points.length - 1
	const destination = (points[lastIndex] as GeoPoint) ?? origin

	if (limit === 2 || lastIndex < 1) {
		return [origin, destination]
	}

	const availableWaypoints = points.slice(1, lastIndex)
	const desiredWaypointCount = Math.min(limit - 2, availableWaypoints.length)

	return [origin, ...(availableWaypoints.slice(0, desiredWaypointCount) as GeoPoint[]), destination]
}

const getRouteColor = () => {
	const color = props.routeColor?.trim()
	return color && color.length > 0 ? color : DEFAULT_ROUTE_COLOR
}

const getPointColor = () => {
	const color = props.pointColor?.trim()
	return color && color.length > 0 ? color : DEFAULT_POINT_COLOR
}

const createMarkerIcon = (color: string, draggable = false) =>
	L.divIcon({
		className: `geo-marker-icon${draggable ? ' geo-marker-icon--draggable' : ''}`,
		html: `<span class="geo-marker-icon__inner" style="--marker-color:${color};"></span>`,
		iconSize: [24, 24],
		iconAnchor: [12, 12],
	})

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
	const editingEnabled = Boolean(props.enablePointEditing)
	const lastIndex = selectedPoints.value.length - 1
	let waypointCounter = 0

	selectedPoints.value.forEach((point, index) => {
		const [lat, lng] = point
		const roleLabel =
			index === 0
				? 'Origem'
				: index === lastIndex
					? 'Destino'
					: `Ponto ${++waypointCounter}`

			if (editingEnabled) {
				const previousPoint: GeoPoint = [point[0], point[1]]
				const marker = L.marker([lat, lng], {
					icon: createMarkerIcon(markerColor, true),
					draggable: true,
					autoPan: true,
				}).addTo(layer)

			marker.bindTooltip(roleLabel, {
				permanent: true,
				direction: 'top',
				offset: [0, -12],
			})

			const handleDragEnd: LeafletEventHandlerFn = (event) => {
				const target = event.target as LMarker
				const { lat: newLat, lng: newLng } = target.getLatLng()

				const normalized: GeoPoint = [
					Number(newLat.toFixed(6)),
					Number(newLng.toFixed(6)),
				]
	
					const updatedPoints = selectedPoints.value.slice()
					updatedPoints[index] = normalized
					selectedPoints.value = updatedPoints
	
					emit('update:points', updatedPoints)
					emit('point-moved', {
						index,
						previous: previousPoint,
						current: normalized,
						label: roleLabel,
					})
					refreshMarkers()
				}

			marker.on('dragend', handleDragEnd)
		} else {
			L.circleMarker([lat, lng], {
				radius: 8,
				color: markerColor,
				weight: 3,
				opacity: 1,
				fillColor: markerColor,
				fillOpacity: 0.85,
			})
				.addTo(layer)
				.bindTooltip(roleLabel, {
					permanent: true,
					direction: 'top',
					offset: [0, -12],
				})
		}
	})

	if (routePolyline) {
		updateRoutePolyline()
	}
}

const handleMapClick = (event: LeafletMouseEvent) => {
	const point: GeoPoint = [Number(event.latlng.lat.toFixed(6)), Number(event.latlng.lng.toFixed(6))]

	const rawLimit = props.maxPoints ?? 2
	const parsedLimit = Number(rawLimit)
	const maxPoints = Number.isFinite(parsedLimit) ? Math.max(2, Math.floor(parsedLimit)) : 2
	const updated = selectedPoints.value.slice()

	if (updated.length >= maxPoints) {
		// Reinicia, mantendo o novo clique como origem
		selectedPoints.value = [point]
	} else {
		selectedPoints.value = [...updated, point]
	}

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
	() => props.enablePointEditing,
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

watch(
	() => props.maxPoints,
	(value) => {
		const rawLimit = value ?? 2
		const parsedLimit = Number(rawLimit)
		const limit = Number.isFinite(parsedLimit) ? Math.max(2, Math.floor(parsedLimit)) : 2

		const trimmed = trimPointsToLimit(selectedPoints.value, limit)
		if (trimmed.length !== selectedPoints.value.length) {
			selectedPoints.value = trimmed
			refreshMarkers()
			emit('update:points', trimmed)
		}
	},
)

watch(
	() => props.resetToken,
	(token, previous) => {
		if (token === undefined || token === previous) {
			return
		}

		selectedPoints.value = []
		markerLayer?.clearLayers()
		if (routePolyline) {
			routePolyline.remove()
			routePolyline = null
		}
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

:global(.geo-marker-icon) {
	background: transparent;
	border: none;
	pointer-events: auto;
}

:global(.geo-marker-icon--draggable) {
	cursor: grab;
}

:global(.geo-marker-icon--draggable:active) {
	cursor: grabbing;
}

:global(.geo-marker-icon__inner) {
	display: block;
	width: 18px;
	height: 18px;
	border-radius: 9999px;
	border: 3px solid var(--marker-color);
	background-color: var(--marker-color);
	box-shadow: 0 0 8px rgba(0, 0, 0, 0.35);
}
</style>
