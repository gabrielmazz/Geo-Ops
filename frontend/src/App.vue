<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
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

const handleMaxPointsChange = () => {
	selectedPoints.value = []
	resetRouteState()
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
						<MapView :max-points="normalizedMaxSelectablePoints" :route-coordinates="routeCoordinates" :route-color="routeColor"
							:point-color="pointColor" :is-dark-mode="isDark" :enable-point-editing="isPointEditingEnabled" @update:points="handlePointsUpdate"
							@point-moved="handlePointMoved" />

						<div class="pointer-events-none absolute left-6 bottom-6 z-[1000] max-w-xs">
							<div class="pointer-events-auto rounded-2xl surface-card-muted overlay-card px-5 py-4">
								<h2 class="text-base font-semibold text-primary">Pontos selecionados</h2>
								<p class="mt-1 text-xs text-secondary">
									{{ selectedPoints.length }} / {{ normalizedMaxSelectablePoints }}
									{{ selectedPoints.length === 1 ? 'ponto selecionado' : 'pontos selecionados' }}
								</p>
								<div v-if="!selectedPoints.length" class="mt-2 text-sm text-secondary">
									Nenhum ponto selecionado.
								</div>
								<ol v-else class="mt-3 space-y-1.5">
									<li v-for="item in selectedPointsDisplay" :key="item.key" :class="item.classes">
										<div class="font-medium">{{ item.label }}</div>
										<div class="point-pill__coords">
											{{ item.coords[0].toFixed(6) }}, {{ item.coords[1].toFixed(6) }}
										</div>
									</li>
								</ol>
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
</style>
