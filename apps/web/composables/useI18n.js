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

export function getDefaultLocale(host, navLang) {
  if (typeof window !== 'undefined' && !host) {
    host = window.location.hostname;
  }
  if (typeof navigator !== 'undefined' && !navLang) {
    navLang = navigator.language;
  }
  if (host) {
    if (host === 'castnow.padap.cn') return 'zh';
    if (host.endsWith('vercel.app') || host.includes('vercel.app')) return 'en';
  }
  const lang = (navLang || 'en').toLowerCase();
  if (lang.startsWith('zh')) return 'zh';
  return 'en';
}

const locale = ref(getDefaultLocale())

const appStoreUrl = ref('https://apps.apple.com/us/app/screen-share-castnow/id6761016081')
const appIcon = ref('/icon.svg')

if (typeof window !== 'undefined') {
  const host = window.location.hostname
  if (host.includes('castnow.padap.cn')) {
    appStoreUrl.value = 'https://apps.apple.com/us/app/castnow-%E5%8D%B3%E5%88%BB%E6%8A%95%E5%B1%8F/id6795734574'
    appIcon.value = '/icon_standard.png'
  }
}

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

  return { t, locale, loadMessages, messagesLoaded, appStoreUrl, appIcon }
}
