<template>
  <div class="flex-1 flex flex-col items-center justify-center p-6 text-center">
    <div class="mb-4 px-4 py-1 bg-cyan-500/10 border border-cyan-500/20 rounded-full flex items-center gap-2 backdrop-blur-sm">
      <Globe class="w-3 h-3 text-cyan-400" />
      <span class="text-[10px] font-black uppercase text-cyan-400 tracking-widest">{{ t('app.tagline') }}</span>
    </div>
    <h1 class="text-6xl md:text-8xl font-black mb-6 tracking-tighter leading-none">
      {{ t('landing.instant') }} <span class="text-cyan-400">{{ t('landing.casting') }}</span>
    </h1>
    <p class="text-slate-500 max-w-xs mb-10 text-sm font-medium italic">{{ t('landing.heroDesc') }}</p>

    <div class="flex flex-col gap-4 w-full max-w-xs">
      <button @click="$emit('navigate', 'SOURCE_SELECT')"
        class="group relative py-6 bg-cyan-500 text-slate-950 rounded-3xl font-black text-xl uppercase shadow-xl shadow-cyan-500/20 active:scale-95 transition-all overflow-hidden">
        <span class="relative z-10">{{ t('landing.broadcast') }}</span>
        <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform"></div>
      </button>
      <button @click="$emit('navigate', 'RECEIVER_INPUT')"
        class="py-6 backdrop-blur-xl bg-white/5 border border-white/10 rounded-3xl font-black text-xl uppercase active:scale-95 transition-all flex items-center justify-center gap-3 hover:border-cyan-500/50 hover:bg-white/10">
        <Download class="w-6 h-6" />{{ t('landing.receive') }}
      </button>
      <div class="flex justify-center w-full">
        <a href="https://apps.apple.com/us/app/castnow-pro/id6761016081" target="_blank"
          class="w-full max-w-[200px] h-11 bg-black border border-slate-800 rounded-xl hover:border-cyan-500 transition-all flex items-center justify-center px-4 gap-3 group active:scale-95">
          <Apple class="w-6 h-6 text-white group-hover:scale-110 transition-transform" />
          <div class="flex flex-col items-start leading-none">
            <span class="text-[8px] font-bold text-slate-400 uppercase tracking-tighter">{{ t('landing.downloadOn') }}</span>
            <span class="text-xs font-black text-white uppercase tracking-tight">{{ t('landing.appStore') }}</span>
          </div>
        </a>
      </div>
    </div>

    <div class="mt-16 flex flex-col items-center gap-6">
      <div class="flex items-center justify-center flex-wrap gap-4 md:gap-8 text-slate-600 font-bold text-[10px] uppercase tracking-[0.2em]">
        <a href="/privacy.html" target="_blank" class="hover:text-cyan-400 transition-colors">{{ t('landing.privacy') }}</a>
        <a href="/terms.html" target="_blank" class="hover:text-cyan-400 transition-colors">{{ t('landing.terms') }}</a>
        <button @click="$emit('showInfo', 'support')" class="hover:text-cyan-400 transition-colors">{{ t('landing.support') }}</button>
        <a href="/blog/index.html" class="hover:text-cyan-400 transition-colors">{{ t('landing.blog') }}</a>
      </div>
      <div class="text-[9px] font-black text-slate-800 uppercase tracking-[0.2em] flex items-center gap-2">
        <span class="w-4 h-px bg-slate-800"></span>{{ t('landing.madeBy') }}<span class="w-4 h-px bg-slate-800"></span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { Globe, Download, Apple } from 'lucide-vue-next';
import { useI18n } from '../composables/useI18n';

const { t } = useI18n();
defineEmits(['navigate', 'showInfo']);
</script>
