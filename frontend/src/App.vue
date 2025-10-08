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
		origin: 'point-pill point-pill--origin',
		destination: 'point-pill point-pill--destination',
		waypoint: 'point-pill point-pill--waypoint',
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
	themeStore.initialize()
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
	<n-config-provider :theme="isDark ? darkTheme : null" :theme-overrides="themeOverrides">
		<div class="min-h-screen flex app-shell">

			<main class="flex-1 flex flex-col p-8">
				<div
					class="flex-1 w-full rounded-3xl surface-card backdrop-blur px-10 py-12 space-y-6 flex flex-col">
					<div class="space-y-2 text-primary">
						<h1 class="text-2xl font-semibold">Selecione os pontos</h1>
						<p class="text-secondary">
							Clique no mapa para definir até duas posições (origem e destino). Esses valores serão
							enviados ao backend Java que consulta o OSRM para retornar o melhor caminho disponível.
						</p>
					</div>

					<div class="relative flex-1 min-h-[60vh]">
						<MapView :max-points="2" :route-coordinates="routeCoordinates" :route-color="routeColor"
							:is-dark-mode="isDark" @update:points="handlePointsUpdate" />

						<div class="pointer-events-none absolute left-6 bottom-6 z-[1000] max-w-xs">
							<div class="pointer-events-auto rounded-2xl surface-card-muted overlay-card px-5 py-4">
								<h2 class="text-base font-semibold text-primary">Pontos selecionados</h2>
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
				<h2 class="text-lg font-medium text-primary">Timeline da rota</h2>

				<div v-if="routeLoading" class="text-secondary">Calculando rota...</div>

				<Alert v-else-if="routeError" title="Erro ao calcular a rota" type="error" :show-icon="true"
					:closable="true" :message="routeError || 'Ocorreu um erro desconhecido ao calcular a rota.'"
					@close="dismissRouteError" />

				<RouteTimeline v-else-if="routeTimelineItems.length" :items="routeTimelineItems" />

				<div v-else class="text-secondary">Selecione dois pontos para visualizar a rota.</div>
			</section>

		</Drawer>

		<!-- Drawer que mostrara as personalizações do mapa -->
		<Drawer title="Personalizações do mapa" v-model:show="isCustomizationsDrawerOpen">
			<section class="space-y-3">

				<n-h2 class="text-primary">Configurações gerais</n-h2>

				<n-grid
					x-gap="4" :cols="2"
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
					Altere a cor dos pontos (origem, destino e intermediários) que aparecem no mapa. A cor padrão é
				</n-p>

				<ColorPicker v-model="routeColor" label="Cor dos pontos" :expected-color="DEFAULT_ROUTE_COLOR" @invalid="(msg) =>
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
			<Alert v-for="alert in alerts" :key="alert.id" :title="alert.title" :type="alert.type"
				:message="alert.message" :show-icon="true" :closable="true" @close="removeAlert(alert.id)" />
		</div>

	</n-config-provider>
</template>
