<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref } from 'vue'
import L, { Map as LMap } from 'leaflet'
import 'leaflet/dist/leaflet.css'

const mapEl = ref<HTMLDivElement | null>(null)
let map: LMap | null = null

onMounted(() => {
  // cria o mapa (lat, lng, zoom) — centro no Brasil como exemplo
  map = L.map(mapEl.value as HTMLDivElement, {
    zoomControl: true,
    attributionControl: true,
  }).setView([-15.78, -47.93], 4)

  // camada de tiles do OpenStreetMap (grátis)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map)

  // exemplo: marcador em Brasília
  L.marker([-15.793889, -47.882778]).addTo(map).bindPopup('Brasília')
})

onBeforeUnmount(() => {
  map?.remove()
  map = null
})
</script>

<template>
  <!-- o mapa PRECISA de altura -->
  <div ref="mapEl" class="map-container"></div>
</template>

<style scoped>
.map-container {
  width: 100%;
  height: 80vh; /* ajuste como preferir */
  border-radius: 12px;
  overflow: hidden;
}
</style>
