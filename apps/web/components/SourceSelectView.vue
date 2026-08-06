<template>
  <div class="flex-1 flex flex-col items-center justify-center p-6">
    <h2 class="text-2xl font-black tracking-tighter uppercase text-white mb-2">{{ t('source.title') }}</h2>

    <div class="flex flex-col gap-4 w-full max-w-sm mt-6">
      <button @click="$emit('toggleSource', 'screen')"
        :disabled="!isScreenShareSupported"
        :class="['flex items-center gap-4 p-5 rounded-2xl border-2 transition-all relative',
                 !isScreenShareSupported ? 'opacity-50 cursor-not-allowed border-slate-800 bg-slate-900/50' :
                 selectedSources.includes('screen') ? 'border-cyan-500 bg-cyan-500/10' : 'border-slate-800 bg-slate-900']">
        <Monitor class="w-6 h-6" :class="selectedSources.includes('screen') && isScreenShareSupported ? 'text-cyan-400' : 'text-slate-600'" />
        <div class="text-left flex-1">
          <div class="flex items-center justify-between">
            <div class="font-black uppercase text-sm" :class="selectedSources.includes('screen') && isScreenShareSupported ? 'text-white' : 'text-slate-400'">{{ t('source.screen') }}</div>
            <span v-if="!isScreenShareSupported" class="text-[9px] font-bold px-2 py-0.5 bg-slate-800 text-slate-400 rounded-md uppercase tracking-wider">{{ t('source.desktopOnly') }}</span>
          </div>
          <div class="text-xs text-slate-600">{{ t('source.screenDesc') }}</div>
        </div>
      </button>
      <button @click="$emit('toggleSource', 'camera')"
        :disabled="isCameraDisabled"
        :class="['flex items-center gap-4 p-5 rounded-2xl border-2 transition-all relative',
                 isCameraDisabled ? 'opacity-50 cursor-not-allowed border-slate-800 bg-slate-900/50' :
                 selectedSources.includes('camera') ? 'border-cyan-500 bg-cyan-500/10' : 'border-slate-800 bg-slate-900']">
        <Camera class="w-6 h-6" :class="selectedSources.includes('camera') && !isCameraDisabled ? 'text-cyan-400' : 'text-slate-600'" />
        <div class="text-left flex-1">
          <div class="flex items-center justify-between">
            <div class="font-black uppercase text-sm" :class="selectedSources.includes('camera') && !isCameraDisabled ? 'text-white' : 'text-slate-400'">{{ t('source.camera') }}</div>
            <span v-if="isCameraDisabled" class="text-[9px] font-bold px-2 py-0.5 bg-slate-800 text-red-400 rounded-md uppercase tracking-wider">
              {{ isCameraDenied ? t('source.cameraDenied') : t('source.noCamera') }}
            </span>
          </div>
          <div class="text-xs text-slate-600">{{ t('source.cameraDesc') }}</div>
        </div>
      </button>
      <div :class="['flex items-center justify-between p-4 rounded-2xl border transition-all',
                    isMicDisabled ? 'opacity-50 border-slate-800/50 bg-slate-900/50' : 'border-slate-800 bg-slate-900']">
        <div class="flex items-center gap-3 flex-1">
          <Mic class="w-5 h-5 text-slate-600" />
          <div class="text-left flex-1">
            <div class="flex items-center justify-between pr-4">
              <div class="font-bold text-sm text-white">{{ t('source.microphone') }}</div>
              <span v-if="isMicDisabled" class="text-[9px] font-bold px-2 py-0.5 bg-slate-800 text-red-400 rounded-md uppercase tracking-wider">
                {{ isMicDenied ? t('source.micDenied') : t('source.noMic') }}
              </span>
            </div>
            <div class="text-[10px] text-slate-600">{{ t('source.micDesc') }}</div>
          </div>
        </div>
        <button @click="$emit('toggleSource', 'mic')"
          :disabled="isMicDisabled"
          :class="['px-3 py-1 rounded-lg text-[10px] font-black uppercase transition-all',
                   isMicDisabled ? 'bg-slate-800/50 text-slate-600 cursor-not-allowed' :
                   selectedSources.includes('mic') ? 'bg-cyan-500 text-slate-950' : 'bg-slate-800 text-slate-400']">
          {{ selectedSources.includes('mic') && !isMicDisabled ? t('source.on') : t('source.off') }}
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
import { computed } from 'vue';
import { Monitor, Camera, Mic } from 'lucide-vue-next';
import { useI18n } from '../composables/useI18n';

const { t } = useI18n();
const props = defineProps({
  selectedSources: { type: Array, default: () => [] },
  isScreenShareSupported: { type: Boolean, default: true },
  hasCamera: { type: Boolean, default: true },
  hasMicrophone: { type: Boolean, default: true },
  isCameraDenied: { type: Boolean, default: false },
  isMicDenied: { type: Boolean, default: false },
});
defineEmits(['toggleSource', 'startBroadcast', 'navigate']);

const isCameraDisabled = computed(() => !props.hasCamera || props.isCameraDenied);
const isMicDisabled = computed(() => !props.hasMicrophone || props.isMicDenied);
</script>
