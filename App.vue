<script setup>
import { ref, onUnmounted, watch, nextTick } from 'vue';
import { 
  Monitor, 
  Download, 
  Zap, 
  X, 
  Copy,
  Check,
  AlertCircle,
  Loader2,
  ShieldAlert,
  WifiOff,
  Activity,
  Maximize,
  Minimize
} from 'lucide-vue-next';

// 应用状态枚举
const STATES = {
  LANDING: 'LANDING',
  SENDER: 'SENDER',
  RECEIVER_INPUT: 'RECEIVER_INPUT',
  RECEIVER_ACTIVE: 'RECEIVER_ACTIVE'
};

const PEER_CONFIG = {
  debug: 1,
  config: {
    iceServers: [
      { urls: 'stun:stun.miwifi.com:3478' },
      { urls: 'stun:stun.chat.agora.io:3478' },
      { urls: 'stun:stun.cdn.aliyun.com:3478' },
      { urls: 'stun:stun.tjsat.top:3478' },
      { urls: 'stun:stun.cloudflare.com:3478' }
    ],
    iceCandidatePoolSize: 10,
  }
};

const appState = ref(STATES.LANDING);
const peerId = ref('');
const inputCode = ref('');
const error = ref(null);
const isConnecting = ref(false);
const isCopied = ref(false);
const isFullscreen = ref(false);

const peerInstance = ref(null);
const localStream = ref(null);
const remoteStream = ref(null);
const localVideo = ref(null);
const remoteVideo = ref(null);
const playerContainer = ref(null);
const activeConnections = ref([]);

/**
 * 将流挂载到 Video 元素，处理自动播放策略
 */
const attachStream = async (videoEl, stream, label) => {
  if (!videoEl || !stream) return;
  
  if (videoEl.srcObject === stream) return; // 避免重复挂载

  console.log(`[CastNow] Attaching to ${label}`);
  videoEl.srcObject = stream;

  try {
    await videoEl.play();
  } catch (err) {
    videoEl.muted = true; // 浏览器通常允许静音后的自动播放
    try {
      await videoEl.play();
    } catch (e) {
      console.error(`[CastNow] ${label} Playback failed`, e);
    }
  }
};

/**
 * 全屏控制
 */
const toggleFullscreen = async () => {
  if (!playerContainer.value) return;

  try {
    if (!document.fullscreenElement) {
      await playerContainer.value.requestFullscreen();
      isFullscreen.value = true;
    } else {
      await document.exitFullscreen();
      isFullscreen.value = false;
    }
  } catch (err) {
    console.error('[CastNow] Fullscreen error:', err);
  }
};

// 监听系统全屏状态变化（处理 Esc 键退出等情况）
const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement;
};

if (typeof document !== 'undefined') {
  document.addEventListener('fullscreenchange', handleFullscreenChange);
}

/**
 * 核心：侦听状态和流的变化，确保预览视频即时显示
 */
watch([appState, localStream, remoteStream], async () => {
  await nextTick();
  
  // 投屏端预览
  if (appState.value === STATES.SENDER && localStream.value) {
    let retry = 0;
    const timer = setInterval(() => {
      if (localVideo.value) {
        attachStream(localVideo.value, localStream.value, 'LocalPreview');
        clearInterval(timer);
      }
      if (++retry > 20) clearInterval(timer);
    }, 50);
  }

  // 接收端播放
  if (appState.value === STATES.RECEIVER_ACTIVE && remoteStream.value) {
    let retry = 0;
    const timer = setInterval(() => {
      if (remoteVideo.value) {
        attachStream(remoteVideo.value, remoteStream.value, 'RemotePlayer');
        clearInterval(timer);
      }
      if (++retry > 20) clearInterval(timer);
    }, 50);
  }
}, { immediate: true });

const cleanup = () => {
  if (document.fullscreenElement) {
    document.exitFullscreen().catch(() => {});
  }

  if (localStream.value) {
    localStream.value.getTracks().forEach(track => track.stop());
    localStream.value = null;
  }
  if (localVideo.value) localVideo.value.srcObject = null;
  if (remoteVideo.value) remoteVideo.value.srcObject = null;

  activeConnections.value.forEach(conn => conn.close());
  activeConnections.value = [];

  if (peerInstance.value) {
    peerInstance.value.destroy();
    peerInstance.value = null;
  }

  remoteStream.value = null;
  peerId.value = '';
  inputCode.value = '';
  isConnecting.value = false;
  error.value = null;
};

onUnmounted(() => {
  cleanup();
  document.removeEventListener('fullscreenchange', handleFullscreenChange);
});

const handleStartCasting = async () => {
  try {
    isConnecting.value = true;
    error.value = null;

    const stream = await navigator.mediaDevices.getDisplayMedia({
      video: { cursor: "always", frameRate: { ideal: 30 } },
      audio: true
    });
    
    localStream.value = stream;
    appState.value = STATES.SENDER;

    stream.getVideoTracks()[0].onended = () => resetApp();

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const peer = new window.Peer(code, PEER_CONFIG);
    peerInstance.value = peer;

    peer.on('open', (id) => {
      peerId.value = id;
      isConnecting.value = false;
    });

    peer.on('connection', (conn) => {
      activeConnections.value.push(conn);
      peer.call(conn.peer, localStream.value);
      conn.on('close', () => {
        activeConnections.value = activeConnections.value.filter(c => c !== conn);
      });
    });

    peer.on('error', (err) => {
      console.error('[CastNow] Peer Error:', err.type);
      if (err.type === 'unavailable-id') {
        error.value = 'Code conflict, retrying...';
        handleStartCasting(); 
      } else {
        error.value = `Connection error: ${err.type}`;
        isConnecting.value = false;
      }
    });

  } catch (err) {
    console.error('[CastNow] Media Error:', err);
    error.value = 'Screen capture denied or failed.';
    isConnecting.value = false;
  }
};

const handleReceiveCast = () => {
  if (inputCode.value.length !== 6) return;
  isConnecting.value = true;
  error.value = null;

  const peer = new window.Peer(PEER_CONFIG);
  peerInstance.value = peer;

  peer.on('open', (id) => {
    const conn = peer.connect(inputCode.value);
    conn.on('open', () => activeConnections.value.push(conn));
    conn.on('close', () => resetApp());

    peer.on('call', (call) => {
      call.answer();
      call.on('stream', (stream) => {
        remoteStream.value = stream;
        appState.value = STATES.RECEIVER_ACTIVE;
        isConnecting.value = false;
      });
      call.on('close', () => resetApp());
    });

    setTimeout(() => {
      if (appState.value !== STATES.RECEIVER_ACTIVE && isConnecting.value) {
        error.value = 'Connection timeout.';
        isConnecting.value = false;
        cleanup();
      }
    }, 15000);
  });

  peer.on('error', (err) => {
    error.value = `Link failed: ${err.type}`;
    isConnecting.value = false;
  });
};

const resetApp = () => {
  cleanup();
  appState.value = STATES.LANDING;
};

const copyToClipboard = () => {
  if (!peerId.value) return;
  navigator.clipboard.writeText(peerId.value);
  isCopied.value = true;
  setTimeout(() => isCopied.value = false, 2000);
};
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30 overflow-x-hidden">
    <header v-if="appState !== STATES.RECEIVER_ACTIVE" class="flex items-center justify-between px-6 py-4 md:px-12 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-2 cursor-pointer group" @click="resetApp">
        <div class="w-8 h-8 bg-amber-500 rounded-lg flex items-center justify-center group-hover:rotate-12 transition-transform duration-300 shadow-lg shadow-amber-500/20">
          <Zap class="text-slate-950 w-5 h-5 fill-current" />
        </div>
        <span class="text-xl md:text-2xl font-black tracking-tighter uppercase">CastNow</span>
      </div>
      <div class="flex items-center gap-4">
         <div v-if="isConnecting" class="flex items-center gap-2 text-[10px] font-black text-amber-500 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/20 animate-pulse uppercase">
            <Activity class="w-3 h-3" /> Processing
         </div>
         <button class="px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-amber-500 border border-amber-500/30 rounded-full hover:bg-amber-500/10 transition-all">PRO</button>
      </div>
    </header>

    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        
        <!-- 1. LANDING -->
        <div v-if="appState === STATES.LANDING" key="landing" class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <h1 class="text-6xl md:text-9xl font-black mb-8 tracking-tighter leading-[0.85]">
            Instant <br />
            <span class="text-amber-500">Casting.</span>
          </h1>
          <p class="text-slate-400 text-lg md:text-xl mb-12 max-w-lg font-medium">No plugins. No latency. Pure P2P screen sharing.</p>
          <div class="grid md:grid-cols-2 gap-4 w-full max-w-2xl px-4">
            <button @click="handleStartCasting" :disabled="isConnecting" class="group relative overflow-hidden flex flex-col items-center justify-center p-10 bg-amber-500 hover:bg-amber-400 rounded-[2.5rem] transition-all shadow-xl active:scale-95 disabled:opacity-50">
              <Monitor v-if="!isConnecting" class="w-12 h-12 text-slate-950 mb-4 group-hover:scale-110 transition-transform" />
              <Loader2 v-else class="w-12 h-12 text-slate-950 mb-4 animate-spin" />
              <span class="text-slate-950 font-black text-2xl tracking-tight">Broadcast</span>
            </button>
            <button @click="appState = STATES.RECEIVER_INPUT" class="group flex flex-col items-center justify-center p-10 bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-[2.5rem] transition-all active:scale-95">
              <Download class="w-12 h-12 text-amber-500 mb-4 group-hover:scale-110 transition-transform" />
              <span class="text-white font-black text-2xl tracking-tight">Receive</span>
            </button>
          </div>
          <div v-if="error" class="mt-8 flex items-center gap-2 text-red-400 font-bold bg-red-400/5 px-6 py-3 rounded-xl border border-red-400/10 text-sm">
            <AlertCircle class="w-4 h-4" /> {{ error }}
          </div>
        </div>

        <!-- 2. SENDER (BROADCAST SIDE) -->
        <div v-else-if="appState === STATES.SENDER" key="sender" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-2xl bg-slate-900/40 border border-slate-800 rounded-[2.5rem] p-6 md:p-12 text-center backdrop-blur-xl shadow-2xl overflow-hidden">
            <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em] mb-6">Your Connection Code</p>
            
            <div class="flex flex-wrap items-center justify-center gap-2 mb-10 px-2 min-h-[5rem]">
              <div v-if="!peerId" class="flex items-center gap-2 text-amber-500/50">
                <Loader2 class="w-5 h-5 animate-spin" />
                <span class="text-sm font-black uppercase tracking-widest">Generating ID...</span>
              </div>
              <div v-else class="flex items-center gap-1 sm:gap-2">
                <template v-for="(char, i) in peerId.split('')" :key="i">
                  <span class="text-2xl sm:text-4xl md:text-5xl font-black text-white bg-slate-950 w-9 sm:w-14 h-12 sm:h-16 md:h-20 flex items-center justify-center rounded-xl border border-slate-800 shadow-xl">
                    {{ char }}
                  </span>
                  <span v-if="i === 2" class="text-slate-700 font-black text-xl px-0.5">-</span>
                </template>
                <button @click="copyToClipboard" class="p-4 ml-1 rounded-2xl bg-slate-800 hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-90 shadow-lg">
                  <Check v-if="isCopied" class="w-5 h-5" />
                  <Copy v-else class="w-5 h-5" />
                </button>
              </div>
            </div>

            <div class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden mb-8 shadow-2xl relative group">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-contain bg-slate-900" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end p-6">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse shadow-[0_0_8px_red]"></div>
                  <p class="text-[10px] font-black text-white tracking-widest uppercase opacity-80">Local Preview (Active)</p>
                </div>
              </div>
            </div>
            <button @click="resetApp" class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-[10px]">End Broadcast</button>
          </div>
        </div>

        <!-- 3. RECEIVER INPUT -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT" key="input" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-md bg-slate-900/40 border border-slate-800 rounded-[3rem] p-8 md:p-12 text-center shadow-2xl">
            <h2 class="text-3xl font-black mb-2 uppercase tracking-tight">Join Cast</h2>
            <p class="text-slate-500 text-sm mb-12">Enter the 6-digit session code</p>
            
            <div class="relative mb-12">
              <input v-model="inputCode" type="text" maxlength="6" inputmode="numeric" autofocus class="absolute inset-0 w-full h-full opacity-0 cursor-default z-10" @keyup.enter="handleReceiveCast" />
              <div class="flex justify-center gap-2 md:gap-3">
                <div v-for="i in 6" :key="i" class="w-10 md:w-14 h-14 md:h-20 bg-slate-950 border-2 rounded-2xl flex items-center justify-center text-3xl md:text-5xl font-black transition-all" :class="inputCode.length >= i ? 'border-amber-500 text-white shadow-lg shadow-amber-500/10 scale-105' : 'border-slate-800 text-slate-800'">
                  {{ inputCode[i-1] || '' }}
                </div>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <button @click="resetApp" class="py-4 md:py-5 bg-slate-800 hover:bg-slate-700 text-white font-black rounded-2xl transition-all uppercase tracking-widest text-[10px]">Back</button>
              <button @click="handleReceiveCast" :disabled="inputCode.length !== 6 || isConnecting" class="py-4 md:py-5 font-black rounded-2xl transition-all flex items-center justify-center gap-2 uppercase tracking-widest text-[10px]" :class="inputCode.length === 6 && !isConnecting ? 'bg-amber-500 text-slate-950' : 'bg-slate-800 text-slate-700'">
                <Loader2 v-if="isConnecting" class="w-4 h-4 animate-spin" />
                {{ isConnecting ? 'Joining' : 'Link' }}
              </button>
            </div>

            <div v-if="error" class="mt-8 p-4 rounded-xl bg-red-500/5 border border-red-500/10">
               <div class="flex items-center justify-center gap-2 text-red-400 font-black text-xs uppercase">
                 <WifiOff class="w-4 h-4" /> {{ error }}
               </div>
            </div>
          </div>
        </div>

        <!-- 4. PLAYER (RECEIVER SIDE) -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE" key="active" ref="playerContainer" class="fixed inset-0 bg-black z-[100] flex items-center justify-center overflow-hidden group/player">
          <video ref="remoteVideo" autoplay playsinline class="w-full h-full object-contain" />
          
          <!-- Overlay Controls -->
          <div class="absolute inset-0 opacity-0 group-hover/player:opacity-100 transition-opacity duration-300 pointer-events-none">
            <!-- Top Status Bar -->
            <div class="absolute top-6 left-6 md:top-10 md:left-10 flex items-center gap-4 bg-black/40 backdrop-blur-2xl px-5 py-2.5 rounded-full border border-white/5 shadow-2xl pointer-events-auto">
              <div class="w-2.5 h-2.5 bg-red-500 rounded-full animate-pulse shadow-[0_0_12px_rgba(239,68,68,0.8)]"></div>
              <span class="text-[10px] md:text-xs font-black text-white uppercase tracking-[0.25em]">Direct P2P Link</span>
            </div>

            <!-- Top Action Buttons -->
            <div class="absolute top-6 right-6 md:top-10 md:right-10 flex items-center gap-3 pointer-events-auto">
              <!-- Fullscreen Button -->
              <button @click="toggleFullscreen" class="w-12 h-12 md:w-16 md:h-16 flex items-center justify-center bg-white/5 hover:bg-white/20 backdrop-blur-2xl rounded-full text-white transition-all border border-white/5 shadow-2xl active:scale-90">
                <Minimize v-if="isFullscreen" class="w-6 h-6 md:w-8 md:h-8" />
                <Maximize v-else class="w-6 h-6 md:w-8 md:h-8" />
              </button>
              
              <!-- Close Button -->
              <button @click="resetApp" class="w-12 h-12 md:w-16 md:h-16 flex items-center justify-center bg-white/5 hover:bg-red-500 backdrop-blur-2xl rounded-full text-white transition-all border border-white/5 shadow-2xl active:scale-90">
                <X class="w-6 h-6 md:w-8 md:h-8 transition-transform group-hover:rotate-90 duration-500" />
              </button>
            </div>
          </div>

          <!-- Mobile Only Visible Hint -->
          <div class="absolute bottom-6 left-1/2 -translate-x-1/2 bg-black/50 backdrop-blur-xl px-4 py-2 rounded-full border border-white/10 md:hidden pointer-events-none animate-bounce">
            <span class="text-[8px] font-bold text-white uppercase tracking-widest">Tap to show controls</span>
          </div>
        </div>
      </Transition>
    </main>

    <footer v-if="appState !== STATES.RECEIVER_ACTIVE" class="px-8 md:px-12 py-8 border-t border-slate-900 flex flex-col md:flex-row justify-between items-center text-[10px] font-black text-slate-600 uppercase tracking-[0.3em] gap-4">
      <div>© 2024 CASTNOW PROTOCOL</div>
      <div class="flex gap-10">
        <a href="#" class="hover:text-amber-500 transition-colors">Docs</a>
        <a href="#" class="hover:text-amber-500 transition-colors">Privacy</a>
        <a href="#" class="hover:text-amber-500 transition-colors">Source</a>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { 
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1); 
}
.fade-enter-from, .fade-leave-to { 
  opacity: 0; 
  transform: scale(0.98) translateY(10px); 
}

/* 针对非全屏状态下的鼠标显示优化 */
.group\/player:hover {
  cursor: default;
}

input { caret-color: transparent; }

@media (max-width: 480px) {
  .text-5xl { font-size: 2rem !important; }
  .w-14 { width: 2.8rem !important; }
  .h-16 { height: 3.2rem !important; }
}

@media (max-width: 380px) {
  .text-2xl { font-size: 1.15rem !important; }
  .w-9 { width: 1.9rem !important; }
  .h-12 { height: 2.5rem !important; }
  .gap-1 { gap: 0.15rem !important; }
}

/* 适配全屏伪类 */
:fullscreen video {
  width: 100vw;
  height: 100vh;
  object-fit: contain;
}
</style>