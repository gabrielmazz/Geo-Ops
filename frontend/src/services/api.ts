const API_BASE_URL = (import.meta.env.VITE_API_URL ?? '').replace(/\/$/, '')

export type RoutePoint = [number, number]

export type RouteResponse = {
	nodes: string[]
	coordinates: Array<{ lat: number; lon: number }>
	totalCost: number
}

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

export async function requestRoute(points: RoutePoint[]): Promise<RouteResponse> {
	const response = await fetch(`${API_BASE_URL}/api/routes`, {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			Accept: 'application/json',
		},
		body: JSON.stringify({ points }),
	})

	if (!response.ok) {
		throw new Error(`Falha ao calcular rota: ${response.status} ${response.statusText}`)
	}

	return (await response.json()) as RouteResponse
}
