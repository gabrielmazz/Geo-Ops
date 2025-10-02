<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { helloApi, requestRoute, type RouteResponse } from './services/api'

// Importação dos componentes locais
import MapView from './components/MapView.vue'

type GeoPoint = [number, number]

const message = ref('')
const error = ref<string | null>(null)
const loading = ref(true)
const selectedPoints = ref<GeoPoint[]>([])
const routeResult = ref<RouteResponse | null>(null)
const routeError = ref<string | null>(null)
const routeLoading = ref(false)
const routeCoordinates = computed(() => routeResult.value?.coordinates ?? [])

// Estado do drawer de ações -> Drawer para ver os pontos que foram selecionados
const isActionsDrawerOpen = ref(false)

const handlePointsUpdate = (points: GeoPoint[]) => {
	selectedPoints.value = points
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
		routeResult.value = await requestRoute(points)
	} catch (err) {
		routeResult.value = null
		routeError.value = err instanceof Error ? err.message : String(err)
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
						enviados ao backend Java para executar o Dijkstra e retornar o melhor caminho.
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
							<ol v-else class="mt-3 space-y-1.5 text-sm text-slate-700 list-inside list-decimal">
								<li v-for="(point, index) in selectedPoints" :key="index">
									Posição {{ index + 1 }}: {{ point[0].toFixed(6) }}, {{ point[1].toFixed(6) }}
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
	<n-drawer
		v-model:show="isActionsDrawerOpen"
		:width="502"
		placement="right"
	>
		<n-drawer-content title="Ações disponíveis">
			<p class="text-sm text-slate-600">
				Configura aqui as opções extras do mapa. Adicione conteúdo conforme necessário.
			</p>
		</n-drawer-content>
	</n-drawer>

</template>
