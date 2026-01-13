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
const showProxyAdvice = ref(false);

const peerInstance = ref(null);
const localStream = ref(null);
const remoteStream = ref(null);
const localVideo = ref(null);
const remoteVideo = ref(null);
const activeConnections = ref([]);

// 深度诊断日志系统
const setupWebRTCStats = (pc, label) => {
  if (!pc) return;
  console.log(`%c[WebRTC:${label}] 🔎 Deep Monitoring Started`, 'color: #3b82f6; font-weight: bold');
  
  try {
    pc.oniceconnectionstatechange = () => {
      const state = pc.iceConnectionState;
      console.log(`[WebRTC:${label}] 🧊 ICE State: %c${state}`, 'color: #f59e0b; font-weight: bold');
      if (state === 'failed' || state === 'disconnected') showProxyAdvice.value = true;
    };

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        const c = event.candidate;
        console.log(`[WebRTC:${label}] 📍 New Candidate: ${c.protocol} | ${c.type} | ${c.address}:${c.port}`);
      }
    };

    const statsInterval = setInterval(async () => {
      if (pc.signalingState === 'closed') return clearInterval(statsInterval);
      try {
        const stats = await pc.getStats();
        stats.forEach(report => {
          if (report.type === 'inbound-rtp' && report.kind === 'video') {
            console.debug(`[WebRTC:${label}] 📊 Video Bitrate: ${Math.round(report.bytesReceived / 1024)} KB received`);
          }
        });
      } catch (e) {}
    }, 5000);
  } catch (e) {
    console.warn(`[WebRTC:${label}] Logger bind error:`, e);
  }
};

const cleanup = () => {
  console.log('[CastNow] Cleaning up resources...');
  
  // 1. 关闭所有数据连接（通知对方关闭）
  activeConnections.value.forEach(conn => {
    try { conn.close(); } catch(e) {}
  });
  activeConnections.value = [];

  // 2. 销毁 Peer 实例
  if (peerInstance.value) {
    try {
      peerInstance.value.destroy();
    } catch (e) {}
    peerInstance.value = null;
  }

  // 3. 停止所有媒体轨道 (关键：彻底终止屏幕共享)
  if (localStream.value) {
    localStream.value.getTracks().forEach(track => {
      track.stop();
      track.onended = null; // 解绑事件防止循环触发
    });
    localStream.value = null;
  }

  // 4. 重置状态
  remoteStream.value = null;
  peerId.value = '';
  inputCode.value = '';
  error.value = null;
  showProxyAdvice.value = false;
  isConnecting.value = false;
};

onUnmounted(cleanup);

// 增强流挂载逻辑
const attachStream = async (videoEl, stream, label) => {
  if (!videoEl || !stream) {
    console.warn(`[CastNow] Cannot attach ${label}: Element or stream missing`, { videoEl, stream });
    return;
  }
  
  console.log(`[CastNow] Attaching stream to <${label}> element...`);
  videoEl.srcObject = stream;
  
  try {
    await videoEl.play();
    console.log(`[CastNow] ✅ ${label} playback started.`);
  } catch (err) {
    console.warn(`[CastNow] ⚠️ ${label} standard playback failed, trying muted:`, err);
    videoEl.muted = true;
    try {
      await videoEl.play();
    } catch (e) {
      console.error(`[CastNow] ❌ ${label} total playback failure:`, e);
    }
  }
};

watch(localStream, async (stream) => {
  if (stream) {
    await nextTick();
    attachStream(localVideo.value, stream, 'LocalVideo');
  }
});

// 当进入接收端活跃状态时，确保视频流被挂载
watch(appState, async (newState) => {
  if (newState === STATES.RECEIVER_ACTIVE && remoteStream.value) {
    await nextTick();
    // 延迟一小会儿等待 Transition 动画完成
    setTimeout(() => {
      attachStream(remoteVideo.value, remoteStream.value, 'RemoteVideo');
    }, 100);
  }
});

watch(remoteStream, async (stream) => {
  if (stream && appState.value === STATES.RECEIVER_ACTIVE) {
    await nextTick();
    attachStream(remoteVideo.value, stream, 'RemoteVideo');
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
      video: { cursor: "always", frameRate: { ideal: 30 } },
      audio: true
    });
    
    localStream.value = stream;
    // 监听系统自带的“停止共享”按钮
    stream.getVideoTracks()[0].onended = () => {
      console.log('[CastNow] Screen sharing stopped by system.');
      resetApp();
    };

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const peer = new window.Peer(code, PEER_CONFIG);
    peerInstance.value = peer;

    peer.on('open', (id) => {
      peerId.value = id;
      appState.value = STATES.SENDER;
      isConnecting.value = false;
    });

    peer.on('connection', (conn) => {
      console.log('[CastNow] Receiver joined. Sending stream...');
      activeConnections.value.push(conn);
      
      const call = peer.call(conn.peer, localStream.value);
      if (call) {
        setupWebRTCStats(call.peerConnection, 'Sender');
      }

      conn.on('close', () => {
        console.log('[CastNow] A receiver has disconnected.');
        activeConnections.value = activeConnections.value.filter(c => c !== conn);
      });
    });

    peer.on('error', (err) => {
      console.error('[CastNow] Peer Error:', err.type);
      if (err.type === 'unavailable-id') {
        error.value = 'Code already in use. Try again.';
      } else {
        error.value = `Protocol Error: ${err.type}`;
        resetApp();
      }
      isConnecting.value = false;
    });

  } catch (err) {
    console.error('[CastNow] Capture error:', err);
    error.value = 'Failed to capture screen. Please check permissions.';
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
    console.log('[CastNow] Receiver ready:', id);
    const conn = peer.connect(inputCode.value);
    
    conn.on('open', () => {
      console.log('[CastNow] Connected to sender.');
      activeConnections.value.push(conn);
    });

    conn.on('close', () => {
      console.log('[CastNow] Sender terminated connection.');
      resetApp();
    });

    peer.on('call', (call) => {
      console.log('[CastNow] 📞 Answering call...');
      call.answer(); 
      setupWebRTCStats(call.peerConnection, 'Receiver');

      call.on('stream', (stream) => {
        console.log('[CastNow] 🌊 Stream received. Initializing player...');
        remoteStream.value = stream;
        appState.value = STATES.RECEIVER_ACTIVE;
        isConnecting.value = false;
      });
    });

    setTimeout(() => {
      if (appState.value !== STATES.RECEIVER_ACTIVE && isConnecting.value) {
        error.value = 'Connection timeout. Check the code or your network.';
        isConnecting.value = false;
        showProxyAdvice.value = true;
      }
    }, 15000);
  });

  peer.on('error', (err) => {
    console.error('[CastNow] Receiver Error:', err.type);
    error.value = `Link failed: ${err.type}`;
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
        <div v-else-if="appState === STATES.SENDER" key="sender" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-xl bg-slate-900/40 border border-slate-800 rounded-[2.5rem] p-6 md:p-12 text-center backdrop-blur-xl shadow-2xl overflow-hidden">
            <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em] mb-6">Connection Code</p>
            
            <div class="flex flex-wrap items-center justify-center gap-2 mb-8 px-2">
              <div class="flex items-center gap-1.5 sm:gap-2">
                <template v-for="(char, i) in peerId.split('')" :key="i">
                  <span class="text-2xl sm:text-4xl md:text-5xl font-black text-white bg-slate-950 w-9 sm:w-14 h-12 sm:h-16 md:h-20 flex items-center justify-center rounded-xl border border-slate-800 shadow-xl">
                    {{ char }}
                  </span>
                  <span v-if="i === 2" class="text-slate-700 font-black text-xl px-0.5">-</span>
                </template>
              </div>
              <button @click="copyToClipboard" class="p-4 rounded-2xl bg-slate-800 hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-90 shadow-lg">
                <Check v-if="isCopied" class="w-5 h-5" />
                <Copy v-else class="w-5 h-5" />
              </button>
            </div>

            <div class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden mb-8 shadow-2xl relative group">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-contain" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end p-6">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
                  <p class="text-[10px] font-black text-white tracking-widest uppercase opacity-80">Local Preview</p>
                </div>
              </div>
            </div>
            <button @click="resetApp" class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-[10px]">End Session</button>
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
            <span class="text-[10px] md:text-xs font-black text-white uppercase tracking-[0.25em]">Live Link Active</span>
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

/* 针对极小屏幕的适配 */
@media (max-width: 480px) {
  .text-5xl { font-size: 2.25rem !important; }
  .w-14 { width: 3rem !important; }
  .h-16 { height: 3.5rem !important; }
}

@media (max-width: 380px) {
  .text-2xl { font-size: 1.25rem !important; }
  .w-9 { width: 2.1rem !important; }
  .h-12 { height: 2.75rem !important; }
  .gap-1.5 { gap: 0.25rem !important; }
}
</style>