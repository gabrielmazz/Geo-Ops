import { ref } from 'vue'
import { defineStore } from 'pinia'

const STORAGE_KEY = 'geo-ops:theme-preference'

const withDocument = <T>(fn: (root: HTMLElement) => T) => {
	if (typeof document === 'undefined') return
	const root = document.documentElement
	return fn(root)
}

const withWindow = <T>(fn: (win: Window) => T) => {
	if (typeof window === 'undefined') return
	return fn(window)
}

const applyThemeClass = (isDark: boolean) => {
	withDocument((root) => {
		root.classList.toggle('dark', isDark)
		root.dataset.theme = isDark ? 'dark' : 'light'
		root.style.colorScheme = isDark ? 'dark' : 'light'
	})
}

const persistPreference = (isDark: boolean) => {
	withWindow((win) => {
		win.localStorage.setItem(STORAGE_KEY, isDark ? 'dark' : 'light')
	})
}

const readStoredPreference = () =>
	withWindow((win) => {
		const value = win.localStorage.getItem(STORAGE_KEY)
		return value === 'dark' ? true : value === 'light' ? false : null
	}) ?? null

export const useThemeStore = defineStore('theme', () => {
	const isDark = ref(false)
	const initialized = ref(false)

	const setTheme = (value: boolean) => {
		isDark.value = value
		applyThemeClass(value)
		persistPreference(value)
	}

	const toggleTheme = () => {
		setTheme(!isDark.value)
	}

	const initialize = () => {
		const storedPreference = readStoredPreference()
		const nextValue = storedPreference ?? false

		if (typeof window === 'undefined' || typeof document === 'undefined') {
			isDark.value = nextValue
			return
		}

		if (initialized.value) {
			setTheme(nextValue)
			return
		}

		initialized.value = true
		setTheme(nextValue)
	}

	return {
		isDark,
		initialize,
		setTheme,
		toggleTheme,
	}
})
