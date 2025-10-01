<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { helloApi } from './services/api'

// Importação dos componentes locais
import MapView from './components/MapView.vue'
import Sidebar from './components/Sidebar.vue'

const message = ref('')
const error = ref<string | null>(null)
const loading = ref(true)

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
</script>

<template>
  <div class="min-h-screen flex bg-slate-900/5">
    <Sidebar />

    <main class="flex-1 flex items-center justify-center p-8">
      <div class="rounded-3xl bg-white/80 backdrop-blur shadow-xl px-12 py-14 text-center space-y-3">
        <p class="text-sm uppercase tracking-[0.35em] text-indigo-400">Tailwind Test</p>
        <h1 class="text-4xl font-semibold text-slate-900">Hello Tailwind</h1>
        <p class="text-slate-500 max-w-md">
          Se você está vendo esta mensagem estilizada, as classes do Tailwind estão carregadas com sucesso.
        </p>
      </div>
    </main>
  </div>
</template>
