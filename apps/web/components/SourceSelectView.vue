<template>
  <div class="flex-1 flex flex-col items-center justify-center p-6">
    <h2 class="text-2xl font-black tracking-tighter uppercase text-white mb-2">{{ t('source.title') }}</h2>

    <div class="flex flex-col gap-4 w-full max-w-sm mt-6">
      <button @click="$emit('toggleSource', 'screen')"
        :class="['flex items-center gap-4 p-5 rounded-2xl border-2 transition-all',
                 selectedSources.includes('screen') ? 'border-cyan-500 bg-cyan-500/10' : 'border-slate-800 bg-slate-900']">
        <Monitor class="w-6 h-6" :class="selectedSources.includes('screen') ? 'text-cyan-400' : 'text-slate-600'" />
        <div class="text-left">
          <div class="font-black uppercase text-sm" :class="selectedSources.includes('screen') ? 'text-white' : 'text-slate-400'">{{ t('source.screen') }}</div>
          <div class="text-xs text-slate-600">{{ t('source.screenDesc') }}</div>
        </div>
      </button>
      <button @click="$emit('toggleSource', 'camera')"
        :class="['flex items-center gap-4 p-5 rounded-2xl border-2 transition-all',
                 selectedSources.includes('camera') ? 'border-cyan-500 bg-cyan-500/10' : 'border-slate-800 bg-slate-900']">
        <Camera class="w-6 h-6" :class="selectedSources.includes('camera') ? 'text-cyan-400' : 'text-slate-600'" />
        <div class="text-left">
          <div class="font-black uppercase text-sm" :class="selectedSources.includes('camera') ? 'text-white' : 'text-slate-400'">{{ t('source.camera') }}</div>
          <div class="text-xs text-slate-600">{{ t('source.cameraDesc') }}</div>
        </div>
      </button>
      <div class="flex items-center justify-between p-4 rounded-2xl border border-slate-800 bg-slate-900">
        <div class="flex items-center gap-3">
          <Mic class="w-5 h-5 text-slate-600" />
          <div class="text-left">
            <div class="font-bold text-sm text-white">{{ t('source.microphone') }}</div>
            <div class="text-[10px] text-slate-600">{{ t('source.micDesc') }}</div>
          </div>
        </div>
        <button @click="$emit('toggleSource', 'mic')"
          :class="['px-3 py-1 rounded-lg text-[10px] font-black uppercase transition-all',
                   selectedSources.includes('mic') ? 'bg-cyan-500 text-slate-950' : 'bg-slate-800 text-slate-400']">
          {{ selectedSources.includes('mic') ? t('source.on') : t('source.off') }}
        </button>
      </div>
    </div>

    <button @click="$emit('startBroadcast')"
      class="mt-8 w-full max-w-sm py-6 bg-cyan-500 text-slate-950 rounded-3xl font-black text-xl uppercase shadow-xl shadow-cyan-500/20 active:scale-95 transition-all">
      {{ t('source.start') }}
    </button>
    <button @click="$emit('navigate', 'LANDING')"
      class="mt-4 text-xs font-bold uppercase text-slate-600 hover:text-slate-400 transition-colors tracking-widest">
      {{ t('source.cancel') }}
    </button>
  </div>
</template>

<script setup>
import { Monitor, Camera, Mic } from 'lucide-vue-next';
import { useI18n } from '../composables/useI18n';

const { t } = useI18n();
defineProps({ selectedSources: Array });
defineEmits(['toggleSource', 'startBroadcast', 'navigate']);
</script>
