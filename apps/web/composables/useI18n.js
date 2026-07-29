import { ref, computed } from 'vue'

const LOCALE_KEY = 'castnow_locale'

const messages = {
  en: null,
  zh: null,
}

let loadPromise = null
async function loadMessages() {
  if (loadPromise) return loadPromise
  loadPromise = Promise.all([
    fetch('/locales/en.json').then(r => r.json()).then(m => messages.en = m),
    fetch('/locales/zh.json').then(r => r.json()).then(m => messages.zh = m),
  ]).catch(err => {
    console.error('Failed to load locale files:', err)
    messages.en = {}
    messages.zh = {}
  })
  return loadPromise
}

function getBrowserLocale() {
  const lang = (navigator.language || 'en').toLowerCase()
  if (lang.startsWith('zh')) return 'zh'
  return 'en'
}

function getSavedLocale() {
  try {
    const saved = localStorage.getItem(LOCALE_KEY)
    if (saved === 'zh' || saved === 'en') return saved
  } catch (_) {}
  return null
}

const locale = ref(getSavedLocale() || getBrowserLocale())

export function useI18n() {
  const t = (key, params) => {
    const msg = messages[locale.value]
    if (!msg) return key
    const keys = key.split('.')
    let value = msg
    for (const k of keys) {
      if (value == null) return key
      value = value[k]
    }
    if (typeof value !== 'string') return key
    if (params) {
      return value.replace(/\{(\w+)\}/g, (_, p) => params[p] ?? `{${p}}`)
    }
    return value
  }

  const setLocale = (l) => {
    locale.value = l
    document.documentElement.lang = l === 'zh' ? 'zh-CN' : 'en'
    try { localStorage.setItem(LOCALE_KEY, l) } catch (_) {}
  }

  const availableLocales = [
    { code: 'zh', label: '中文' },
    { code: 'en', label: 'English' },
  ]

  return { t, locale, setLocale, availableLocales, loadMessages }
}
