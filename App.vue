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
  Activity
} from 'lucide-vue-next';

// App States
const STATES = {
  LANDING: 'LANDING',
  SENDER: 'SENDER',
  RECEIVER_INPUT: 'RECEIVER_INPUT',
  RECEIVER_ACTIVE: 'RECEIVER_ACTIVE'
};

const PEER_CONFIG = {
  debug: 1, // 降低生产环境日志干扰
  config: {
    iceServers: [
      // 优化为中国境内访问稳定的 STUN 服务器
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
const showProxyAdvice = ref(false);

const peerInstance = ref(null);
const localStream = ref(null);
const remoteStream = ref(null);
const localVideo = ref(null);
const remoteVideo = ref(null);

// WebRTC Logging Helper
const setupWebRTCStats = (pc, label) => {
  if (!pc) return;
  
  console.log(`[WebRTC:${label}] 🟢 Monitoring PC instance.`);
  
  try {
    pc.oniceconnectionstatechange = () => {
      const state = pc.iceConnectionState;
      console.log(`[WebRTC:${label}] 🧊 ICE Connection: %c${state}`, 'color: #f59e0b; font-weight: bold');
      if (state === 'failed' || state === 'disconnected') {
        // 14秒断开通常是因为 ICE 保持心跳失败
        showProxyAdvice.value = true;
      }
    };

    pc.onconnectionstatechange = () => {
      console.log(`[WebRTC:${label}] 🔌 Connection State: %c${pc.connectionState}`, 'color: #10b981; font-weight: bold');
      if (pc.connectionState === 'closed') {
        console.warn(`[WebRTC:${label}] Connection closed unexpectedly.`);
      }
    };

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        const c = event.candidate;
        console.log(`[WebRTC:${label}] 📍 Candidate: ${c.type} via ${c.protocol}`);
      }
    };
  } catch (e) {
    console.warn(`[WebRTC:${label}] Logger bind error:`, e);
  }
};

const cleanup = () => {
  console.log('[CastNow] Cleaning up resources...');
  if (peerInstance.value) {
    peerInstance.value.destroy();
    peerInstance.value = null;
  }
  if (localStream.value) {
    localStream.value.getTracks().forEach(track => track.stop());
    localStream.value = null;
  }
  remoteStream.value = null;
  peerId.value = '';
  inputCode.value = '';
  error.value = null;
  showProxyAdvice.value = false;
  isConnecting.value = false;
};

onUnmounted(cleanup);

watch(localStream, async (stream) => {
  if (stream) {
    await nextTick();
    if (localVideo.value) localVideo.value.srcObject = stream;
  }
});

watch(remoteStream, async (stream) => {
  if (stream) {
    await nextTick();
    if (remoteVideo.value) remoteVideo.value.srcObject = stream;
  }
});

const copyToClipboard = () => {
  if (!peerId.value) return;
  navigator.clipboard.writeText(peerId.value);
  isCopied.value = true;
  setTimeout(() => isCopied.value = false, 2000);
};

// SENDER LOGIC
const handleStartCasting = async () => {
  try {
    isConnecting.value = true;
    error.value = null;

    const stream = await navigator.mediaDevices.getDisplayMedia({
      video: { 
        cursor: "always",
        frameRate: { ideal: 30, max: 60 }
      },
      audio: true
    });
    
    localStream.value = stream;
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    
    const peer = new window.Peer(code, PEER_CONFIG);
    peerInstance.value = peer;

    peer.on('open', (id) => {
      peerId.value = id;
      appState.value = STATES.SENDER;
      isConnecting.value = false;
    });

    peer.on('call', (call) => {
      console.log('[CastNow] Received incoming call request');
      call.answer(stream);
      setTimeout(() => setupWebRTCStats(call.peerConnection, 'Sender'), 1000);
    });

    peer.on('error', (err) => {
      error.value = `Protocol Error: ${err.type}`;
      if (err.type !== 'unavailable-id') {
        cleanup();
        appState.value = STATES.LANDING;
      }
    });

    stream.getVideoTracks()[0].onended = resetApp;
  } catch (err) {
    error.value = 'Display capture denied or failed.';
    isConnecting.value = false;
  }
};

// RECEIVER LOGIC
const handleReceiveCast = () => {
  if (inputCode.value.length !== 6) return;

  isConnecting.value = true;
  error.value = null;

  const peer = new window.Peer(PEER_CONFIG);
  peerInstance.value = peer;

  peer.on('open', (id) => {
    // 关键修正：呼叫时不发送任何流，等待对方 answer 视频轨道
    const call = peer.call(inputCode.value, null);
    
    if (call) {
      setTimeout(() => setupWebRTCStats(call.peerConnection, 'Receiver'), 1000);
      
      const timeout = setTimeout(() => {
        if (appState.value !== STATES.RECEIVER_ACTIVE) {
          error.value = 'Connection timeout. Check Sender status.';
          showProxyAdvice.value = true;
          isConnecting.value = false;
          cleanup();
          appState.value = STATES.RECEIVER_INPUT;
        }
      }, 20000);

      call.on('stream', (stream) => {
        console.log('[CastNow] 🎉 Remote stream received!');
        clearTimeout(timeout);
        remoteStream.value = stream;
        appState.value = STATES.RECEIVER_ACTIVE;
        isConnecting.value = false;
      });

      call.on('close', () => {
        console.warn('[CastNow] Call closed by peer');
        resetApp();
      });
    }
  });

  peer.on('error', (err) => {
    error.value = err.type === 'peer-unavailable' ? 'Sender not found or code expired.' : `Network issue: ${err.type}`;
    isConnecting.value = false;
  });
};

const resetApp = () => {
  cleanup();
  appState.value = STATES.LANDING;
};
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30 overflow-x-hidden">
    <header class="flex items-center justify-between px-6 py-4 md:px-12 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-2 cursor-pointer group" @click="resetApp">
        <div class="w-8 h-8 bg-amber-500 rounded-lg flex items-center justify-center group-hover:rotate-12 transition-transform duration-300 shadow-lg shadow-amber-500/20">
          <Zap class="text-slate-950 w-5 h-5 fill-current" />
        </div>
        <span class="text-xl md:text-2xl font-black tracking-tighter uppercase">CastNow</span>
      </div>
      <div class="flex items-center gap-4">
         <div v-if="isConnecting" class="flex items-center gap-2 text-[10px] font-black text-amber-500 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/20 animate-pulse uppercase">
            <Activity class="w-3 h-3" /> Linking
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
        <div v-else-if="appState === STATES.SENDER" key="sender" class="flex-1 flex flex-col items-center justify-center p-3 sm:p-4">
          <div class="w-full max-w-xl bg-slate-900/40 border border-slate-800 rounded-[2rem] sm:rounded-[3rem] p-4 sm:p-12 text-center backdrop-blur-xl shadow-2xl">
            <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em] mb-6 sm:mb-8">Connection Code</p>
            
            <!-- FIXED CODE DISPLAY FOR SMALL SCREENS -->
            <div class="flex items-center justify-center gap-1 sm:gap-2 mb-8 sm:mb-10 max-w-full overflow-hidden px-2">
              <div class="flex items-center gap-1 sm:gap-2">
                <template v-for="(char, i) in peerId.split('')" :key="i">
                  <span class="text-2xl sm:text-4xl md:text-6xl font-black text-white bg-slate-950 w-8 sm:w-12 md:w-16 h-12 sm:h-16 md:h-20 flex items-center justify-center rounded-lg sm:rounded-2xl border border-slate-800 shadow-[inset_0_2px_10px_rgba(0,0,0,0.5)]">
                    {{ char }}
                  </span>
                  <span v-if="i === 2" class="text-slate-700 font-black text-lg sm:text-2xl px-0.5">-</span>
                </template>
              </div>
              <button @click="copyToClipboard" class="ml-1 sm:ml-4 flex-shrink-0 p-2 sm:p-4 rounded-full bg-slate-800 hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-90 shadow-lg">
                <Check v-if="isCopied" class="w-4 h-4 sm:w-5 sm:h-5" />
                <Copy v-else class="w-4 h-4 sm:w-5 sm:h-5" />
              </button>
            </div>

            <div class="aspect-video bg-black rounded-xl sm:rounded-[2rem] border border-slate-800 overflow-hidden mb-8 sm:mb-10 shadow-2xl relative group">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-contain" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end p-4 sm:p-6">
                <p class="text-[9px] sm:text-[10px] font-black text-white tracking-widest uppercase opacity-60">Live Preview</p>
              </div>
            </div>
            <button @click="resetApp" class="w-full py-4 sm:py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-xl sm:rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-[10px]">End Session</button>
          </div>
        </div>

        <!-- 3. RECEIVER INPUT -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT" key="input" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-md bg-slate-900/40 border border-slate-800 rounded-[3rem] p-8 md:p-12 text-center shadow-2xl">
            <h2 class="text-3xl font-black mb-2 uppercase tracking-tight">Join Cast</h2>
            <p class="text-slate-500 text-sm mb-12">Enter the session code</p>
            
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
                {{ isConnecting ? 'Linking' : 'Join' }}
              </button>
            </div>

            <div v-if="error || showProxyAdvice" class="mt-8 p-6 rounded-2xl bg-red-500/5 border border-red-500/10 text-left animate-in fade-in zoom-in-95">
               <div v-if="error" class="flex items-center gap-2 text-red-400 font-black text-xs uppercase mb-2">
                 <WifiOff class="w-4 h-4" /> {{ error }}
               </div>
               <div v-if="showProxyAdvice" class="flex flex-col gap-3">
                 <div class="p-3 bg-red-500/10 rounded-xl border border-red-500/20">
                    <p class="text-[11px] text-red-400 font-bold leading-relaxed flex items-start gap-2">
                      <ShieldAlert class="w-4 h-4 flex-shrink-0" />
                      P2P handshaking failed. Potential issues: VPN interference, restricted firewall, or symmetric NAT.
                    </p>
                 </div>
                 <div class="text-[9px] text-slate-500 font-medium space-y-1 uppercase tracking-tighter">
                    <p>• Try disabling VPN / Proxy</p>
                    <p>• Switch network (e.g. 4G/5G Hotspot)</p>
                    <p>• Check if the Sender is still online</p>
                 </div>
               </div>
            </div>
          </div>
        </div>

        <!-- 4. PLAYER -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE" key="active" class="fixed inset-0 bg-black z-[100] flex items-center justify-center overflow-hidden">
          <video ref="remoteVideo" autoplay playsinline class="w-full h-full object-contain" />
          <div class="absolute top-6 left-6 md:top-10 md:left-10 flex items-center gap-4 bg-black/40 backdrop-blur-2xl px-5 py-2.5 rounded-full border border-white/5 shadow-2xl pointer-events-none">
            <div class="w-2.5 h-2.5 bg-red-500 rounded-full animate-pulse shadow-[0_0_12px_rgba(239,68,68,0.8)]"></div>
            <span class="text-[10px] md:text-xs font-black text-white uppercase tracking-[0.25em]">Direct Link Active</span>
          </div>
          <button @click="resetApp" class="absolute top-6 right-6 md:top-10 md:right-10 w-12 h-12 md:w-16 md:h-16 flex items-center justify-center bg-white/5 hover:bg-red-500 backdrop-blur-2xl rounded-full text-white transition-all group border border-white/5 shadow-2xl">
            <X class="w-6 h-6 md:w-8 md:h-8 group-hover:rotate-90 transition-transform duration-500" />
          </button>
        </div>
      </Transition>
    </main>

    <footer v-if="appState !== STATES.RECEIVER_ACTIVE" class="px-8 md:px-12 py-8 border-t border-slate-900 flex flex-col md:flex-row justify-between items-center text-[10px] font-black text-slate-600 uppercase tracking-[0.3em] gap-4">
      <div>© 2024 CASTNOW PROTOCOL</div>
      <div class="flex gap-10">
        <a href="#" class="hover:text-amber-500 transition-colors">Documentation</a>
        <a href="#" class="hover:text-amber-500 transition-colors">Server</a>
        <a href="#" class="hover:text-amber-500 transition-colors">Open Source</a>
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
input { caret-color: transparent; }

/* 增强针对超小屏幕的自适应能力 */
@media (max-width: 380px) {
  .gap-1 { gap: 0.1rem !important; }
  .w-8 { width: 1.75rem !important; }
  .h-12 { height: 2.5rem !important; }
  .text-2xl { font-size: 1.15rem !important; }
  .px-2 { padding-left: 0.25rem !important; padding-right: 0.25rem !important; }
}
</style>