<template>
  <aside
    class="sidebar"
    :class="{ 'sidebar--expanded': isExpanded }"
    aria-label="Main navigation"
  >
    <div class="sidebar__brand">
      <div class="brand-logo" aria-hidden="true">
        <span class="brand-logo__primary"></span>
        <span class="brand-logo__accent"></span>
      </div>

      <div v-if="isExpanded" class="brand-text">
        <span class="brand-text__title">FinSet</span>
      </div>

      <button
        type="button"
        class="sidebar__toggle"
        :aria-expanded="isExpanded"
        aria-label="Alternar largura da barra lateral"
        @click="toggleSidebar"
      >
        <span class="chevron"></span>
      </button>
    </div>

    <div class="sidebar__content">
      <nav class="sidebar__nav" aria-label="Primary">
        <ul>
          <li v-for="item in primaryItems" :key="item.id">
            <button
              type="button"
              class="nav-button"
              :data-active="item.id === activeItem"
              @click="setActive(item.id)"
            >
              <span class="nav-button__icon">
                <span class="icon" :class="`icon--${item.icon}`"></span>
              </span>
              <span v-if="isExpanded" class="nav-button__label">{{ item.label }}</span>
            </button>
          </li>
        </ul>
      </nav>

      <ul class="sidebar__secondary" aria-label="Secondary">
        <li v-for="item in secondaryItems" :key="item.id">
          <button
            type="button"
            class="nav-button nav-button--subtle"
            :data-active="item.id === activeItem"
            @click="setActive(item.id)"
          >
            <span class="nav-button__icon nav-button__icon--subtle">
              <span class="icon" :class="`icon--${item.icon}`"></span>
            </span>
            <span v-if="isExpanded" class="nav-button__label">{{ item.label }}</span>
          </button>
        </li>
      </ul>
    </div>

    <div class="sidebar__footer">
      <div class="theme-switch" role="group" aria-label="Alternar tema">
        <button
          type="button"
          class="theme-switch__button"
          :data-active="themeMode === 'day'"
          aria-label="Tema claro"
          @click="setTheme('day')"
        >
          <span class="icon icon--sun"></span>
        </button>
        <button
          type="button"
          class="theme-switch__button"
          :data-active="themeMode === 'night'"
          aria-label="Tema escuro"
          @click="setTheme('night')"
        >
          <span class="icon icon--moon"></span>
        </button>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { ref } from 'vue'

type NavItem = {
  id: string
  label: string
  icon: string
}

type ThemeMode = 'day' | 'night'

const isExpanded = ref(false)
const activeItem = ref('dashboard')
const themeMode = ref<ThemeMode>('day')

const primaryItems: NavItem[] = [
  { id: 'dashboard', label: 'Dashboard', icon: 'grid' },
  { id: 'transactions', label: 'Transactions', icon: 'transactions' },
  { id: 'wallet', label: 'Wallet', icon: 'wallet' },
  { id: 'goals', label: 'Goals', icon: 'goals' },
  { id: 'budget', label: 'Budget', icon: 'budget' },
  { id: 'analytics', label: 'Analytics', icon: 'analytics' },
  { id: 'settings', label: 'Settings', icon: 'settings' }
]

const secondaryItems: NavItem[] = [
  { id: 'help', label: 'Help', icon: 'help' },
  { id: 'logout', label: 'Log out', icon: 'logout' }
]

const toggleSidebar = () => {
  isExpanded.value = !isExpanded.value
}

const setActive = (id: string) => {
  activeItem.value = id
}

const setTheme = (mode: ThemeMode) => {
  themeMode.value = mode
}
</script>

<style scoped>
.sidebar {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 28px;
  width: 92px;
  min-height: calc(100vh - 64px);
  margin: 32px 0 32px 32px;
  padding: 28px 18px;
  border-radius: 48px;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.96) 0%, rgba(255, 255, 255, 0.82) 100%);
  box-shadow: 0 30px 60px rgba(88, 87, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.6);
  backdrop-filter: blur(22px);
  transition: width 0.35s ease, padding 0.35s ease, margin 0.35s ease, border-radius 0.35s ease;
}

.sidebar--expanded {
  width: 272px;
  padding: 32px 28px;
  border-radius: 40px;
}

.sidebar__brand {
  display: flex;
  align-items: center;
  gap: 18px;
}

.brand-logo {
  position: relative;
  display: grid;
  place-items: center;
  width: 52px;
  height: 52px;
  border-radius: 18px;
  background: linear-gradient(135deg, #1a2aad 0%, #845fff 55%, #f86af8 100%);
  box-shadow: inset 0 5px 10px rgba(255, 255, 255, 0.35), inset 0 -6px 12px rgba(26, 34, 148, 0.35);
}

.brand-logo__primary,
.brand-logo__accent {
  position: absolute;
  display: block;
  border-radius: 999px;
}

.brand-logo__primary {
  width: 26px;
  height: 26px;
  background: rgba(255, 255, 255, 0.82);
  top: 12px;
  left: 11px;
}

.brand-logo__accent {
  width: 30px;
  height: 30px;
  background: rgba(17, 23, 102, 0.85);
  bottom: 10px;
  right: 10px;
}

.brand-text {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.brand-text__title {
  font-size: 20px;
  font-weight: 600;
  color: #1f2147;
}

.sidebar__toggle {
  position: absolute;
  top: 36px;
  right: -16px;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  display: grid;
  place-items: center;
  background: #ffffff;
  box-shadow: 0 10px 25px rgba(99, 111, 255, 0.25);
  cursor: pointer;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.sidebar__toggle:hover {
  transform: translateX(2px);
  box-shadow: 0 14px 32px rgba(99, 111, 255, 0.3);
}

.sidebar--expanded .sidebar__toggle {
  right: -12px;
}

.chevron {
  position: relative;
  width: 10px;
  height: 10px;
  border-right: 2px solid #5a60ff;
  border-bottom: 2px solid #5a60ff;
  transform: rotate(45deg);
  transition: transform 0.35s ease;
}

.sidebar--expanded .chevron {
  transform: rotate(-135deg);
}

.sidebar__content {
  display: flex;
  flex-direction: column;
  flex: 1;
  gap: 32px;
}

.sidebar__nav ul,
.sidebar__secondary {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.sidebar__secondary {
  margin-top: auto;
  gap: 10px;
}

.nav-button {
  position: relative;
  display: flex;
  align-items: center;
  gap: 16px;
  width: 100%;
  padding: 10px 14px;
  border: none;
  border-radius: 18px;
  background: transparent;
  color: #1f2147;
  font-size: 15px;
  font-weight: 500;
  line-height: 1.2;
  cursor: pointer;
  transition: background 0.3s ease, color 0.3s ease, transform 0.3s ease;
}

.nav-button__icon {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 16px;
  background: rgba(104, 110, 255, 0.12);
  color: #585cff;
  transition: background 0.3s ease, color 0.3s ease, box-shadow 0.3s ease;
}

.nav-button[data-active='true'] {
  color: #ffffff;
  background: linear-gradient(135deg, #7f63ff 0%, #a28dff 100%);
  box-shadow: 0 18px 34px rgba(127, 99, 255, 0.35);
}

.nav-button[data-active='true'] .nav-button__icon {
  background: rgba(255, 255, 255, 0.2);
  color: #ffffff;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.3);
}

.nav-button:not([data-active='true']):hover .nav-button__icon {
  background: rgba(104, 110, 255, 0.2);
}

.nav-button:not([data-active='true']):hover {
  transform: translateX(4px);
}

.nav-button__label {
  white-space: nowrap;
}

.nav-button--subtle {
  font-weight: 500;
  color: rgba(31, 33, 71, 0.7);
  backdrop-filter: none;
}

.nav-button--subtle[data-active='true'] {
  background: rgba(103, 110, 255, 0.12);
  color: #4f54d9;
  box-shadow: none;
}

.nav-button__icon--subtle {
  background: rgba(103, 109, 255, 0.08);
  color: #4f54d9;
}

.nav-button--subtle[data-active='true'] .nav-button__icon--subtle {
  background: rgba(94, 100, 248, 0.18);
  color: #4f54d9;
  box-shadow: none;
}

.sidebar:not(.sidebar--expanded) .nav-button {
  justify-content: center;
  padding: 12px 0;
}

.sidebar:not(.sidebar--expanded) .nav-button__icon {
  width: 48px;
  height: 48px;
  background: transparent;
  color: #454b81;
}

.sidebar:not(.sidebar--expanded) .nav-button--subtle {
  background: transparent;
  color: rgba(31, 33, 71, 0.75);
}

.sidebar:not(.sidebar--expanded) .nav-button--subtle .nav-button__icon--subtle {
  background: transparent;
  color: #4a4f7a;
}

.sidebar:not(.sidebar--expanded) .nav-button[data-active='true'] {
  background: transparent;
  box-shadow: none;
  color: #5259ff;
}

.sidebar:not(.sidebar--expanded) .nav-button[data-active='true'] .nav-button__icon {
  background: linear-gradient(135deg, #7f63ff 0%, #a28dff 100%);
  color: #ffffff;
  box-shadow: 0 14px 26px rgba(127, 99, 255, 0.35);
}

.sidebar__footer {
  display: flex;
  justify-content: center;
}

.theme-switch {
  display: flex;
  gap: 6px;
  padding: 6px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.78);
  box-shadow: inset 0 0 0 1px rgba(164, 168, 255, 0.24);
}

.theme-switch__button {
  width: 44px;
  height: 44px;
  border-radius: 16px;
  border: none;
  display: grid;
  place-items: center;
  background: transparent;
  color: #676eff;
  cursor: pointer;
  transition: background 0.3s ease, color 0.3s ease, box-shadow 0.3s ease;
}

.theme-switch__button[data-active='true'] {
  background: linear-gradient(135deg, #7f63ff 0%, #a28dff 100%);
  color: #ffffff;
  box-shadow: 0 12px 24px rgba(127, 99, 255, 0.35);
}

/* Placeholder icon shapes */
.icon {
  position: relative;
  display: block;
  width: 22px;
  height: 22px;
  color: currentColor;
}

.icon::before,
.icon::after {
  content: '';
  position: absolute;
  display: block;
  background: currentColor;
}

.icon--grid::before {
  width: 7px;
  height: 7px;
  top: 0;
  left: 0;
  border-radius: 2px;
  box-shadow: 9px 0 0 0 currentColor, 0 9px 0 0 currentColor, 9px 9px 0 0 currentColor;
}

.icon--grid::after {
  display: none;
}

.icon--transactions::before {
  width: 18px;
  height: 22px;
  top: 0;
  left: 2px;
  border-radius: 8px;
  background: transparent;
  border: 2px solid currentColor;
}

.icon--transactions::after {
  width: 12px;
  height: 2px;
  top: 8px;
  left: 6px;
  border-radius: 999px;
  box-shadow: 0 6px 0 0 currentColor;
}

.icon--wallet::before {
  width: 18px;
  height: 12px;
  top: 4px;
  left: 2px;
  background: transparent;
  border: 2px solid currentColor;
  border-radius: 8px;
}

.icon--wallet::after {
  width: 6px;
  height: 6px;
  top: 7px;
  right: 1px;
  background: transparent;
  border: 2px solid currentColor;
  border-radius: 50%;
}

.icon--goals::before {
  width: 18px;
  height: 18px;
  top: 2px;
  left: 2px;
  border-radius: 50%;
  background: transparent;
  border: 2px solid currentColor;
}

.icon--goals::after {
  width: 8px;
  height: 8px;
  top: 7px;
  left: 7px;
  border-radius: 50%;
}

.icon--budget::before {
  width: 18px;
  height: 8px;
  bottom: 3px;
  left: 2px;
  border-radius: 999px;
  background: transparent;
  border: 2px solid currentColor;
}

.icon--budget::after {
  width: 18px;
  height: 8px;
  top: 1px;
  left: 2px;
  border-radius: 999px;
  background: transparent;
  border: 2px solid currentColor;
}

.icon--analytics::before {
  width: 4px;
  height: 8px;
  bottom: 2px;
  left: 1px;
  border-radius: 2px 2px 0 0;
  box-shadow: 6px -4px 0 0 currentColor, 12px -10px 0 0 currentColor;
}

.icon--analytics::after {
  width: 18px;
  height: 2px;
  bottom: 0;
  left: 2px;
  border-radius: 999px;
  opacity: 0.3;
}

.icon--settings::before {
  width: 18px;
  height: 18px;
  top: 2px;
  left: 2px;
  border-radius: 50%;
  background: transparent;
  border: 2px solid currentColor;
}

.icon--settings::after {
  width: 10px;
  height: 2px;
  top: 10px;
  left: 6px;
  border-radius: 999px;
  box-shadow: 0 -6px 0 0 currentColor, 0 6px 0 0 currentColor;
}

.icon--help::before {
  width: 20px;
  height: 20px;
  top: 1px;
  left: 1px;
  border-radius: 50%;
  background: transparent;
  border: 2px solid currentColor;
}

.icon--help::after {
  content: '?';
  position: absolute;
  top: 2px;
  left: 6px;
  font-size: 14px;
  font-weight: 600;
  color: currentColor;
  background: transparent;
}

.icon--logout::before {
  width: 12px;
  height: 16px;
  top: 3px;
  left: 3px;
  border-radius: 4px;
  background: transparent;
  border: 2px solid currentColor;
}

.icon--logout::after {
  width: 8px;
  height: 8px;
  top: 7px;
  right: -2px;
  background: transparent;
  border-top: 2px solid currentColor;
  border-right: 2px solid currentColor;
  transform: rotate(45deg);
}

.icon--sun::before {
  width: 12px;
  height: 12px;
  top: 5px;
  left: 5px;
  border-radius: 50%;
}

.icon--sun::after {
  width: 2px;
  height: 2px;
  top: -1px;
  left: 10px;
  border-radius: 1px;
  box-shadow:
    0 20px 0 currentColor,
    -10px 10px 0 currentColor,
    10px 10px 0 currentColor,
    -10px 0 0 currentColor,
    10px 0 0 currentColor,
    -10px 20px 0 currentColor,
    10px 20px 0 currentColor;
}

.icon--moon::before {
  width: 14px;
  height: 14px;
  top: 4px;
  left: 5px;
  border-radius: 50%;
  background: transparent;
  box-shadow: inset 0 0 0 999px currentColor;
}

.icon--moon::after {
  width: 10px;
  height: 10px;
  top: 4px;
  left: 7px;
  border-radius: 50%;
  background: #fff;
}

.sidebar:not(.sidebar--expanded) .brand-text {
  display: none;
}
</style>
