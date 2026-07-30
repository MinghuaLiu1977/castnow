import { ref, reactive } from 'vue'

const messages = reactive({
  zh: {},
})

const messagesLoaded = ref(false)

async function loadMessages() {
  if (messagesLoaded.value) return
  try {
    const zh = await fetch('/locales/zh.json').then(r => r.json())
    Object.assign(messages.zh, zh)
    messagesLoaded.value = true
  } catch (err) {
    console.error('Failed to load locale files:', err)
    messagesLoaded.value = true
  }
}

const locale = ref('zh')

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

  return { t, locale, loadMessages }
}
