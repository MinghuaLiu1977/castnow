<script setup>
import { ref, onUnmounted, watch, nextTick, computed } from 'vue';
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
  Minimize,
  BookOpen,
  ShieldCheck,
  Code2,
  Github,
  Mail,
  User,
  ExternalLink,
  Globe,
  Layers
} from 'lucide-vue-next';

// Application States
const STATES = {
  LANDING: 'LANDING',
  SENDER: 'SENDER',
  RECEIVER_INPUT: 'RECEIVER_INPUT',
  RECEIVER_ACTIVE: 'RECEIVER_ACTIVE'
};

/**
 * Dynamic STUN Server Selection
 * Detects if the user is in Mainland China to provide localized STUN servers for lower latency.
 */
const getIceServers = () => {
  const isChina = () => {
    try {
      const locale = navigator.language || '';
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
      // Heuristic for Mainland China region
      return locale.toLowerCase().includes('zh') || 
             timezone.includes('Asia/Shanghai') || 
             timezone.includes('Asia/Chongqing') || 
             timezone.includes('Asia/Urumqi') || 
             timezone.includes('Asia/Harbin');
    } catch (e) {
      return false;
    }
  };

  const chinaStuns = [
    { urls: 'stun:stun.miwifi.com:3478' },
    { urls: 'stun:stun.chat.agora.io:3478' },
    { urls: 'stun:stun.cdn.aliyun.com:3478' },
    { urls: 'stun:stun.douyucdn.cn:3478' },
    { urls: 'stun:stun.hitv.com:3478' },
    { urls: 'stun:stun.tjsat.top:3478' },
    { urls: 'stun:stun.cloudflare.com:3478' }
  ];

  const globalStuns = [
    { urls: 'stun:stun.cloudflare.com:3478' },
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun.voipstunt.com' },
    { urls: 'stun:stun.ekiga.net' },
    { urls: 'stun:stun.ideasip.com' }
  ];

  return isChina() ? chinaStuns : globalStuns;
};

const appState = ref(STATES.LANDING);
const peerId = ref('');
const inputCode = ref('');
const error = ref(null);
const isConnecting = ref(false);
const isCopied = ref(false);
const isFullscreen = ref(false);

// Modal States: 'docs', 'privacy', 'source', 'contact'
const activeModal = ref(null); 

const peerInstance = ref(null);
const localStream = ref(null);
const remoteStream = ref(null);
const localVideo = ref(null);
const remoteVideo = ref(null);
const playerContainer = ref(null);
const activeConnections = ref([]);

const attachStream = async (videoEl, stream, label) => {
  if (!videoEl || !stream) return;
  if (videoEl.srcObject === stream) return;
  
  videoEl.srcObject = stream;
  try {
    await videoEl.play();
  } catch (err) {
    videoEl.muted = true;
    try { await videoEl.play(); } catch (e) { console.error(`[${label}] Auto-play failed`, e); }
  }
};

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
  } catch (err) { console.error('Fullscreen toggle error:', err); }
};

const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement;
};

if (typeof document !== 'undefined') {
  document.addEventListener('fullscreenchange', handleFullscreenChange);
}

watch([appState, localStream, remoteStream], async () => {
  await nextTick();
  if (appState.value === STATES.SENDER && localStream.value) {
    let retry = 0;
    const timer = setInterval(() => {
      if (localVideo.value) { attachStream(localVideo.value, localStream.value, 'Local'); clearInterval(timer); }
      if (++retry > 20) clearInterval(timer);
    }, 50);
  }
  if (appState.value === STATES.RECEIVER_ACTIVE && remoteStream.value) {
    let retry = 0;
    const timer = setInterval(() => {
      if (remoteVideo.value) { attachStream(remoteVideo.value, remoteStream.value, 'Remote'); clearInterval(timer); }
      if (++retry > 20) clearInterval(timer);
    }, 50);
  }
}, { immediate: true });

const cleanup = () => {
  if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
  if (localStream.value) { localStream.value.getTracks().forEach(t => t.stop()); localStream.value = null; }
  if (localVideo.value) localVideo.value.srcObject = null;
  if (remoteVideo.value) remoteVideo.value.srcObject = null;
  activeConnections.value.forEach(c => c.close());
  activeConnections.value = [];
  if (peerInstance.value) { peerInstance.value.destroy(); peerInstance.value = null; }
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
    const stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: true });
    localStream.value = stream;
    appState.value = STATES.SENDER;
    stream.getVideoTracks()[0].onended = () => resetApp();
    
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const peer = new window.Peer(code, {
      debug: 1,
      config: {
        iceServers: getIceServers(),
        iceCandidatePoolSize: 10,
      }
    });
    peerInstance.value = peer;
    
    peer.on('open', (id) => { peerId.value = id; isConnecting.value = false; });
    peer.on('connection', (conn) => {
      activeConnections.value.push(conn);
      peer.call(conn.peer, localStream.value);
      conn.on('close', () => activeConnections.value = activeConnections.value.filter(c => c !== conn));
    });
    peer.on('error', (err) => {
      if (err.type === 'unavailable-id') handleStartCasting();
      else { error.value = `Protocol Fault: ${err.type}`; isConnecting.value = false; }
    });
  } catch (err) {
    error.value = 'Capture was denied.';
    isConnecting.value = false;
  }
};

const handleReceiveCast = () => {
  if (inputCode.value.length !== 6) return;
  isConnecting.value = true;
  error.value = null;
  
  const peer = new window.Peer({
    debug: 1,
    config: {
      iceServers: getIceServers(),
      iceCandidatePoolSize: 10,
    }
  });
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
        error.value = 'Handshake timed out.'; 
        isConnecting.value = false; 
        cleanup(); 
      } 
    }, 15000);
  });
  peer.on('error', (err) => { error.value = `Access failed: ${err.type}`; isConnecting.value = false; });
};

const resetApp = () => { cleanup(); appState.value = STATES.LANDING; };
const copyToClipboard = () => { 
  navigator.clipboard.writeText(peerId.value); 
  isCopied.value = true; 
  setTimeout(() => isCopied.value = false, 2000); 
};
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30 overflow-x-hidden">
    <!-- Header -->
    <header v-if="appState !== STATES.RECEIVER_ACTIVE" class="flex items-center justify-between px-6 py-4 md:px-12 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-2 cursor-pointer group" @click="resetApp">
        <div class="w-8 h-8 bg-amber-500 rounded-lg flex items-center justify-center group-hover:rotate-12 transition-transform duration-300 shadow-lg shadow-amber-500/20">
          <Zap class="text-slate-950 w-5 h-5 fill-current" />
        </div>
        <span class="text-xl md:text-2xl font-black tracking-tighter uppercase">CastNow</span>
      </div>
      <div class="flex items-center gap-4">
         <div v-if="isConnecting" class="hidden sm:flex items-center gap-2 text-[10px] font-black text-amber-500 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/20 animate-pulse uppercase">
            <Activity class="w-3 h-3" /> Tunneling
         </div>
         <button @click="activeModal = 'contact'" class="px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-amber-500 border border-amber-500/30 rounded-full hover:bg-amber-500 hover:text-slate-950 transition-all">Local Deployment</button>
      </div>
    </header>

    <!-- Main Content -->
    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        
        <!-- 1. LANDING -->
        <div v-if="appState === STATES.LANDING" key="landing" class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="mb-6 flex items-center gap-2 bg-slate-900/50 px-4 py-1.5 rounded-full border border-slate-800">
            <Globe class="w-3.5 h-3.5 text-amber-500" />
            <span class="text-[9px] font-bold uppercase tracking-[0.2em] text-slate-400">P2P Optimized for your region</span>
          </div>
          <h1 class="text-6xl md:text-9xl font-black mb-8 tracking-tighter leading-[0.85]">
            Instant <br />
            <span class="text-amber-500">Casting.</span>
          </h1>
          <p class="text-slate-400 text-lg md:text-xl mb-12 max-w-lg font-medium italic">No plugins. No latency. Pure P2P screen sharing built on modern WebRTC.</p>
          <div class="grid md:grid-cols-2 gap-4 w-full max-w-2xl px-4">
            <button @click="handleStartCasting" :disabled="isConnecting" class="group relative overflow-hidden flex flex-col items-center justify-center p-10 bg-amber-500 hover:bg-amber-400 rounded-[2.5rem] transition-all shadow-xl active:scale-95 disabled:opacity-50">
              <Monitor v-if="!isConnecting" class="w-12 h-12 text-slate-950 mb-4 group-hover:scale-110 transition-transform" />
              <Loader2 v-else class="w-12 h-12 text-slate-950 mb-4 animate-spin" />
              <span class="text-slate-950 font-black text-2xl tracking-tight uppercase">Broadcast</span>
            </button>
            <button @click="appState = STATES.RECEIVER_INPUT" class="group flex flex-col items-center justify-center p-10 bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-[2.5rem] transition-all active:scale-95">
              <Download class="w-12 h-12 text-amber-500 mb-4 group-hover:scale-110 transition-transform" />
              <span class="text-white font-black text-2xl tracking-tight uppercase">Receive</span>
            </button>
          </div>
          <div v-if="error" class="mt-8 flex items-center gap-2 text-red-400 font-bold bg-red-400/5 px-6 py-3 rounded-xl border border-red-400/10 text-sm">
            <AlertCircle class="w-4 h-4" /> {{ error }}
          </div>
        </div>

        <!-- 2. SENDER (BROADCAST SIDE) -->
        <div v-else-if="appState === STATES.SENDER" key="sender" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-2xl bg-slate-900/40 border border-slate-800 rounded-[2.5rem] p-6 md:p-12 text-center backdrop-blur-xl shadow-2xl">
            <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em] mb-6">Unique Channel Identifier</p>
            <div class="flex flex-wrap items-center justify-center gap-2 mb-10 min-h-[5rem]">
              <div v-if="!peerId" class="flex items-center gap-2 text-amber-500/50">
                <Loader2 class="w-5 h-5 animate-spin" />
                <span class="text-sm font-black uppercase tracking-widest">Opening Tunnel...</span>
              </div>
              <div v-else class="flex items-center gap-1 sm:gap-2">
                <template v-for="(char, i) in peerId.split('')" :key="i">
                  <span class="text-2xl sm:text-4xl md:text-5xl font-black text-white bg-slate-950 w-9 sm:w-14 h-12 sm:h-16 md:h-20 flex items-center justify-center rounded-xl border border-slate-800 shadow-xl">{{ char }}</span>
                  <span v-if="i === 2" class="text-slate-700 font-black text-xl px-0.5">-</span>
                </template>
                <button @click="copyToClipboard" class="p-4 ml-1 rounded-2xl bg-slate-800 hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-90 shadow-lg">
                  <Check v-if="isCopied" class="w-5 h-5" />
                  <Copy v-else class="w-5 h-5" />
                </button>
              </div>
            </div>
            <div class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden mb-8 shadow-2xl relative">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-contain bg-slate-900" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end p-6">
                <div class="flex items-center gap-2"><div class="w-2 h-2 bg-red-500 rounded-full animate-pulse shadow-[0_0_8px_red]"></div><p class="text-[10px] font-black text-white tracking-widest uppercase opacity-80">Live Stream Monitor</p></div>
              </div>
            </div>
            <button @click="resetApp" class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-[10px]">Close Session</button>
          </div>
        </div>

        <!-- 3. RECEIVER INPUT -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT" key="input" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-md bg-slate-900/40 border border-slate-800 rounded-[3rem] p-8 md:p-12 text-center shadow-2xl">
            <h2 class="text-3xl font-black mb-2 uppercase tracking-tight">Access Key</h2>
            <p class="text-slate-500 text-sm mb-12 uppercase tracking-widest">Connect to an active node</p>
            <div class="relative mb-12">
              <input v-model="inputCode" type="text" maxlength="6" inputmode="numeric" autofocus class="absolute inset-0 w-full h-full opacity-0 cursor-default z-10" @keyup.enter="handleReceiveCast" />
              <div class="flex justify-center gap-2">
                <div v-for="i in 6" :key="i" class="w-10 md:w-14 h-14 md:h-20 bg-slate-950 border-2 rounded-2xl flex items-center justify-center text-3xl md:text-5xl font-black transition-all" :class="inputCode.length >= i ? 'border-amber-500 text-white shadow-lg shadow-amber-500/10 scale-105' : 'border-slate-800 text-slate-800'">{{ inputCode[i-1] || '' }}</div>
              </div>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <button @click="resetApp" class="py-4 bg-slate-800 hover:bg-slate-700 text-white font-black rounded-2xl transition-all uppercase tracking-widest text-[10px]">Back</button>
              <button @click="handleReceiveCast" :disabled="inputCode.length !== 6 || isConnecting" class="py-4 font-black rounded-2xl transition-all flex items-center justify-center gap-2 uppercase tracking-widest text-[10px]" :class="inputCode.length === 6 && !isConnecting ? 'bg-amber-500 text-slate-950' : 'bg-slate-800 text-slate-700'">
                <Loader2 v-if="isConnecting" class="w-4 h-4 animate-spin" />
                {{ isConnecting ? 'Linking' : 'Establish Link' }}
              </button>
            </div>
          </div>
        </div>

        <!-- 4. PLAYER (RECEIVER SIDE) -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE" key="active" ref="playerContainer" class="fixed inset-0 bg-black z-[100] flex items-center justify-center overflow-hidden group/player">
          <video ref="remoteVideo" autoplay playsinline class="w-full h-full object-contain" />
          <div class="absolute inset-0 opacity-0 group-hover/player:opacity-100 transition-opacity duration-300 pointer-events-none">
            <div class="absolute top-6 left-6 md:top-10 md:left-10 flex items-center gap-4 bg-black/40 backdrop-blur-2xl px-5 py-2.5 rounded-full border border-white/5 pointer-events-auto shadow-2xl">
              <div class="w-2.5 h-2.5 bg-red-500 rounded-full animate-pulse shadow-[0_0_12px_red]"></div>
              <span class="text-[10px] font-black text-white uppercase tracking-[0.25em]">Secure P2P Node Active</span>
            </div>
            <div class="absolute top-6 right-6 md:top-10 md:right-10 flex items-center gap-3 pointer-events-auto">
              <button @click="toggleFullscreen" class="w-12 h-12 md:w-16 md:h-16 flex items-center justify-center bg-white/5 hover:bg-white/20 backdrop-blur-2xl rounded-full text-white transition-all border border-white/5 shadow-2xl"><Minimize v-if="isFullscreen" class="w-6 h-6" /><Maximize v-else class="w-6 h-6" /></button>
              <button @click="resetApp" class="w-12 h-12 md:w-16 md:h-16 flex items-center justify-center bg-white/5 hover:bg-red-500 backdrop-blur-2xl rounded-full text-white transition-all border border-white/5 shadow-2xl"><X class="w-6 h-6 group-hover:rotate-90 transition-transform duration-500" /></button>
            </div>
          </div>
        </div>
      </Transition>
    </main>

    <!-- Footer -->
    <footer v-if="appState !== STATES.RECEIVER_ACTIVE" class="px-8 md:px-12 py-10 border-t border-slate-900 flex flex-col lg:flex-row justify-between items-center gap-10">
      <div class="flex items-center gap-4 bg-slate-900/40 p-4 rounded-[1.5rem] border border-slate-800 shadow-xl group cursor-default">
        <div class="w-12 h-12 rounded-2xl bg-slate-950 flex items-center justify-center border border-slate-800 text-amber-500 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.2)] transition-all">
          <User class="w-6 h-6" />
        </div>
        <div class="flex flex-col">
          <span class="text-slate-300 font-black text-[10px] uppercase tracking-widest leading-tight">Lead Architect</span>
          <span class="text-slate-500 text-[10px] font-medium tracking-tight">Senior Solutions Engineer & Author</span>
        </div>
      </div>
      
      <div class="flex flex-wrap justify-center gap-6 md:gap-12 text-[10px] font-black text-slate-600 uppercase tracking-[0.4em]">
        <button @click="activeModal = 'docs'" class="hover:text-amber-500 transition-colors">Documentation</button>
        <button @click="activeModal = 'privacy'" class="hover:text-amber-500 transition-colors">Data Privacy</button>
        <button @click="activeModal = 'source'" class="hover:text-amber-500 transition-colors">Open Source</button>
        <button @click="activeModal = 'contact'" class="hover:text-amber-500 transition-colors">Local Deployment</button>
      </div>
    </footer>

    <!-- Modals Overlay -->
    <Transition name="modal">
      <div v-if="activeModal" class="fixed inset-0 z-[200] flex items-center justify-center p-6 backdrop-blur-xl bg-black/70" @click.self="activeModal = null">
        <div class="w-full max-w-xl bg-slate-900 border border-slate-800 rounded-[3rem] p-8 md:p-12 shadow-[0_0_50px_rgba(0,0,0,0.5)] relative overflow-hidden">
          <button @click="activeModal = null" class="absolute top-8 right-8 p-2 text-slate-500 hover:text-white transition-colors"><X class="w-6 h-6" /></button>
          
          <!-- Modal: Docs -->
          <div v-if="activeModal === 'docs'" class="flex flex-col gap-6 animate-slideUp">
            <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center text-amber-500"><BookOpen class="w-9 h-9" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">How it works</h3>
            <div class="space-y-4 text-slate-400 font-medium text-sm leading-relaxed">
              <p>1. Initiate by clicking <span class="text-white">Broadcast</span>. Select your source: Window, Tab, or Entire Screen.</p>
              <p>2. A <span class="text-white">6-digit node code</span> is assigned to your browser session.</p>
              <p>3. Share this code. The recipient enters it on the <span class="text-white">Receive</span> terminal.</p>
              <p>4. Secure handshake happens, then WebRTC streams media <span class="text-white">directly</span> between you.</p>
            </div>
          </div>

          <!-- Modal: Privacy -->
          <div v-if="activeModal === 'privacy'" class="flex flex-col gap-6 animate-slideUp">
            <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center text-amber-500"><ShieldCheck class="w-9 h-9" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">Privacy Architecture</h3>
            <div class="space-y-4 text-slate-400 font-medium text-sm leading-relaxed">
              <p>CastNow is built with <span class="text-white">Privacy by Design</span>. Media data is never routed through our servers.</p>
              <p>We leverage <span class="text-white">End-to-End P2P Tunnels</span>. Signal packets only contain metadata for connection negotiation. Your stream is yours alone.</p>
            </div>
          </div>

          <!-- Modal: Source -->
          <div v-if="activeModal === 'source'" class="flex flex-col gap-6 animate-slideUp">
            <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center text-amber-500"><Code2 class="w-9 h-9" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">Open Ecosystem</h3>
            <div class="space-y-4 text-slate-400 font-medium text-sm leading-relaxed">
              <p>CastNow empowers the community through open standards. No locked proprietary protocols. Transparent codebases only.</p>
              <div class="pt-6 flex gap-4">
                <a href="https://github.com" target="_blank" class="flex items-center gap-2 bg-slate-800 px-6 py-3 rounded-2xl hover:bg-slate-700 transition-all text-white font-black text-xs uppercase tracking-widest"><Github class="w-4 h-4" /> Source Repository</a>
              </div>
            </div>
          </div>

          <!-- Modal: Local Deployment -->
          <div v-if="activeModal === 'contact'" class="flex flex-col gap-6 text-center animate-slideUp">
            <div class="w-20 h-20 bg-amber-500/10 rounded-3xl flex items-center justify-center text-amber-500 mx-auto shadow-inner"><Layers class="w-10 h-10" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">Local Deployment</h3>
            <p class="text-slate-400 font-medium max-w-sm mx-auto text-sm leading-relaxed">Enterprise-grade localized solutions for internal networks, private P2P clusters, and custom TURN/STUN infrastructure.</p>
            <div class="bg-slate-950 p-6 rounded-3xl border border-slate-800 select-all font-mono text-amber-500 font-black text-lg md:text-xl shadow-inner">
              solutions@castnow.io
            </div>
            <div class="flex flex-wrap items-center justify-center gap-4 text-slate-500 text-[8px] md:text-[9px] font-black uppercase tracking-[0.2em] mt-6">
               <span class="flex items-center gap-1.5"><Activity class="w-3 h-3" /> Dedicated Support</span>
               <span class="w-1 h-1 bg-slate-700 rounded-full"></span>
               <span class="flex items-center gap-1.5"><ShieldAlert class="w-3 h-3" /> Private Cloud</span>
            </div>
            <button @click="activeModal = null" class="mt-8 text-slate-600 hover:text-slate-400 transition-colors text-[9px] font-black uppercase tracking-[0.4em]">Dismiss</button>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1); }
.fade-enter-from, .fade-leave-to { opacity: 0; transform: scale(0.98) translateY(10px); }

.modal-enter-active, .modal-leave-active { transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); }
.modal-enter-from, .modal-leave-to { opacity: 0; backdrop-filter: blur(0px); transform: scale(0.95); }

@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}
.animate-slideUp { animation: slideUp 0.5s cubic-bezier(0.4, 0, 0.2, 1) forwards; }

input { caret-color: transparent; }
:fullscreen video { width: 100vw; height: 100vh; object-fit: contain; }

@media (max-width: 480px) { 
  .text-5xl { font-size: 2rem !important; } 
  .w-14 { width: 2.8rem !important; } 
  .h-16 { height: 3.2rem !important; } 
}
</style>