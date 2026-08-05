import { ref, reactive } from 'vue'

const messages = reactive({
  en: {},
  zh: {},
})

const messagesLoaded = ref(false)

async function loadMessages() {
  if (messagesLoaded.value) return
  try {
    const [en, zh] = await Promise.all([
      fetch('/locales/en.json').then(r => r.json()),
      fetch('/locales/zh.json').then(r => r.json()),
    ])
    Object.assign(messages.en, en)
    Object.assign(messages.zh, zh)
    messagesLoaded.value = true
  } catch (err) {
    console.error('Failed to load locale files:', err)
    messagesLoaded.value = true
  }
}

function getDefaultLocale() {
  const host = window.location.hostname
  if (host === 'castnow.padap.cn') return 'zh'
  const lang = (navigator.language || 'en').toLowerCase()
  if (lang.startsWith('zh')) return 'zh'
  return 'en'
}

const locale = ref(getDefaultLocale())

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

  return { t, locale, loadMessages, messagesLoaded }
}
