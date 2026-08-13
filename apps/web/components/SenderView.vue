<script setup>
import { ref, watch, onMounted } from 'vue';
import {
  Monitor, Camera, Activity, Volume2, VolumeX, Repeat,
  CheckCircle2, Smartphone, Mic, MicOff,
} from 'lucide-vue-next';
import { useI18n } from '../composables/useI18n';

const { t } = useI18n();

const props = defineProps({
  peerId: { type: String, default: '' },
  isMicMuted: { type: Boolean, default: true },
  isPlaybackMuted: { type: Boolean, default: false },
  facingMode: { type: String, default: 'user' },
  selectedSources: { type: Array, default: () => [] },
  hasMultipleCameras: { type: Boolean, default: false },
  localScreenStream: { default: null },
  localCameraStream: { default: null },
  localVideo: { default: null },
  lastReceiverInfo: { type: String, default: '' },
  error: { type: String, default: null },
});

const emit = defineEmits(['toggleMic', 'toggleCamera', 'togglePlayback', 'resetApp']);

const localScreenVideo = ref(null);
const localCameraVideo = ref(null);
const localVideoEl = ref(null);

watch(localScreenVideo, (el) => { if (el && props.localScreenStream) el.srcObject = props.localScreenStream; });
watch(() => props.localScreenStream, (stream) => { if (stream && localScreenVideo.value) localScreenVideo.value.srcObject = stream; });

watch(localCameraVideo, (el) => { if (el && props.localCameraStream) el.srcObject = props.localCameraStream; });
watch(() => props.localCameraStream, (stream) => { if (stream && localCameraVideo.value) localCameraVideo.value.srcObject = stream; });

watch(localVideoEl, (el) => { if (el && props.localVideo) el.srcObject = props.localVideo; });
watch(() => props.localVideo, (stream) => { if (stream && localVideoEl.value) localVideoEl.value.srcObject = stream; });
</script>

<template>
  <div class="flex-1 flex flex-col items-center justify-center p-4">
    <div class="w-full max-w-xl backdrop-blur-xl bg-white/5 border border-white/10 rounded-[3rem] p-8 text-center relative overflow-hidden shadow-2xl">
      <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-cyan-500 to-transparent animate-pulse"></div>

      <div class="flex items-center justify-between mb-8">
        <div class="flex items-center gap-2">
          <Activity class="w-4 h-4 text-cyan-400" />
          <span class="text-[10px] font-black text-slate-500 uppercase tracking-widest">{{ t('sender.activeTunnel') }}</span>
        </div>
        <div class="flex items-center gap-2">
          <button @click="$emit('togglePlayback')"
            class="flex items-center gap-2 px-3 py-1.5 bg-slate-800 rounded-full hover:bg-cyan-500 hover:text-slate-950 transition-all"
            :class="{ 'bg-red-500/20 text-red-500 hover:bg-red-500 hover:text-white': isPlaybackMuted }">
            <component :is="isPlaybackMuted ? VolumeX : Volume2" class="w-3 h-3" />
            <span class="text-[10px] font-black uppercase">{{ isPlaybackMuted ? t('controls.muted') : t('controls.sound') }}</span>
          </button>
          <button @click="$emit('toggleMic')"
            class="flex items-center gap-2 px-3 py-1.5 bg-slate-800 rounded-full hover:bg-cyan-500 hover:text-slate-950 transition-all"
            :class="{ 'bg-red-500/20 text-red-500 hover:bg-red-500 hover:text-white': isMicMuted }">
            <component :is="isMicMuted ? MicOff : Mic" class="w-3 h-3" />
            <span class="text-[10px] font-black uppercase">{{ isMicMuted ? t('sender.muted') : t('sender.micOn') }}</span>
          </button>
          <button v-if="selectedSources.includes('camera') && hasMultipleCameras" @click="$emit('toggleCamera')"
            class="flex items-center gap-2 px-3 py-1.5 bg-slate-800 rounded-full hover:bg-cyan-500 hover:text-slate-950 transition-all">
            <Repeat class="w-3 h-3" />
            <span class="text-[10px] font-black uppercase">{{ facingMode === 'user' ? t('sender.front') : t('sender.back') }}</span>
          </button>
        </div>
      </div>

      <div class="mb-10">
        <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] mb-4">{{ t('sender.sharingKey') }}</p>
        <div class="flex items-center justify-center gap-2">
          <template v-for="(char, i) in peerId.split('')" :key="i">
            <span class="text-4xl md:text-6xl font-black bg-slate-950 w-12 md:w-16 h-16 md:h-24 flex items-center justify-center rounded-2xl border border-slate-800 text-cyan-400 shadow-inner">{{ char }}</span>
            <span v-if="i === 2" class="text-slate-800 font-black text-2xl">-</span>
          </template>
          <div v-if="!peerId" class="flex gap-2">
            <div v-for="n in 6" :key="n" class="w-12 h-16 bg-slate-950 rounded-2xl border border-slate-800 animate-pulse"></div>
          </div>
        </div>
      </div>

      <transition name="fade">
        <div v-if="error" class="mt-8 pt-6 border-t border-slate-800/50 flex justify-center">
          <div class="flex items-center gap-2 text-red-500 bg-red-400/5 px-6 py-2.5 rounded-2xl border border-red-500/20 shadow-sm shadow-red-500/5">
            <span class="text-[10px] font-black uppercase tracking-[0.2em]">{{ error }}</span>
          </div>
        </div>
        <div v-else-if="lastReceiverInfo" class="mt-8 pt-6 border-t border-slate-800/50 flex justify-center">
          <div class="flex items-center gap-2 text-emerald-500 bg-emerald-400/5 px-6 py-2.5 rounded-2xl border border-emerald-500/20 shadow-sm shadow-emerald-500/5">
            <Smartphone class="w-4 h-4" />
            <span class="text-[10px] font-black uppercase tracking-[0.2em]">{{ t('sender.receiverConnected', { info: lastReceiverInfo }) }}</span>
          </div>
        </div>
      </transition>

      <div class="grid gap-4 mb-8" :class="localScreenStream && localCameraStream ? 'grid-cols-2' : 'grid-cols-1'">
        <div v-if="localScreenStream" class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative group shadow-inner">
          <video ref="localScreenVideo" autoplay muted playsinline class="w-full h-full object-cover" />
          <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
          <div class="absolute bottom-4 left-6 flex items-center gap-3">
            <div class="w-2 h-2 bg-red-500 rounded-full animate-ping"></div>
            <span class="text-[8px] font-black uppercase tracking-widest">{{ t('sender.screenShare') }}</span>
          </div>
        </div>
        <div v-if="localCameraStream" class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative group shadow-inner">
          <video ref="localCameraVideo" autoplay muted playsinline class="w-full h-full object-cover" />
          <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
          <div class="absolute bottom-4 left-6 flex items-center gap-3">
            <div class="w-2 h-2 bg-red-500 rounded-full animate-ping"></div>
            <span class="text-[8px] font-black uppercase tracking-widest">{{ t('controls.camera') }}</span>
          </div>
        </div>
        <div v-if="!localScreenStream && !localCameraStream" class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative group shadow-inner">
          <video ref="localVideoEl" autoplay muted playsinline class="w-full h-full object-cover" />
        </div>
      </div>

      <button @click="$emit('resetApp')"
        class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-xs">
        {{ t('sender.terminate') }}
      </button>
    </div>
  </div>
</template>
