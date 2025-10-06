<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { helloApi, requestRoute, type RouteResponse } from './services/api'

// Importação dos componentes locais
import MapView from './components/MapView.vue'

// Importação dos componentes montados
import Alert from './components/Alert.vue'
import Button from './components/Button.vue'
import RouteTimeline from './components/RouteTimeline.vue'
import Drawer from './components/Drawer.vue'
import ColorPicker from './components/ColorPicker.vue'

type GeoPoint = [number, number]

const message = ref('')
const error = ref<string | null>(null)
const loading = ref(true)
const selectedPoints = ref<GeoPoint[]>([])
const routeResult = ref<RouteResponse | null>(null)
const routeError = ref<string | null>(null)
const routeLoading = ref(false)
const DEFAULT_ROUTE_COLOR = '#ff0000'
const routeColor = ref<string>(DEFAULT_ROUTE_COLOR)

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
		origin: 'border-emerald-200 bg-emerald-50 text-emerald-700',
		destination: 'border-rose-200 bg-rose-50 text-rose-700',
		waypoint: 'border-slate-200 bg-slate-50 text-slate-700',
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
			badgeClasses: `rounded-lg border px-3 py-2 text-sm ${roleClasses[role]}`,
		}
	})

	const originItem = items[0]
	const destinationItem = items.length > 1 ? items[items.length - 1] : null
	const waypointItems = items.slice(1, items.length - (destinationItem ? 1 : 0))

	return destinationItem
		? [originItem, ...waypointItems, destinationItem]
		: [originItem, ...waypointItems]
})

// Estado do drawer de ações -> Drawer para ver os pontos que foram selecionados
const isActionsDrawerOpen = ref(false)

// Estado do drawer de personalizações -> Drawer para ver as personalizações do mapa
const isCustomizationsDrawerOpen = ref(false)

const handlePointsUpdate = (points: GeoPoint[]) => {
	selectedPoints.value = points
}

const selectedPointsDisplay = computed<SelectedPointDisplay[]>(() => {
	const points = selectedPoints.value
	if (!points.length) {
		return []
	}

	const lastIndex = points.length - 1
	let waypointCount = 0

	const roleClasses: Record<SelectedPointDisplay['role'], string> = {
		origin: 'border-emerald-200 bg-emerald-50 text-emerald-700',
		destination: 'border-rose-200 bg-rose-50 text-rose-700',
		waypoint: 'border-slate-200 bg-slate-50 text-slate-700',
	}

	return points
		.map<SelectedPointDisplay>((point, index) => {
			const role: SelectedPointDisplay['role'] =
				index === 0 ? 'origin' : index === lastIndex ? 'destination' : 'waypoint'

			let label: string
			if (role === 'origin') {
				label = 'Origem'
			} else if (role === 'destination') {
				label = 'Destino'
			} else {
				waypointCount += 1
				label = `Ponto ${waypointCount}`
			}

			return {
				key: `${point[0]}-${point[1]}-${index}`,
				coords: point,
				label,
				role,
				classes: `rounded-lg border px-3 py-2 text-sm ${roleClasses[role]}`,
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
		routeResult.value = null
		routeError.value = null
		routeLoading.value = false
		return
	}

	routeLoading.value = true
	routeError.value = null

	try {
		const result = await requestRoute(points)
		routeResult.value = result

		const pointCount = points.length
		const pointsDescription =
			pointCount === 2 ? 'origem e destino' : `${pointCount} pontos`
		pushAlert({
			title: 'Rota calculada',
			type: 'success',
			message: `A rota com ${pointsDescription} foi gerada com sucesso.`,
		})
	} catch (err) {
		routeResult.value = null
		routeError.value = err instanceof Error ? err.message : String(err)

		const message =
			routeError.value ||
			'Ocorreu um erro desconhecido ao calcular a rota. Verifique a conexão com o backend.'
		pushAlert({
			title: 'Erro ao calcular a rota',
			type: 'error',
			message,
		})
	} finally {
		routeLoading.value = false
	}
}

const dismissRouteError = () => {
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
	void loadGreeting()
})

watch(
	selectedPoints,
	(points) => {
		void fetchRoute(points)
	},
	{ deep: true },
)
</script>

<template>
	<div class="min-h-screen flex bg-slate-900/5">

		<main class="flex-1 flex flex-col p-8">
			<div
				class="flex-1 w-full rounded-3xl bg-white/80 backdrop-blur shadow-xl px-10 py-12 space-y-6 flex flex-col">
				<div class="space-y-2 text-slate-900">
					<h1 class="text-2xl font-semibold">Selecione os pontos</h1>
					<p class="text-slate-600">
						Clique no mapa para definir até duas posições (origem e destino). Esses valores serão
						enviados ao backend Java que consulta o OSRM para retornar o melhor caminho disponível.
					</p>
				</div>

				<div class="relative flex-1 min-h-[60vh]">
					<MapView :max-points="2" :route-coordinates="routeCoordinates" :route-color="routeColor"
						@update:points="handlePointsUpdate" />

					<div class="pointer-events-none absolute left-6 bottom-6 z-[1000] max-w-xs">
						<div
							class="pointer-events-auto rounded-2xl bg-white/90 backdrop-blur px-5 py-4 shadow-lg border border-white/60">
							<h2 class="text-base font-semibold text-slate-800">Pontos selecionados</h2>
							<div v-if="!selectedPoints.length" class="mt-2 text-sm text-slate-600">
								Nenhum ponto selecionado.
							</div>
							<ol v-else class="mt-3 space-y-1.5">
								<li v-for="item in selectedPointsDisplay" :key="item.key" :class="item.classes">
									<div class="font-medium">{{ item.label }}</div>
									<div class="mt-0.5 text-xs text-slate-600">
										{{ item.coords[0].toFixed(6) }}, {{ item.coords[1].toFixed(6) }}
									</div>
								</li>
							</ol>
						</div>
					</div>
				</div>

				<!-- Div responsavel pelos botões e ações que serão possiveis executar no sistema -->
				<n-flex justify="center">

					<!-- Botão responsável por abrir o drawer dos pontos, mostrando uma timeline -->
					<Button @click="isActionsDrawerOpen = true" :label="'Abrir timeline'"
						class="metamorphous-regular" />

					<!-- Botão responsável por abrir o drawer de personalizações -->
					<Button @click="isCustomizationsDrawerOpen = true" :label="'Abrir personalizações'"
						class="metamorphous-regular" />

				</n-flex>
			</div>
		</main>
	</div>


	<!-- Drawer que mostrara todos os pontos selecionados -->
	<!-- A ideia é que ele usa o componente do Native para montar uma timeline
	  	com os pontos selecionados, marcando o ponto de origem, destino e os pontos
	  	intermediários -->
	<Drawer title="Ações disponíveis" v-model:show="isActionsDrawerOpen">
		<section class="space-y-3">
			<h2 class="text-lg font-medium text-slate-800">Timeline da rota</h2>

			<div v-if="routeLoading" class="text-slate-600">Calculando rota...</div>

			<Alert v-else-if="routeError" title="Erro ao calcular a rota" type="error" :show-icon="true"
				:closable="true" :message="routeError || 'Ocorreu um erro desconhecido ao calcular a rota.'"
				@close="dismissRouteError" />

			<RouteTimeline v-else-if="routeTimelineItems.length" :items="routeTimelineItems" />

			<div v-else class="text-slate-600">Selecione dois pontos para visualizar a rota.</div>
		</section>

	</Drawer>

	<!-- Drawer que mostrara as personalizações do mapa -->
	<Drawer title="Personalizações do mapa" v-model:show="isCustomizationsDrawerOpen">
		<section class="space-y-3">

			<n-h2>Personalização da cor da rota</n-h2>

			<ColorPicker v-model="routeColor" label="Cor da rota" :expected-color="DEFAULT_ROUTE_COLOR" @invalid="(msg) =>
				pushAlert({
					title: 'Cor inválida',
					type: 'warning',
					message: msg,
				})
			" />
		</section>
	</Drawer>


	<!-- Div que ira conter todos os alertas do sistema -->
	<div class="fixed top-6 right-6 z-[1200] flex w-80 flex-col gap-3">
		<Alert v-for="alert in alerts" :key="alert.id" :title="alert.title" :type="alert.type" :message="alert.message"
			:show-icon="true" :closable="true" @close="removeAlert(alert.id)" />
	</div>

</template>
