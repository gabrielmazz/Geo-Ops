const API_BASE_URL = (import.meta.env.VITE_API_URL ?? '').replace(/\/$/, '')

// Realiza a chamada da função Hello from Spring
export async function helloApi(): Promise<string> {
  const response = await fetch(`${API_BASE_URL}/api/hello`, {
    headers: {
      Accept: 'application/json',
    },
  })

  if (!response.ok) {
    throw new Error(`Falha ao carregar: ${response.status} ${response.statusText}`)
  }

  const data: { message?: string } = await response.json()
  return data.message ?? 'Hello from Spring!'
}
