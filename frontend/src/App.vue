<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { darkTheme, type GlobalThemeOverrides } from 'naive-ui'
import { helloApi, requestRoute, type RouteResponse } from './services/api'

// Importação dos componentes locais
import MapView from './components/MapView.vue'

// Importação dos componentes montados
import Alert from './components/Alert.vue'
import Button from './components/Button.vue'
import RouteTimeline from './components/RouteTimeline.vue'
import Drawer from './components/Drawer.vue'
import ColorPicker from './components/ColorPicker.vue'
import Switch from './components/Switch.vue'
import Modal from './components/Modal.vue'
import NumberInput from './components/NumberInput.vue'

// Componente que mostra o nome junto com uma animação
import ViewLoader from './components/ViewLoader.vue'

// Imagens usadas no sistema
import LogoAliare from './assets/images/logos/logo-aliare.png'

import { useThemeStore } from './stores/theme'

type GeoPoint = [number, number]
type MapViewExposed = {
	getContainer: () => HTMLDivElement | null
}

const themeStore = useThemeStore()
const isDark = computed({
	get: () => themeStore.isDark,
	set: (value: boolean) => {
		themeStore.setTheme(value)
	},
})

const themeOverrides: GlobalThemeOverrides = {
	common: {
		fontFamily:
			'"Inter", system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
		primaryColor: '#2563eb',
		primaryColorHover: '#1d4ed8',
		primaryColorPressed: '#1d4ed8',
		primaryColorSuppl: '#1d4ed8',
	},
}

const message = ref('')
const error = ref<string | null>(null)
const loading = ref(true)
const selectedPoints = ref<GeoPoint[]>([])
const routeResult = ref<RouteResponse | null>(null)
const routeError = ref<string | null>(null)
const routeLoading = ref(false)
const isPointEditingEnabled = ref(false)
const isRouteApproximationEnabled = ref(true)
const DEFAULT_ROUTE_COLOR = '#22c55e'
const DEFAULT_POINT_COLOR = '#22c55e'
const routeColor = ref<string>(DEFAULT_ROUTE_COLOR)
const pointColor = ref<string>(DEFAULT_POINT_COLOR)
const EARTH_RADIUS_METERS = 6_371_000
const MAX_SNAP_DISTANCE_METERS = 8_000
const maxSelectablePoints = ref<number | null>(2)
const mapResetToken = ref(0)
const mapViewRef = ref<MapViewExposed | null>(null)
const introModalThemeClass = computed(() => (isDark.value ? 'intro-modal--dark' : 'intro-modal--light'))
const floatingPanelThemeClass = computed(() =>
	isDark.value ? 'floating-panel--dark' : 'floating-panel--light',
)

type QuickCommand = {
	keyLabel: string
	description: string
}

const quickCommands: QuickCommand[] = [
	{ keyLabel: 'R', description: 'Redefinir pontos selecionados.' },
	{ keyLabel: 'E', description: 'Editar pontos diretamente no mapa (arrastar marcadores).' },
	{ keyLabel: 'A', description: 'Gerar pontos aleatórios válidos em todo o mapa.' },
	{ keyLabel: 'C', description: 'Abrir ou fechar o painel de personalizações.' },
	{ keyLabel: 'I', description: 'Aleatorizar a cor da rota e dos pontos.' },
	{ keyLabel: 'O', description: 'Restaurar a cor padrão da rota e dos pontos.' },
	{ keyLabel: 'P', description: 'Salvar uma imagem do mapa atual com rota e pontos.' },
]

const normalizedMaxSelectablePoints = computed(() => {
	const rawValue = maxSelectablePoints.value
	if (rawValue === null || rawValue === undefined) {
		return 2
	}

	const parsedValue = Number(rawValue)
	if (!Number.isFinite(parsedValue)) {
		return 2
	}

	return Math.min(10, Math.max(2, Math.floor(parsedValue)))
})

type AlertType = 'default' | 'info' | 'success' | 'warning' | 'error'

type AppAlert = {
	id: number
	title?: string
	message: string
	type: AlertType
	timer?: ReturnType<typeof setTimeout>
}

const alerts = ref<AppAlert[]>([])
let alertIdCounter = 0

type SelectedPointDisplay = {
	key: string
	coords: GeoPoint
	label: string
	role: 'origin' | 'destination' | 'waypoint'
	classes: string
}

const routeCoordinates = computed(() => routeResult.value?.coordinates ?? [])
const routeNodes = computed(() => routeResult.value?.nodes ?? [])

type InvalidPointDetail = {
	role: 'origin' | 'destination' | 'waypoint'
	index: number
	coords: GeoPoint
	distanceMeters: number
}

const getPointRole = (index: number, total: number): InvalidPointDetail['role'] => {
	if (index === 0) {
		return 'origin'
	}
	if (index === total - 1) {
		return 'destination'
	}
	return 'waypoint'
}

const getPointLabel = (index: number, total: number): string => {
	const role = getPointRole(index, total)
	if (role === 'origin') {
		return 'Origem'
	}
	if (role === 'destination') {
		return 'Destino'
	}
	return `Ponto ${index}`
}

const toRadians = (value: number): number => (value * Math.PI) / 180

const distanceBetweenPoints = (pointA: GeoPoint, pointB: GeoPoint): number => {
	const [lat1, lon1] = pointA
	const [lat2, lon2] = pointB
	const dLat = toRadians(lat2 - lat1)
	const dLon = toRadians(lon2 - lon1)
	const lat1Rad = toRadians(lat1)
	const lat2Rad = toRadians(lat2)
	const a =
		Math.sin(dLat / 2) ** 2 +
		Math.cos(lat1Rad) * Math.cos(lat2Rad) * Math.sin(dLon / 2) ** 2
	return 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(Math.max(a, 0)))
}

const generateRandomHexColor = (): string =>
	`#${Math.floor(Math.random() * 0xffffff)
		.toString(16)
		.padStart(6, '0')}`

const isTypingTarget = (event: KeyboardEvent): boolean => {
	const target = event.target
	if (!(target instanceof HTMLElement)) {
		return false
	}

	if (target.isContentEditable) {
		return true
	}

	const tagName = target.tagName
	return tagName === 'INPUT' || tagName === 'TEXTAREA' || tagName === 'SELECT'
}

const LAND_REGIONS = [
	{ lat: { min: -23.9, max: -22.7 }, lon: { min: -47.2, max: -45.5 } }, 	// São Paulo / Campinas
	{ lat: { min: -23.1, max: -22.7 }, lon: { min: -43.8, max: -43.0 } }, 	// Rio de Janeiro
	{ lat: { min: -20.1, max: -19.6 }, lon: { min: -44.1, max: -43.7 } }, 	// Belo Horizonte
	{ lat: { min: -15.9, max: -15.4 }, lon: { min: -48.1, max: -47.7 } }, 	// Brasília
	{ lat: { min: -16.0, max: -15.6 }, lon: { min: -49.4, max: -48.8 } }, 	// Goiânia
	{ lat: { min: -25.6, max: -25.2 }, lon: { min: -49.4, max: -48.9 } }, 	// Curitiba
	{ lat: { min: -30.2, max: -29.9 }, lon: { min: -51.3, max: -50.9 } }, 	// Porto Alegre
	{ lat: { min: -12.9, max: -12.8 }, lon: { min: -38.5, max: -38.3 } }, 	// Salvador
	{ lat: { min: -8.1, max: -7.9 }, lon: { min: -35.1, max: -34.9 } }, 	// Recife
	{ lat: { min: -3.9, max: -3.6 }, lon: { min: -38.7, max: -38.3 } }, 	// Fortaleza
	{ lat: { min: -1.5, max: -1.1 }, lon: { min: -48.6, max: -48.1 } }, 	// Belém
	{ lat: { min: -20.6, max: -20.2 }, lon: { min: -54.8, max: -54.4 } }, 	// Campo Grande
] as const

type LandRegion = (typeof LAND_REGIONS)[number]

const randomBetween = (min: number, max: number) => min + Math.random() * (max - min)

const createRandomGeoPoint = (region?: LandRegion): GeoPoint => {
	const regionIndex = Math.floor(Math.random() * LAND_REGIONS.length)
	const targetRegion: LandRegion = region ?? LAND_REGIONS[regionIndex]!
	const lat = randomBetween(targetRegion.lat.min, targetRegion.lat.max)
	const lon = randomBetween(targetRegion.lon.min, targetRegion.lon.max)
	return [Number(lat.toFixed(6)), Number(lon.toFixed(6))]
}

const generateRandomPoints = (count: number): GeoPoint[] => {
	const points: GeoPoint[] = []
	const usedRegionIndices = new Set<number>()
	const uniqueKeys = new Set<string>()

	while (points.length < count) {
		let regionIndex: number
		if (points.length < LAND_REGIONS.length) {
			const availableIndices = LAND_REGIONS.map((_, index) => index).filter(
				(index) => !usedRegionIndices.has(index),
			)

			if (availableIndices.length > 0) {
				regionIndex = availableIndices[Math.floor(Math.random() * availableIndices.length)]!
				usedRegionIndices.add(regionIndex)
			} else {
				regionIndex = Math.floor(Math.random() * LAND_REGIONS.length)
			}
		} else {
			regionIndex = Math.floor(Math.random() * LAND_REGIONS.length)
		}

		const region = LAND_REGIONS[regionIndex]!
		const point = createRandomGeoPoint(region)
		const key = point.join(',')
		if (uniqueKeys.has(key)) {
			continue
		}

		points.push(point)
		uniqueKeys.add(key)
	}

	return points
}

const MAX_RANDOM_ROUTE_ATTEMPTS = 12

type IntroHighlight = {
	icon: string
	title: string
	description: string
}

const introHighlights: IntroHighlight[] = [
	{
		icon: '📍',
		title: 'Marque pontos estratégicos',
		description:
			'Selecione fazendas, centros de distribuição e destinos diretamente no mapa interativo.',
	},
	{
		icon: '🧭',
		title: 'Rotas otimizadas automaticamente',
		description:
			'Combine a roteirização inteligente com ajustes automáticos para encontrar o melhor trajeto.',
	},
	{
		icon: '🎨',
		title: 'Personalize do seu jeito',
		description:
			'Ajuste cores, edição de pontos e preferências de aproximação para alinhar o Geo-Ops à sua operação.',
	},
]

type RouteValidationResult =
	| { kind: 'valid' }
	| {
			kind: 'invalid-origin' | 'invalid-destination' | 'invalid-both'
			title: string
			message: string
			invalidPoints?: InvalidPointDetail[]
		}

const validateRouteAnchors = (
	route: RouteResponse,
	points: GeoPoint[],
): RouteValidationResult => {
	if (!points.length || route.coordinates.length < 2) {
		return {
			kind: 'invalid-both',
			title: 'Rota indisponível',
			message:
				'Não foi possível traçar a rota com os pontos selecionados. Escolha marcadores em terra firme.',
		}
	}

	const originPoint = points[0]
	const destinationPoint = points[points.length - 1]

	if (!originPoint || !destinationPoint) {
		return {
			kind: 'invalid-both',
			title: 'Pontos insuficientes',
			message:
				'Não foi possível validar a rota. Selecione novamente os pontos de origem e destino.',
		}
	}

	const [originLat, originLon] = originPoint
	const [destinationLat, destinationLon] = destinationPoint
	const firstRouteCoordinate = route.coordinates[0]
	const lastRouteCoordinate = route.coordinates[route.coordinates.length - 1]

	const firstCoordinate: GeoPoint = [
		firstRouteCoordinate?.lat ?? originLat,
		firstRouteCoordinate?.lon ?? originLon,
	]
	const lastCoordinate: GeoPoint = [
		lastRouteCoordinate?.lat ?? destinationLat,
		lastRouteCoordinate?.lon ?? destinationLon,
	]

	const originDistance = distanceBetweenPoints(originPoint, firstCoordinate)
	const destinationDistance = distanceBetweenPoints(destinationPoint, lastCoordinate)
	const originInvalid = originDistance > MAX_SNAP_DISTANCE_METERS
	const destinationInvalid = destinationDistance > MAX_SNAP_DISTANCE_METERS
	const invalidPoints: InvalidPointDetail[] = []

	if (originInvalid && destinationInvalid) {
		invalidPoints.push(
			{
				role: 'origin',
				index: 0,
				coords: originPoint,
				distanceMeters: originDistance,
			},
			{
				role: 'destination',
				index: points.length - 1,
				coords: destinationPoint,
				distanceMeters: destinationDistance,
			},
		)
		return {
			kind: 'invalid-both',
			title: 'Pontos inválidos',
			message:
				'Não foi possível traçar a rota. Os dois pontos selecionados parecem estar no oceano. Escolha locais em terra.',
			invalidPoints,
		}
	}

	if (originInvalid) {
		invalidPoints.push({
			role: 'origin',
			index: 0,
			coords: originPoint,
			distanceMeters: originDistance,
		})
		return {
			kind: 'invalid-origin',
			title: 'Origem inválida',
			message:
				'Não foi possível traçar a rota. O ponto de origem está em uma área sem acesso por terra (possivelmente oceano). Ajuste a marcação.',
			invalidPoints,
		}
	}

	if (destinationInvalid) {
		invalidPoints.push({
			role: 'destination',
			index: points.length - 1,
			coords: destinationPoint,
			distanceMeters: destinationDistance,
		})
		return {
			kind: 'invalid-destination',
			title: 'Destino inválido',
			message:
				'Não foi possível traçar a rota. O ponto de destino está em uma área sem acesso por terra (possivelmente oceano). Ajuste a marcação.',
			invalidPoints,
		}
	}

	return { kind: 'valid' }
}

type TimelineItem = {
	key: string
	label: string
	coordinate: { lat: number; lon: number }
	role: 'origin' | 'destination' | 'waypoint'
	badgeClasses: string
}

const routeTimelineItems = computed(() => {
	const coords = routeCoordinates.value
	const nodes = routeNodes.value
	if (!coords.length) {
		return []
	}

	const lastIndex = coords.length - 1
	let waypointCount = 0

	const roleClasses: Record<TimelineItem['role'], string> = {
		origin: 'badge badge--origin',
		destination: 'badge badge--destination',
		waypoint: 'badge badge--waypoint',
	}

	const items = coords.map<TimelineItem>((coordinate, index) => {
		const role: TimelineItem['role'] =
			index === 0 ? 'origin' : index === lastIndex ? 'destination' : 'waypoint'

		const baseLabel =
			role === 'origin'
				? 'Origem'
				: role === 'destination'
					? 'Destino'
					: `Ponto ${++waypointCount}`
		const label = nodes[index] ?? baseLabel

		return {
			key: `${coordinate.lat}-${coordinate.lon}-${index}`,
			label,
			coordinate,
			role,
			badgeClasses: roleClasses[role],
		}
	})

	const originItem = items[0]!
	const destinationItem = items.length > 1 ? items[items.length - 1]! : null
	const waypointItems = items.slice(1, items.length - (destinationItem ? 1 : 0))

	return destinationItem
		? [originItem, ...waypointItems, destinationItem]
		: [originItem, ...waypointItems]
})

const maxPointsSummary = computed(() => {
	const limit = normalizedMaxSelectablePoints.value
	const positionsText = `${limit} ${limit === 1 ? 'posição' : 'posições'}`

	if (limit <= 0) {
		return '0 posições'
	}

	if (limit === 1) {
		return `${positionsText} (origem)`
	}

	if (limit === 2) {
		return `${positionsText} (origem e destino)`
	}

	const intermediateCount = limit - 2
	const intermediateText = `${intermediateCount} ${
		intermediateCount === 1 ? 'ponto intermediário' : 'pontos intermediários'
	}`

	return `${positionsText} (origem, ${intermediateText} e destino)`
})

// Estado do drawer de ações -> Drawer para ver os pontos que foram selecionados
const isActionsDrawerOpen = ref(false)

// Estado do drawer de personalizações -> Drawer para ver as personalizações do mapa
const isCustomizationsDrawerOpen = ref(false)

// Estado do modal que mostra o meu nome e a animação
const isModalOpenName = ref(false)

// Estado do modal para mostrar sempre que carregar a tela pela primeira vez
const isModalOpenFirstLoad = ref(true)

const handlePointsUpdate = (points: GeoPoint[]) => {
	selectedPoints.value = points
}

type PointMovedEvent = {
	index: number
	previous: GeoPoint
	current: GeoPoint
	label: string
}

const formatPoint = (point: GeoPoint) =>
	`${point[0].toFixed(6)}, ${point[1].toFixed(6)}`

const formatDistance = (meters: number): string => {
	if (!Number.isFinite(meters)) {
		return 'distância desconhecida'
	}

	if (meters >= 1000) {
		return `${(meters / 1000).toFixed(2)} km`
	}

	return `${Math.round(meters)} m`
}

const handlePointMoved = ({ label, previous, current }: PointMovedEvent) => {
	pushAlert({
		title: `${label} ajustado`,
		type: 'info',
		message: `Posição atualizada de ${formatPoint(previous)} para ${formatPoint(current)}.`,
	})
}

const isRouteComputationError = (error: unknown): boolean =>
	error instanceof Error && error.message.startsWith('Falha ao calcular rota')

const diagnoseRouteFailure = async (points: GeoPoint[]): Promise<InvalidPointDetail[]> => {
	if (points.length < 2) {
		return []
	}

	const allowApproximation = isRouteApproximationEnabled.value
	const total = points.length
	const invalidIndices = new Set<number>()

	// Remove individual waypoints to detect culpados.
	for (let index = 1; index < total - 1; index += 1) {
		const subset = points.filter((_, currentIndex) => currentIndex !== index) as GeoPoint[]
		try {
			await requestRoute(subset, { allowApproximation })
			invalidIndices.add(index)
		} catch (error) {
			if (!isRouteComputationError(error)) {
				throw error
			}
		}
	}

	if (invalidIndices.size > 0) {
		return Array.from(invalidIndices).map((index) => ({
			role: getPointRole(index, total),
			index,
			coords: points[index]!,
			distanceMeters: Number.NaN,
		}))
	}

	// Avalia segmentos consecutivos para encontrar trechos inviáveis.
	const pointStats = points.map(() => ({ success: 0, failure: 0 }))

	for (let index = 0; index < total - 1; index += 1) {
		const segment: GeoPoint[] = [points[index]!, points[index + 1]!]
		const currentStats = pointStats[index]!
		const nextStats = pointStats[index + 1]!

		try {
			await requestRoute(segment, { allowApproximation })
			currentStats.success += 1
			nextStats.success += 1
		} catch (error) {
			if (!isRouteComputationError(error)) {
				throw error
			}
			currentStats.failure += 1
			nextStats.failure += 1
		}
	}

	pointStats.forEach((stat, index) => {
		if (stat.failure === 0) {
			return
		}

		const isEndpoint = index === 0 || index === total - 1
		if (isEndpoint || stat.success === 0 || stat.failure >= stat.success) {
			invalidIndices.add(index)
		}
	})

	return Array.from(invalidIndices).map((index) => ({
		role: getPointRole(index, total),
		index,
		coords: points[index]!,
		distanceMeters: Number.NaN,
	}))
}

let routeRequestToken = 0
let skipNextRouteComputation = false

const resetRouteState = () => {
	routeRequestToken += 1
	routeResult.value = null
	routeError.value = null
	routeLoading.value = false
}

const selectedPointsDisplay = computed<SelectedPointDisplay[]>(() => {
	const points = selectedPoints.value
	if (!points.length) {
		return []
	}

	const roleClasses: Record<SelectedPointDisplay['role'], string> = {
		origin: 'point-pill point-pill--origin',
		destination: 'point-pill point-pill--destination',
		waypoint: 'point-pill point-pill--waypoint',
	}

	return points
		.map<SelectedPointDisplay>((point, index) => {
			const role = getPointRole(index, points.length)
			const label = getPointLabel(index, points.length)
			return {
				key: `${point[0]}-${point[1]}-${index}`,
				coords: point,
				label,
				role,
				classes: roleClasses[role],
			}
		})
		.sort((a, b) => {
			if (a.role === b.role) {
				return 0
			}
			if (a.role === 'origin') {
				return -1
			}
			if (b.role === 'destination') {
				return -1
			}
			if (a.role === 'destination') {
				return 1
			}
			return 1
		})
})

const pushAlert = (alert: Omit<AppAlert, 'id' | 'timer'> & { durationMs?: number }) => {
	alertIdCounter += 1
	const durationMs = alert.durationMs ?? 5000

	const alertEntry: AppAlert = {
		id: alertIdCounter,
		...alert,
	}

	alertEntry.timer = setTimeout(() => {
		removeAlert(alertEntry.id)
	}, durationMs)

	alerts.value.push(alertEntry)
}

const removeAlert = (id: number) => {
	alerts.value = alerts.value.reduce<AppAlert[]>((acc, alert) => {
		if (alert.id === id) {
			if (alert.timer) {
				clearTimeout(alert.timer)
			}
			return acc
		}
		return acc.concat(alert)
	}, [])
}

const resetSelectedPoints = ({ silent }: { silent?: boolean } = {}) => {
	const hadPoints = selectedPoints.value.length > 0

	if (hadPoints) {
		selectedPoints.value = []
	}

	mapResetToken.value += 1
	resetRouteState()

	if (!silent) {
		if (hadPoints) {
			pushAlert({
				title: 'Pontos redefinidos',
				type: 'info',
				message: 'Todos os marcadores foram removidos. Selecione novos pontos no mapa.',
			})
		} else {
			pushAlert({
				title: 'Nada para redefinir',
				type: 'info',
				message: 'Nenhum ponto estava selecionado.',
				durationMs: 3000,
			})
		}
	}
}

const handleMaxPointsChange = () => {
	resetSelectedPoints({ silent: true })
}

const togglePointEditing = () => {
	isPointEditingEnabled.value = !isPointEditingEnabled.value
	pushAlert({
		title: 'Edição de pontos',
		type: 'info',
		message: isPointEditingEnabled.value
			? 'Modo de edição ativado. Arraste os marcadores para ajustar a rota.'
			: 'Modo de edição desativado. Os marcadores voltam a ficar fixos.',
		durationMs: 4000,
	})
}

const randomizeSelectedPointsPositions = async () => {
	if (routeLoading.value) {
		return
	}

	const limit = normalizedMaxSelectablePoints.value
	const count = Math.max(2, limit)
	const allowApproximation = isRouteApproximationEnabled.value

	routeError.value = null
	const randomizationToken = ++routeRequestToken
	routeLoading.value = true

	for (let attempt = 1; attempt <= MAX_RANDOM_ROUTE_ATTEMPTS; attempt += 1) {
		const candidatePoints = generateRandomPoints(count)
		try {
			const result = await requestRoute(candidatePoints, { allowApproximation })
			if (randomizationToken !== routeRequestToken) {
				return
			}

			skipNextRouteComputation = true
			routeResult.value = result
			selectedPoints.value = candidatePoints
			routeLoading.value = false

			pushAlert({
				title: 'Rota aleatória pronta',
				type: 'success',
				message: `Uma rota válida com ${count} ponto${count > 1 ? 's' : ''} foi encontrada na tentativa ${
					attempt
				}.`,
				durationMs: 5000,
			})
			return
		} catch (error) {
			if (!isRouteComputationError(error)) {
				if (randomizationToken === routeRequestToken) {
					routeLoading.value = false
				}
				pushAlert({
					title: 'Falha inesperada',
					type: 'error',
					message:
						error instanceof Error
							? error.message
							: 'Não foi possível gerar uma rota aleatória devido a um erro inesperado.',
				})
				return
			}
		}
	}

	if (randomizationToken === routeRequestToken) {
		routeLoading.value = false
		pushAlert({
			title: 'Não foi possível gerar a rota',
			type: 'error',
			message: 'Nenhuma rota válida foi encontrada após várias tentativas. Tente novamente.',
		})
	}
}

const toggleCustomizationsDrawer = () => {
	isCustomizationsDrawerOpen.value = !isCustomizationsDrawerOpen.value
}

const randomizeRouteAndPointColors = () => {
	const nextRouteColor = generateRandomHexColor()
	let nextPointColor = generateRandomHexColor()

	if (nextPointColor === nextRouteColor) {
		nextPointColor = generateRandomHexColor()
	}

	routeColor.value = nextRouteColor
	pointColor.value = nextPointColor

	pushAlert({
		title: 'Cores aleatórias aplicadas',
		type: 'success',
		message: 'Cor da rota e dos pontos atualizadas aleatoriamente.',
	})
}

const resetRouteAndPointColors = () => {
	const wasRouteChanged = routeColor.value !== DEFAULT_ROUTE_COLOR
	const wasPointChanged = pointColor.value !== DEFAULT_POINT_COLOR

	if (!wasRouteChanged && !wasPointChanged) {
		pushAlert({
			title: 'Cores já estão padrão',
			type: 'info',
			message: 'A rota e os pontos já utilizam as cores padrão.',
		})
		return
	}

	routeColor.value = DEFAULT_ROUTE_COLOR
	pointColor.value = DEFAULT_POINT_COLOR

	pushAlert({
		title: 'Cores redefinidas',
		type: 'info',
		message: 'A cor da rota e dos pontos voltou para o padrão.',
	})
}

const saveMapSnapshot = async () => {
	const container = mapViewRef.value?.getContainer()
	if (!container) {
		pushAlert({
			title: 'Mapa indisponível',
			type: 'error',
			message: 'Não foi possível localizar o mapa para salvar a imagem.',
		})
		return
	}

	try {
		const { toPng } = await import('html-to-image')
		const dataUrl = await toPng(container, {
			cacheBust: true,
			pixelRatio: window.devicePixelRatio ?? 1,
		})

		const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
		const link = document.createElement('a')
		link.href = dataUrl
		link.download = `geo-ops-map-${timestamp}.png`
		link.click()

		pushAlert({
			title: 'Imagem salva',
			type: 'success',
			message: 'Uma imagem do mapa foi gerada e baixada automaticamente.',
		})
	} catch (error) {
		const message =
			error instanceof Error ? error.message : 'Falha desconhecida ao gerar a imagem.'
		pushAlert({
			title: 'Erro ao salvar imagem',
			type: 'error',
			message,
		})
	}
}

const handleGlobalKeydown = (event: KeyboardEvent) => {
	if (event.defaultPrevented) {
		return
	}

	if (isTypingTarget(event)) {
		return
	}

	const key = event.key.toLowerCase()

	switch (key) {
		case 'i':
			event.preventDefault()
			randomizeRouteAndPointColors()
			break
		case 'o':
			event.preventDefault()
			resetRouteAndPointColors()
			break
		case 'p':
			event.preventDefault()
			void saveMapSnapshot()
			break
		case 'r':
			resetSelectedPoints()
			break
		case 'e':
			togglePointEditing()
			break
		case 'a':
			void randomizeSelectedPointsPositions()
			break
		case 'c':
			toggleCustomizationsDrawer()
			break
		default:
	}
}

const closeWelcomeModal = () => {
	isModalOpenFirstLoad.value = false
}

const openPersonalizationsFromIntro = () => {
	isModalOpenFirstLoad.value = false
	isCustomizationsDrawerOpen.value = true
}

const fetchRoute = async (points: GeoPoint[]) => {
	if (points.length < 2) {
		resetRouteState()
		return
	}

	const requestToken = ++routeRequestToken
	routeLoading.value = true
	routeError.value = null

	try {
		const result = await requestRoute(points, {
			allowApproximation: isRouteApproximationEnabled.value,
		})
		const validation = validateRouteAnchors(result, points)

		if (requestToken !== routeRequestToken) {
			return
		}

		if (validation.kind !== 'valid') {
			routeResult.value = null
			routeError.value = validation.message
			pushAlert({
				title: validation.title,
				type: 'warning',
				message: validation.message,
			})
			if (validation.invalidPoints?.length) {
				validation.invalidPoints.forEach((detail) => {
					const label = getPointLabel(detail.index, points.length)
					const formattedCoords = formatPoint(detail.coords)
					const distanceText = formatDistance(detail.distanceMeters)

					pushAlert({
						title: `${label} fora da área válida`,
						type: 'warning',
						message: `${label} em ${formattedCoords} está a ${distanceText} do trajeto disponível. Arraste o marcador para um local em terra firme.`,
					})
				})
			}
			return
		}

		routeResult.value = result
		const coordinatesCount = result.coordinates.length
		const formattedPoints = coordinatesCount.toLocaleString('pt-BR')
		const formattedDistance = Number.isFinite(result.totalCost)
			? result.totalCost.toLocaleString('pt-BR', {
					minimumFractionDigits: 2,
					maximumFractionDigits: 2,
				})
			: null
		const successMessage = formattedDistance
			? `Rota calculada com ${formattedPoints} pontos e ${formattedDistance} km.`
			: `Rota calculada com ${formattedPoints} pontos.`
		pushAlert({
			title: 'Rota calculada',
			type: 'success',
			message: successMessage,
		})
	} catch (err) {
		if (requestToken !== routeRequestToken) {
			return
		}

		routeResult.value = null
		routeError.value = err instanceof Error ? err.message : String(err)

		const fallbackMessage =
			routeError.value ||
			'Ocorreu um erro desconhecido ao calcular a rota. Verifique a conexão com o backend.'
		pushAlert({
			title: 'Erro ao calcular a rota',
			type: 'error',
			message: fallbackMessage,
		})

		try {
			const diagnostics = await diagnoseRouteFailure(points)
			if (requestToken === routeRequestToken) {
				diagnostics.forEach((detail) => {
					const label = getPointLabel(detail.index, points.length)
					const formattedCoords = formatPoint(detail.coords)
					const distanceText = formatDistance(detail.distanceMeters)

					pushAlert({
						title: `${label} precisa ser ajustado`,
						type: 'warning',
						message: `${label} em ${formattedCoords} impede o cálculo da rota (${distanceText}). Arraste o marcador para uma via acessível e tente novamente.`,
					})
				})
			}
		} catch {
			// Ignora falhas de diagnóstico
		}
	} finally {
		if (requestToken === routeRequestToken) {
			routeLoading.value = false
		}
	}
}

const evaluateRouteComputation = () => {
	if (skipNextRouteComputation) {
		skipNextRouteComputation = false
		return
	}

	const points = selectedPoints.value
	const limit = normalizedMaxSelectablePoints.value

	if (points.length < 2 || points.length !== limit) {
		resetRouteState()
		return
	}

	void fetchRoute(points)
}

function dismissRouteError(): void {
	routeError.value = null
}

const loadGreeting = async () => {
	loading.value = true
	error.value = null

	try {
		message.value = await helloApi()
	} catch (err) {
		error.value = err instanceof Error ? err.message : String(err)
	} finally {
		loading.value = false
	}
}

onMounted(() => {
	themeStore.initialize()
	void loadGreeting()
	window.addEventListener('keydown', handleGlobalKeydown)
})

onBeforeUnmount(() => {
	window.removeEventListener('keydown', handleGlobalKeydown)
})

watch(
	selectedPoints,
	() => {
		evaluateRouteComputation()
	},
	{ deep: true },
)

watch(
	normalizedMaxSelectablePoints,
	(normalized) => {
		if (maxSelectablePoints.value !== normalized) {
			maxSelectablePoints.value = normalized
		}
		evaluateRouteComputation()
	},
)

watch(
	() => isRouteApproximationEnabled.value,
	() => {
		evaluateRouteComputation()
	},
)

evaluateRouteComputation()
</script>

<template>
	<n-config-provider :theme="isDark ? darkTheme : null" :theme-overrides="themeOverrides">
		<div class="min-h-screen flex app-shell">

			<main class="flex-1 flex flex-col p-8">
				<div
					class="flex-1 w-full rounded-3xl surface-card backdrop-blur px-10 pt-12 pb-6 space-y-6 flex flex-col">
					
					<div class="relative flex-1 min-h-[60vh]">
						<MapView
							ref="mapViewRef"
							:points="selectedPoints"
							:reset-token="mapResetToken"
							:max-points="normalizedMaxSelectablePoints"
							:route-coordinates="routeCoordinates"
							:route-color="routeColor"
							:point-color="pointColor"
							:is-dark-mode="isDark"
							:enable-point-editing="isPointEditingEnabled"
							@update:points="handlePointsUpdate"
							@point-moved="handlePointMoved"
						/>

						<!-- Painel para mostrar os pontos selecionados no mapa -->
						<div class="pointer-events-none absolute left-6 bottom-6 z-[1000] max-w-xs">
							<div class="floating-panel pointer-events-auto selected-points-panel" :class="floatingPanelThemeClass">
								<span class="floating-panel__glow floating-panel__glow--primary" aria-hidden="true"></span>
								<span class="floating-panel__glow floating-panel__glow--secondary" aria-hidden="true"></span>

								<div class="floating-panel__inner">
									<header class="floating-panel__header">
										<h2 class="floating-panel__title">Pontos selecionados</h2>
										<p class="floating-panel__subtitle selected-points__counter">
											{{ selectedPoints.length }} / {{ normalizedMaxSelectablePoints }}
											{{ selectedPoints.length === 1 ? 'ponto selecionado' : 'pontos selecionados' }}
										</p>
									</header>

									<div class="selected-points__content">
										<p v-if="!selectedPoints.length" class="selected-points__empty">
											Nenhum ponto selecionado.
										</p>
										<ul v-else class="selected-points__list">
											<li v-for="item in selectedPointsDisplay" :key="item.key" :class="item.classes">
												<div class="font-medium">{{ item.label }}</div>
												<div class="point-pill__coords">
													{{ item.coords[0].toFixed(6) }}, {{ item.coords[1].toFixed(6) }}
												</div>
											</li>
										</ul>
									</div>
								</div>
							</div>
						</div>

						<!-- Div do lado direito na parte de baixo para mostrar alguns comandos e atalhos que podem ser utilizados -->
						<div class="pointer-events-none absolute right-6 bottom-6 z-[1000] max-w-xs">
							<div class="floating-panel pointer-events-auto" :class="floatingPanelThemeClass">
								<span class="floating-panel__glow floating-panel__glow--primary" aria-hidden="true"></span>
								<span class="floating-panel__glow floating-panel__glow--secondary" aria-hidden="true"></span>

								<div class="floating-panel__inner">
									<header class="floating-panel__header">
										<h2 class="floating-panel__title">Instruções e comandos rápidos</h2>
										<p class="floating-panel__subtitle">
											Use os atalhos para ajustar rotas e pontos sem interromper o fluxo.
										</p>
									</header>

									<ul class="quick-commands">
										<li v-for="command in quickCommands" :key="command.keyLabel" class="quick-commands__item">
											<span class="quick-commands__key">{{ command.keyLabel }}</span>
											<span class="quick-commands__description">{{ command.description }}</span>
										</li>
									</ul>

									<p class="floating-panel__footer">
										Combine os atalhos para configurar rotas em segundos.
									</p>
								</div>
							</div>
						</div>
					</div>

						<!-- Div responsavel pelos botões e ações que serão possiveis executar no sistema -->
						<n-flex justify="center" align="center" class="w-full gap-4 pt-2 pb-0">
							<!-- Botão responsável por abrir o drawer dos pontos, mostrando uma timeline -->
							<Button
								@click="isActionsDrawerOpen = true"
								:label="'Abrir timeline'"
								button-type="ghost"
								class="metamorphous-regular"
								color="#10b981"
							/>

							<!-- Botão responsável por abrir o drawer de personalizações -->
							<Button
								@click="isCustomizationsDrawerOpen = true"
								:label="'Abrir personalizações'"
								button-type="ghost"
								class="metamorphous-regular"
								color="#10b981"
							/>
						</n-flex>
				</div>
			</main>
		</div>

		<n-flex justify="center">
			<Button @click="isModalOpenName = true" 
					:label="'Desenvolvido por Gabriel Mazzuco'" 
					:button-type="'text'" 
					class="fixed bottom-6 left-6 z-[1200]" />
		</n-flex>


		<!-- Drawer que mostrara todos os pontos selecionados -->
		<!-- A ideia é que ele usa o componente do Native para montar uma timeline
		  	com os pontos selecionados, marcando o ponto de origem, destino e os pontos
		  	intermediários -->
		<Drawer title="Ações disponíveis" v-model:show="isActionsDrawerOpen">
			<section class="space-y-3">
				<h2 class="text-lg font-medium text-primary">Timeline da rota</h2>

				<div v-if="routeLoading" class="text-secondary">Calculando rota...</div>

				<Alert v-else-if="routeError" title="Erro ao calcular a rota" type="error" :show-icon="true"
					:closable="true" :message="routeError || 'Ocorreu um erro desconhecido ao calcular a rota.'"
					@close="dismissRouteError" />

				<RouteTimeline v-else-if="routeTimelineItems.length" :items="routeTimelineItems" />

				<div v-else class="text-secondary">
					Selecione todos os pontos configurados para visualizar a rota.
				</div>
			</section>

		</Drawer>

		<!-- Drawer que mostrara as personalizações do mapa -->
		<Drawer title="Personalizações do mapa" v-model:show="isCustomizationsDrawerOpen">
			<section class="space-y-3">

				<n-h2 class="text-primary">Configurações gerais</n-h2>

				<n-grid
					x-gap="24" :cols="2"
				>
					<n-gi>

						<Switch v-model="isDark" label="Dark Mode"
							description="Ative para mudar o tema do mapa e da aplicação para o modo escuro." />

					</n-gi>

					<n-gi>

						<Switch v-model="routeLoading" label="Modo de carregamento"
							description="Ative para simular o estado de carregamento da rota." />

					</n-gi>

				</n-grid>

				<n-grid
					x-gap="24" :cols="2"
				>
					<n-gi>

						<Switch v-model="isPointEditingEnabled" label="Edição dos pontos"
							description="Permite arrastar os marcadores no mapa para ajustar suas posições." />
						

					</n-gi>

					<n-gi>

						<Switch v-model="isRouteApproximationEnabled" label="Aproximação das rotas"
							description="Ajusta automaticamente os pontos para vias próximas ao calcular a rota." />

					</n-gi>

				</n-grid>



				<n-h2 class="text-primary">Personalização da cor da rota</n-h2>

				<ColorPicker v-model="routeColor" label="Cor da rota" :expected-color="DEFAULT_ROUTE_COLOR" @invalid="(msg) =>
					pushAlert({
						title: 'Cor inválida',
						type: 'warning',
						message: msg,
					})
				" />

				<n-h2 class="text-primary">Personalização do pontos da rota</n-h2>

				<n-p class="text-secondary">
					Altere a cor dos pontos (origem, destino e intermediários) que aparecem no mapa. A cor padrão é #22C55E.
				</n-p>

				<ColorPicker v-model="pointColor" label="Cor dos pontos" :expected-color="DEFAULT_POINT_COLOR" @invalid="(msg) =>
					pushAlert({
						title: 'Cor inválida',
						type: 'warning',
						message: msg,
					})
				" />

				 <!-- Input responsavel por limitar quantidade de pontos que o usuario pode clicar no mapa para definir
				  	  uma rota entre eles --> 
				<NumberInput v-model="maxSelectablePoints" label="Quantidade máxima de pontos"
					description="Defina a quantidade máxima de pontos que podem ser selecionados no mapa para traçar uma rota entre eles."
					:min="2" :max="6" 
					@change="handleMaxPointsChange"
				/>

			</section>
		</Drawer>

		<!-- Modal responsável por mostrar o meu nome e da animação -->
		<Modal
			:show="isModalOpenName"
			@update:show="isModalOpenName = $event"
		>

			<n-h2 class="text-primary text-center mb-4">Desenvolvido por Gabriel Mazzuco</n-h2>
			
			<ViewLoader />

			<div class="space-y-4 mt-12">	
				<n-p class="text-secondary text-center">
					Este foi um projeto para o PDI - Programa de Desenvolvimento Individual do meu trabalho como desenvolvedor na Empresa de Tecnologia voltada para o Agronegócio (Aliare).
				</n-p>
			</div>


			<n-flex justify="center" align="center" class="w-full h-full">
				<n-image
					:src="LogoAliare"
					alt="Logo da Aliare"
					width="250"
					height="auto"
				/>
			</n-flex>

		</Modal>

		<!-- Modal que sempre aparece quando carrega a tela pela primeira vez, introduzindo o sistema -->
		<Modal
			:show="isModalOpenFirstLoad"
			@update:show="isModalOpenFirstLoad = $event"
		>
			<div class="intro-modal" :class="introModalThemeClass">
				<span class="intro-modal__glow intro-modal__glow--primary" aria-hidden="true"></span>
				<span class="intro-modal__glow intro-modal__glow--secondary" aria-hidden="true"></span>

				<div class="intro-modal__inner">
					<div class="intro-header">
						<span class="intro-badge">Geo-Ops · Agronegócio</span>
						<h2 class="intro-title">Bem-vindo ao Geo-Ops</h2>
						<p class="intro-subtitle">
							Planeje rotas inteligentes, conecte operações em campo e tome decisões com confiança.
						</p>
					</div>

					<n-divider dashed />

					<div class="intro-highlights">
						<article v-for="highlight in introHighlights" :key="highlight.title" class="intro-highlight">
							<div class="intro-highlight__icon" aria-hidden="true">
								{{ highlight.icon }}
							</div>
							<div class="intro-highlight__content">
								<h3 class="intro-highlight__title">
									{{ highlight.title }}
								</h3>
								<p class="intro-highlight__description">
									{{ highlight.description }}
								</p>
							</div>
						</article>
					</div>

					<n-divider dashed />

					<div class="intro-footer">
						<p class="intro-note">
							Dica: utilize o atalho <strong>A</strong> para gerar rotas aleatórias com pontos válidos em todo o Brasil.
						</p>
						<div class="intro-actions">
							<Button
								@click="closeWelcomeModal"
								:label="'Explorar agora'"
								color="#2563eb"
							/>
							<Button
								@click="openPersonalizationsFromIntro"
								:label="'Personalizar interface'"
								button-type="ghost"
								color="#22c55e"
							/>
						</div>
					</div>
				</div>
			</div>
		</Modal>

		<!-- Div que ira conter todos os alertas do sistema -->
		<div class="fixed top-6 right-6 z-[1200] flex w-80 flex-col gap-3">
			<Alert v-for="alert in alerts" :key="alert.id" :title="alert.title" :type="alert.type"
				:message="alert.message" :show-icon="true" :closable="true" @close="removeAlert(alert.id)" />
		</div>

	</n-config-provider>
</template>

<!-- Retira a barra de rolagem -->
<style scoped>
:global(html),
:global(body) {
	overflow: hidden;
}

.floating-panel {
	position: relative;
	padding: 1px;
	border-radius: 28px;
	background: linear-gradient(135deg, rgba(37, 99, 235, 0.35), rgba(16, 185, 129, 0.4));
	box-shadow: 0 24px 48px rgba(15, 23, 42, 0.22);
	overflow: hidden;
}

.floating-panel__inner {
	position: relative;
	border-radius: 27px;
	padding: 1.5rem;
	backdrop-filter: blur(18px);
}

.floating-panel--light .floating-panel__inner {
	background: rgba(255, 255, 255, 0.96);
	color: #0f172a;
}

.floating-panel--dark .floating-panel__inner {
	background: rgba(11, 15, 25, 0.9);
	color: #f8fafc;
}

.floating-panel__glow {
	position: absolute;
	border-radius: 9999px;
	filter: blur(80px);
	opacity: 0.6;
}

.floating-panel__glow--primary {
	top: -70px;
	right: -40px;
	width: 180px;
	height: 180px;
	background: rgba(37, 99, 235, 0.8);
}

.floating-panel__glow--secondary {
	bottom: -70px;
	left: -50px;
	width: 160px;
	height: 160px;
	background: rgba(16, 185, 129, 0.75);
}

.floating-panel__header {
	display: grid;
	gap: 0.35rem;
	margin-bottom: 1.25rem;
}

.floating-panel__title {
	margin: 0;
	font-size: 1rem;
	font-weight: 600;
}

.floating-panel__subtitle {
	margin: 0;
	font-size: 0.85rem;
	opacity: 0.75;
}

.quick-commands {
	display: grid;
	gap: 0.75rem;
	margin: 0;
	padding: 0;
	list-style: none;
}

.quick-commands__item {
	display: flex;
	align-items: center;
	gap: 0.75rem;
	padding: 0.75rem 0.9rem;
	border-radius: 18px;
	backdrop-filter: blur(12px);
}

.floating-panel--light .quick-commands__item {
	background: rgba(37, 99, 235, 0.08);
}

.floating-panel--dark .quick-commands__item {
	background: rgba(255, 255, 255, 0.08);
}

.quick-commands__key {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	min-width: 2.5rem;
	height: 2.5rem;
	border-radius: 9999px;
	font-weight: 600;
	font-size: 0.85rem;
	letter-spacing: 0.05em;
	text-transform: uppercase;
	border: 1px solid transparent;
	box-shadow: 0 12px 28px rgba(15, 23, 42, 0.15);
}

.floating-panel--light .quick-commands__key {
	background: rgba(37, 99, 235, 0.16);
	color: rgba(37, 99, 235, 0.95);
}

.floating-panel--dark .quick-commands__key {
	background: rgba(37, 99, 235, 0.3);
	color: #dbeafe;
	border-color: rgba(148, 163, 184, 0.35);
}

.quick-commands__description {
	font-size: 0.9rem;
	line-height: 1.4;
	opacity: 0.9;
}

.floating-panel__footer {
	margin-top: 1.25rem;
	font-size: 0.8rem;
	opacity: 0.7;
}

.floating-panel--dark .floating-panel__footer {
	color: rgba(226, 232, 240, 0.85);
}

.selected-points__counter {
	margin: 0;
	font-size: 0.85rem;
	opacity: 0.75;
}

.selected-points__content {
	display: grid;
	gap: 0.85rem;
}

.selected-points__empty {
	margin: 0;
	font-size: 0.9rem;
	opacity: 0.8;
}

.selected-points__list {
	margin: 0;
	padding: 0;
	list-style: none;
	display: grid;
	gap: 0.75rem;
}

.selected-points__list li {
	width: 100%;
}

.intro-modal {
	position: relative;
	padding: 1px;
	border-radius: 32px;
	background: linear-gradient(135deg, rgba(37, 99, 235, 0.35), rgba(16, 185, 129, 0.4));
	box-shadow: 0 32px 60px rgba(15, 23, 42, 0.25);
}

.intro-modal__inner {
	position: relative;
	border-radius: 30px;
	padding: 2.75rem 2.5rem;
	overflow: hidden;
}

.intro-modal--light .intro-modal__inner {
	background: rgba(255, 255, 255, 0.98);
	color: #0f172a;
}

.intro-modal--dark .intro-modal__inner {
	background: rgba(11, 15, 25, 0.92);
	color: #f8fafc;
}

.intro-modal__glow {
	position: absolute;
	border-radius: 9999px;
	filter: blur(90px);
	opacity: 0.6;
}

.intro-modal__glow--primary {
	top: -120px;
	right: -80px;
	width: 260px;
	height: 260px;
	background: rgba(37, 99, 235, 0.8);
}

.intro-modal__glow--secondary {
	bottom: -100px;
	left: -60px;
	width: 220px;
	height: 220px;
	background: rgba(16, 185, 129, 0.75);
}

.intro-header {
	text-align: center;
	display: grid;
	gap: 0.75rem;
	margin-bottom: 1.5rem;
}

.intro-badge {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	margin: 0 auto;
	padding: 0.25rem 0.75rem;
	border-radius: 9999px;
	background: rgba(37, 99, 235, 0.16);
	color: rgba(37, 99, 235, 0.95);
	font-weight: 600;
	font-size: 0.75rem;
	letter-spacing: 0.08em;
	text-transform: uppercase;
}

.intro-modal--dark .intro-badge {
	background: rgba(37, 99, 235, 0.3);
	color: #dbeafe;
}

.intro-title {
	font-size: 2rem;
	line-height: 1.25;
	font-weight: 700;
}

.intro-subtitle {
	font-size: 1rem;
	max-width: 36rem;
	margin: 0 auto;
	opacity: 0.85;
}

.intro-highlights {
	display: grid;
	gap: 1rem;
	margin: 1.75rem 0;
}

.intro-highlight {
	display: flex;
	align-items: flex-start;
	gap: 1rem;
	padding: 1rem 1.25rem;
	border-radius: 20px;
	backdrop-filter: blur(12px);
}

.intro-modal--light .intro-highlight {
	background: rgba(37, 99, 235, 0.08);
}

.intro-modal--dark .intro-highlight {
	background: rgba(255, 255, 255, 0.08);
}

.intro-highlight__icon {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	width: 3rem;
	height: 3rem;
	border-radius: 9999px;
	background: rgba(255, 255, 255, 0.15);
	font-size: 1.5rem;
}

.intro-modal--light .intro-highlight__icon {
	background: rgba(37, 99, 235, 0.12);
}

.intro-highlight__title {
	font-size: 1rem;
	font-weight: 600;
	margin-bottom: 0.25rem;
}

.intro-highlight__description {
	font-size: 0.9rem;
	opacity: 0.85;
	margin: 0;
}

.intro-footer {
	display: grid;
	gap: 1.5rem;
	margin-top: 1.5rem;
}

.intro-note {
	text-align: center;
	font-size: 0.95rem;
	opacity: 0.85;
}

.intro-actions {
	display: flex;
	flex-direction: column;
	align-items: center;
	gap: 0.75rem;
}

@media (min-width: 768px) {
	.intro-actions {
		flex-direction: row;
		justify-content: center;
	}

	.intro-highlight {
		padding: 1.25rem 1.5rem;
	}
}
</style>
