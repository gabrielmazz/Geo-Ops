<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { helloApi, requestRoute, type RouteResponse } from './services/api'

// Importação dos componentes locais
import Alert from './components/Alert.vue'
import MapView from './components/MapView.vue'

type GeoPoint = [number, number]

const message = ref('')
const error = ref<string | null>(null)
const loading = ref(true)
const selectedPoints = ref<GeoPoint[]>([])
const routeResult = ref<RouteResponse | null>(null)
const routeError = ref<string | null>(null)
const routeLoading = ref(false)

type AlertType = 'default' | 'info' | 'success' | 'warning' | 'error'
type RouteNotification = {
	title?: string
	message: string
	type: AlertType
}

const routeNotification = ref<RouteNotification | null>(null)
let notificationTimer: ReturnType<typeof setTimeout> | null = null

const clearRouteNotification = () => {
	if (notificationTimer) {
		window.clearTimeout(notificationTimer)
		notificationTimer = null
	}
	routeNotification.value = null
}

const showRouteNotification = (notification: RouteNotification) => {
	clearRouteNotification()
	routeNotification.value = notification
	notificationTimer = window.setTimeout(() => {
		routeNotification.value = null
		notificationTimer = null
	}, 4000)
}

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

const getTimelineDot = (item: TimelineItem) => {
	if (item.role === 'origin') {
		return '🟢'
	}
	if (item.role === 'destination') {
		return '🔴'
	}
	return '🔵'
}

// Estado do drawer de ações -> Drawer para ver os pontos que foram selecionados
const isActionsDrawerOpen = ref(false)

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

const fetchRoute = async (points: GeoPoint[]) => {
	if (points.length < 2) {
		routeResult.value = null
		routeError.value = null
		routeLoading.value = false
		clearRouteNotification()
		return
	}

	routeLoading.value = true
	routeError.value = null

	try {
		const result = await requestRoute(points)
		routeResult.value = result
		routeError.value = null
		if (result) {
			showRouteNotification({
				title: 'Rota calculada',
				message: 'A rota foi calculada com sucesso.',
				type: 'success',
			})
		}
	} catch (err) {
		routeResult.value = null
		const errorMessage = err instanceof Error ? err.message : String(err)
		routeError.value = errorMessage
		showRouteNotification({
			title: 'Erro ao calcular a rota',
			message: errorMessage,
			type: 'error',
		})
	} finally {
		routeLoading.value = false
	}
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

onUnmounted(() => {
	clearRouteNotification()
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
		<div
			v-if="routeNotification"
			class="fixed top-6 right-6 z-[1200] w-full max-w-sm pointer-events-none">
			<div class="pointer-events-auto">
				<Alert
					:key="`${routeNotification.type}-${routeNotification.message}`"
					:title="routeNotification.title"
					:message="routeNotification.message"
					:type="routeNotification.type"
					:closable="true"
					:show-icon="true"
					@close="clearRouteNotification"
				/>
			</div>
		</div>
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
					<MapView :max-points="2" :route-coordinates="routeCoordinates"
						@update:points="handlePointsUpdate" />

					<div class="pointer-events-none absolute left-6 bottom-6 z-[1000] max-w-xs">
						<div
							class="pointer-events-auto rounded-2xl bg-white/90 backdrop-blur px-5 py-4 shadow-lg border border-white/60">
							<h2 class="text-base font-semibold text-slate-800">Pontos selecionados</h2>
							<div v-if="!selectedPoints.length" class="mt-2 text-sm text-slate-600">
								Nenhum ponto selecionado.
							</div>
							<ol v-else class="mt-3 space-y-1.5">
								<li
									v-for="item in selectedPointsDisplay"
									:key="item.key"
									:class="item.classes">
									<div class="font-medium">{{ item.label }}</div>
									<div class="mt-0.5 text-xs text-slate-600">
										{{ item.coords[0].toFixed(6) }}, {{ item.coords[1].toFixed(6) }}
									</div>
								</li>
							</ol>
						</div>
					</div>
				</div>

				<!-- <div class="rounded-2xl bg-slate-900/5 p-5">
          <h2 class="text-lg font-medium text-slate-800">Resultado da rota</h2>
          <div v-if="routeLoading" class="mt-3 text-slate-600">Calculando rota...</div>
          <div v-else-if="routeError" class="mt-3 text-red-600">
            {{ routeError }}
          </div>
          <div v-else-if="routeResult" class="mt-3 space-y-3 text-slate-700">
            <p>
              Ordem dos nós: <span class="font-medium">{{ routeResult.nodes.join(' → ') }}</span>
            </p>
            <p>Total aproximado: {{ routeResult.totalCost.toFixed(1) }} km</p>
            <ul class="space-y-1 text-sm">
              <li
                v-for="(coordinate, index) in routeResult.coordinates"
                :key="coordinate.lat + coordinate.lon + '-' + index"
              >
                {{ routeResult.nodes[index] ?? `Ponto ${index + 1}` }}:
                {{ coordinate.lat.toFixed(4) }}, {{ coordinate.lon.toFixed(4) }}
              </li>
            </ul>
          </div>
          <div v-else class="mt-3 text-slate-600">Selecione dois pontos para calcular a rota.</div>
        </div>  -->
				<!-- Div responsavel pelos botões e ações que serão possiveis executar no sistema -->
				<div>
					<n-button @click="isActionsDrawerOpen = true">
						Abrir ações
					</n-button>
				</div>
			</div>
		</main>
	</div>


	<!-- Drawer que mostrara todos os pontos selecionados -->
	<!-- A ideia é que ele usa o componente do Native para montar uma timeline
	  	com os pontos selecionados, marcando o ponto de origem, destino e os pontos
	  	intermediários -->
	<n-drawer v-model:show="isActionsDrawerOpen" :width="502" placement="right">

		<n-drawer-content title="Ações disponíveis">
			<section class="space-y-3">
				<h2 class="text-lg font-medium text-slate-800">Timeline da rota</h2>
					<div v-if="routeLoading" class="text-slate-600">Calculando rota...</div>
					<Alert
						v-else-if="routeError"
						title="Erro ao calcular a rota"
						type="error"
						:closable="true"
						:show-icon="true"
						:message="routeError ?? 'Ocorreu um erro desconhecido ao calcular a rota.'"
						@close="routeError = null"
					/>
					<n-timeline v-else-if="routeTimelineItems.length">
						<n-timeline-item
							v-for="item in routeTimelineItems"
							:key="item.key"
							:title="item.label"
							:dot="getTimelineDot(item)">
							<div :class="item.badgeClasses">
								<div class="font-medium">{{ item.label }}</div>
								<div class="mt-0.5 text-xs opacity-80">
									{{ item.coordinate.lat.toFixed(6) }}, {{ item.coordinate.lon.toFixed(6) }}
								</div>
							</div>
						</n-timeline-item>
					</n-timeline>
				<div v-else class="text-slate-600">Selecione dois pontos para visualizar a rota.</div>
			</section>
		</n-drawer-content>
	</n-drawer>

</template>
