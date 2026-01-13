
<script setup>
import { ref, onUnmounted, watch, nextTick, computed, onMounted } from 'vue';
import { inject as injectAnalytics } from '@vercel/analytics';
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
  Layers,
  Clock,
  CreditCard,
  Key,
  TrendingUp,
  Timer,
  LogOut,
  Infinity,
  Sparkles
} from 'lucide-vue-next';

// Application States
const STATES = {
  LANDING: 'LANDING',
  SENDER: 'SENDER',
  RECEIVER_INPUT: 'RECEIVER_INPUT',
  RECEIVER_ACTIVE: 'RECEIVER_ACTIVE'
};

// --- Monetization Logic (Production Ready) ---
const FREE_TRIAL_SECONDS = 1800; // 30 Minutes
const GRACE_PERIOD_SECONDS = 300; // 5 Minutes

const timeLeft = ref(FREE_TRIAL_SECONDS);
const graceTimeLeft = ref(GRACE_PERIOD_SECONDS);
const proTimeLeft = ref(null); 
const isGracePeriod = ref(false);
const isPro = ref(false);
const showPaywall = ref(false);
const licenseKeyInput = ref('');
const isVerifying = ref(false);
let timerInterval = null;
let proCountInterval = null;

const formatTime = (seconds) => {
  if (seconds === null || seconds < 0) return '--:--';
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

/**
 * 生产环境验证：所有 Key 必须通过后端 Redis 查询其真实 TTL
 */
const verifyLicense = async (key) => {
  if (!key) return false;
  
  try {
    const response = await fetch('/api/verify-pass', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ licenseKey: key })
    });
    
    if (!response.ok) throw new Error('Security connection failed');
    
    const data = await response.json();
    if (data.valid) {
      isPro.value = true;
      isGracePeriod.value = false;
      proTimeLeft.value = data.expiresIn; 
      localStorage.setItem('castnow_license', key);
      showPaywall.value = false;
      stopTimers();
      startProCountdown();
      return true;
    } else {
      isPro.value = false;
      localStorage.removeItem('castnow_license');
      return false;
    }
  } catch (err) {
    console.error('[Security Check Failed]', err);
    return false;
  }
};

const startProCountdown = () => {
  if (proCountInterval) clearInterval(proCountInterval);
  proCountInterval = setInterval(() => {
    if (proTimeLeft.value > 0) {
      proTimeLeft.value--;
    } else {
      isPro.value = false;
      proTimeLeft.value = null;
      localStorage.removeItem('castnow_license');
      clearInterval(proCountInterval);
      if (appState.value === STATES.SENDER) showPaywall.value = true;
    }
  }, 1000);
};

const stopTimers = () => {
  if (timerInterval) clearInterval(timerInterval);
  timerInterval = null;
};

const handleActivate = async () => {
  if (!licenseKeyInput.value) return;
  isVerifying.value = true;
  error.value = null;
  const success = await verifyLicense(licenseKeyInput.value);
  if (!success) {
    error.value = "Invalid, expired, or used license key.";
  } else {
    error.value = null;
  }
  isVerifying.value = false;
};

const handleDismissPaywall = () => {
  if (isGracePeriod.value && appState.value === STATES.SENDER) {
    if (confirm("Trial has ended. Closing this will immediately disconnect your session. Exit now?")) {
      stopCastingForcefully();
    }
  } else {
    showPaywall.value = false;
  }
};

const startTrialTimer = () => {
  if (timerInterval) clearInterval(timerInterval);
  timerInterval = setInterval(() => {
    if (isPro.value) {
      stopTimers();
      return;
    }

    if (!isGracePeriod.value) {
      if (timeLeft.value > 0) {
        timeLeft.value--;
      } else {
        isGracePeriod.value = true;
        if (appState.value === STATES.SENDER) showPaywall.value = true;
      }
    } else {
      if (graceTimeLeft.value > 0) {
        graceTimeLeft.value--;
      } else {
        stopCastingForcefully();
      }
    }
  }, 1000);
};

const stopCastingForcefully = () => {
  stopTimers();
  resetApp();
  showPaywall.value = false;
  error.value = "Session terminated. Trial limit reached.";
};

onMounted(async () => {
  injectAnalytics();
  const savedKey = localStorage.getItem('castnow_license');
  if (savedKey) {
    await verifyLicense(savedKey);
  }
});

const getIceServers = () => {
  const isChina = () => {
    try {
      const locale = navigator.language || '';
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
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
  stopTimers();
  timeLeft.value = FREE_TRIAL_SECONDS;
  graceTimeLeft.value = GRACE_PERIOD_SECONDS;
  isGracePeriod.value = false;
};

onUnmounted(() => {
  cleanup();
  if (proCountInterval) clearInterval(proCountInterval);
  document.removeEventListener('fullscreenchange', handleFullscreenChange);
});

const handleStartCasting = async () => {
  if (!isPro.value && timeLeft.value <= 0 && graceTimeLeft.value <= 0) {
    showPaywall.value = true;
    return;
  }
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
      if (!isPro.value && !timerInterval) startTrialTimer();
      conn.on('close', () => {
        activeConnections.value = activeConnections.value.filter(c => c !== conn);
        if (activeConnections.value.length === 0) stopTimers();
      });
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
    config: { iceServers: getIceServers(), iceCandidatePoolSize: 10 }
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
        if (!isPro.value) startTrialTimer();
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
    <header v-if="appState !== STATES.RECEIVER_ACTIVE" class="flex items-center justify-between px-6 py-4 md:px-12 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-2 cursor-pointer group" @click="resetApp">
        <div class="w-8 h-8 bg-amber-500 rounded-lg flex items-center justify-center group-hover:rotate-12 transition-transform duration-300 shadow-lg shadow-amber-500/20">
          <Zap class="text-slate-950 w-5 h-5 fill-current" />
        </div>
        <span class="text-xl md:text-2xl font-black tracking-tighter uppercase">CastNow</span>
      </div>
      
      <div class="flex items-center gap-3 md:gap-4">
         <!-- Trial Timer -->
         <div v-if="!isPro" class="flex items-center gap-2 px-3 py-1.5 bg-slate-900 border border-slate-800 rounded-full shadow-lg">
            <Clock class="w-4 h-4 text-amber-500" />
            <span class="text-xs font-black tracking-tighter" :class="isGracePeriod ? 'text-red-500 animate-pulse' : 'text-slate-300'">
              {{ isGracePeriod ? 'Grace Period' : formatTime(timeLeft) }}
            </span>
         </div>

         <!-- Pro Status -->
         <div v-else class="flex items-center gap-2 px-3 py-1.5 bg-amber-500/10 border border-amber-500/30 rounded-full shadow-[0_0_15px_rgba(245,158,11,0.1)] group relative">
            <Zap class="w-4 h-4 text-amber-500 fill-current" />
            <span class="text-[10px] font-black text-amber-500 uppercase tracking-widest">Pro Member</span>
            <div class="absolute -bottom-8 left-1/2 -translate-x-1/2 bg-slate-900 text-[8px] text-slate-400 font-bold px-2 py-0.5 rounded border border-slate-800 opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
              Expires in: {{ formatTime(proTimeLeft) }}
            </div>
         </div>

         <button 
           v-if="!isPro" 
           @click="showPaywall = true" 
           class="flex items-center gap-2 px-4 py-1.5 bg-amber-500 hover:bg-amber-400 text-slate-950 rounded-full font-black text-[10px] uppercase tracking-widest transition-all shadow-lg shadow-amber-500/20 active:scale-95"
           :class="isGracePeriod ? 'animate-bounce bg-red-500 text-white' : 'animate-pulse'"
         >
           <Zap class="w-3 h-3 fill-current" />
           <span class="hidden sm:inline">{{ isGracePeriod ? 'Renew Now' : 'Upgrade' }}</span>
           <span class="sm:hidden">{{ isGracePeriod ? 'Renew' : 'Pro' }}</span>
         </button>

         <div v-if="isConnecting" class="hidden sm:flex items-center gap-2 text-[10px] font-black text-amber-500 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/20 animate-pulse uppercase">
            <Activity class="w-3 h-3" /> Tunneling
         </div>
         <button @click="activeModal = 'contact'" class="px-3 py-1.5 text-[10px] font-black uppercase tracking-widest text-amber-500 border border-amber-500/30 rounded-full hover:bg-amber-500 hover:text-slate-950 transition-all hidden md:block">Business</button>
      </div>
    </header>

    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        <div v-if="appState === STATES.LANDING" key="landing" class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="mb-6 flex items-center gap-2 bg-slate-900/50 px-4 py-1.5 rounded-full border border-slate-800">
            <Globe class="w-3.5 h-3.5 text-amber-500" />
            <span class="text-[9px] font-bold uppercase tracking-[0.2em] text-slate-400">Secure P2P Protocol Engine</span>
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

        <div v-else-if="appState === STATES.SENDER" key="sender" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-2xl bg-slate-900/40 border border-slate-800 rounded-[2.5rem] p-6 md:p-12 text-center backdrop-blur-xl shadow-2xl">
            <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em] mb-6">Channel Key</p>
            <div class="flex flex-wrap items-center justify-center gap-2 mb-10 min-h-[5rem]">
              <div v-if="!peerId" class="flex items-center gap-2 text-amber-500/50">
                <Loader2 class="w-5 h-5 animate-spin" />
                <span class="text-sm font-black uppercase tracking-widest">Generating Tunnel...</span>
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
                <div class="flex items-center gap-2">
                   <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse shadow-[0_0_8px_red]"></div>
                   <p class="text-[10px] font-black text-white tracking-widest uppercase opacity-80">Local Preview</p>
                </div>
                <div v-if="!isPro" class="ml-auto bg-black/60 backdrop-blur px-3 py-1 rounded-full border border-white/10 flex items-center gap-2">
                   <Timer class="w-3 h-3 text-amber-500" />
                   <span class="text-[9px] font-black text-white uppercase" :class="isGracePeriod ? 'text-red-500 animate-pulse' : ''">
                     {{ isGracePeriod ? `Grace Period: ${formatTime(graceTimeLeft)}` : `${formatTime(timeLeft)} Trial` }}
                   </span>
                </div>
                <div v-else class="ml-auto bg-amber-500/20 backdrop-blur px-3 py-1 rounded-full border border-amber-500/30 flex items-center gap-2">
                   <Zap class="w-3 h-3 text-amber-500 fill-current" />
                   <span class="text-[9px] font-black text-white uppercase tracking-tighter">Pro Session Active</span>
                </div>
              </div>
            </div>
            <button @click="resetApp" class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-[10px]">Terminate Session</button>
          </div>
        </div>

        <div v-else-if="appState === STATES.RECEIVER_INPUT" key="input" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-md bg-slate-900/40 border border-slate-800 rounded-[3rem] p-8 md:p-12 text-center shadow-2xl">
            <h2 class="text-3xl font-black mb-2 uppercase tracking-tight">Access Key</h2>
            <p class="text-slate-500 text-sm mb-12 uppercase tracking-widest">Connect to broadcaster</p>
            <div class="relative mb-12">
              <input v-model="inputCode" type="text" maxlength="6" inputmode="numeric" autofocus class="absolute inset-0 w-full h-full opacity-0 cursor-default z-10" @keyup.enter="handleReceiveCast" />
              <div class="flex justify-center gap-2">
                <div v-for="i in 6" :key="i" class="w-10 md:w-14 h-14 md:h-20 bg-slate-950 border-2 rounded-2xl flex items-center justify-center text-3xl md:text-5xl font-black transition-all" :class="inputCode.length >= i ? 'border-amber-500 text-white shadow-lg shadow-amber-500/10 scale-105' : 'border-slate-800 text-slate-800'">{{ inputCode[i-1] || '' }}</div>
              </div>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <button @click="resetApp" class="py-4 bg-slate-800 hover:bg-slate-700 text-white font-black rounded-2xl transition-all uppercase tracking-widest text-[10px]">Cancel</button>
              <button @click="handleReceiveCast" :disabled="inputCode.length !== 6 || isConnecting" class="py-4 font-black rounded-2xl transition-all flex items-center justify-center gap-2 uppercase tracking-widest text-[10px]" :class="inputCode.length === 6 && !isConnecting ? 'bg-amber-500 text-slate-950' : 'bg-slate-800 text-slate-700'">
                <Loader2 v-if="isConnecting" class="w-4 h-4 animate-spin" />
                {{ isConnecting ? 'Linking' : 'Establish Link' }}
              </button>
            </div>
          </div>
        </div>

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
            <div v-if="!isPro" class="absolute bottom-6 left-1/2 -translate-x-1/2 bg-black/60 backdrop-blur-2xl border border-white/10 px-6 py-3 rounded-full flex items-center gap-3 animate-slideUp pointer-events-auto">
               <Clock class="w-4 h-4 text-amber-500" />
               <span class="text-[11px] font-black uppercase tracking-widest text-white">
                 {{ isGracePeriod ? `Broadcaster trial ended. Grace period active.` : `Trial Session: ${formatTime(timeLeft)}` }}
               </span>
            </div>
            <div v-else class="absolute bottom-6 left-1/2 -translate-x-1/2 bg-amber-500/20 backdrop-blur-2xl border border-amber-500/30 px-6 py-3 rounded-full flex items-center gap-3 animate-slideUp pointer-events-auto">
               <Zap class="w-4 h-4 text-amber-500 fill-current" />
               <span class="text-[11px] font-black uppercase tracking-widest text-white">
                 Premium Node | {{ formatTime(proTimeLeft) }} Left
               </span>
            </div>
          </div>
        </div>
      </Transition>
    </main>

    <!-- Paywall Modal (Optimized for Conversion) -->
    <Transition name="modal">
      <div v-if="showPaywall" class="fixed inset-0 z-[300] flex items-center justify-center p-6 backdrop-blur-2xl bg-black/80">
        <div class="w-full max-w-lg bg-slate-900 border border-slate-800 rounded-[3rem] p-8 md:p-12 shadow-[0_0_100px_rgba(245,158,11,0.15)] relative overflow-hidden text-center">
          
          <div v-if="isGracePeriod && appState === STATES.SENDER" class="absolute top-0 left-0 right-0 bg-red-500/20 border-b border-red-500/30 py-3 flex items-center justify-center gap-2 animate-pulse">
            <ShieldAlert class="w-4 h-4 text-red-500" />
            <span class="text-[10px] font-black text-red-500 uppercase tracking-widest">Time Remaining: {{ formatTime(graceTimeLeft) }}</span>
          </div>

          <div class="w-20 h-20 bg-amber-500 rounded-3xl flex items-center justify-center text-slate-950 mx-auto mb-8 shadow-2xl shadow-amber-500/20" :class="(isGracePeriod && appState === STATES.SENDER) ? 'mt-8' : ''">
            <Zap class="w-10 h-10 fill-current" />
          </div>

          <h3 class="text-3xl font-black uppercase tracking-tight mb-4">
            {{ (isGracePeriod && appState === STATES.SENDER) ? 'Activate Full Access' : '24-Hour Premium Pass' }}
          </h3>
          <p class="text-slate-400 font-medium mb-10 text-sm leading-relaxed px-4">
             One-time purchase. Unlock <span class="text-white font-bold">Unlimited Sessions</span> for a full 24 hours. No hidden fees.
          </p>

          <!-- Feature List -->
          <div class="grid grid-cols-2 gap-y-3 gap-x-4 mb-10 text-left px-4">
            <div class="flex items-center gap-2 text-[10px] font-bold text-slate-300 uppercase tracking-widest">
              <Sparkles class="w-3.5 h-3.5 text-amber-500" /> 4K Fidelity
            </div>
            <div class="flex items-center gap-2 text-[10px] font-bold text-slate-300 uppercase tracking-widest">
              <Infinity class="w-3.5 h-3.5 text-amber-500" /> Unlimited Use
            </div>
            <div class="flex items-center gap-2 text-[10px] font-bold text-slate-300 uppercase tracking-widest">
              <Activity class="w-3.5 h-3.5 text-amber-500" /> Zero Latency
            </div>
            <div class="flex items-center gap-2 text-[10px] font-bold text-slate-300 uppercase tracking-widest">
              <Globe class="w-3.5 h-3.5 text-amber-500" /> Global Nodes
            </div>
          </div>
          
          <div class="bg-slate-950 rounded-[2rem] p-6 border border-slate-800 mb-8 mx-4 group cursor-default">
            <div class="text-6xl font-black text-white tracking-tighter mb-2 group-hover:scale-105 transition-transform">$1.90</div>
            <div class="text-[10px] font-black text-amber-500/60 uppercase tracking-[0.3em] mb-6">Full Day Unrestricted Access</div>
            
            <a href="https://gumroad.com/l/ihhtg" target="_blank" class="w-full py-5 bg-amber-500 hover:bg-amber-400 text-slate-950 font-black rounded-2xl transition-all flex items-center justify-center gap-3 uppercase tracking-widest text-xs shadow-lg shadow-amber-500/20 active:scale-95">
              <CreditCard class="w-4 h-4" /> Buy 24h Pass
            </a>
          </div>

          <div class="space-y-4 px-4">
             <div class="relative group">
               <input v-model="licenseKeyInput" type="text" placeholder="Enter License Key" class="w-full bg-slate-950 border border-slate-800 rounded-2xl py-4 px-6 text-sm font-mono placeholder:text-slate-700 focus:border-amber-500 outline-none transition-all" @keyup.enter="handleActivate" />
               <div class="absolute right-2 top-2 bottom-2">
                  <button @click="handleActivate" :disabled="!licenseKeyInput || isVerifying" class="h-full px-6 bg-slate-800 hover:bg-slate-700 disabled:opacity-50 text-white font-black text-[10px] uppercase tracking-widest rounded-xl transition-all">
                    <Loader2 v-if="isVerifying" class="w-3 h-3 animate-spin" />
                    <span v-else>Activate</span>
                  </button>
               </div>
             </div>
             <p v-if="error" class="text-red-400 text-[10px] font-bold uppercase tracking-widest animate-pulse">{{ error }}</p>
          </div>

          <button 
            @click="handleDismissPaywall" 
            class="mt-10 group flex items-center justify-center gap-2 mx-auto text-[9px] font-black uppercase tracking-[0.4em] transition-all"
            :class="(isGracePeriod && appState === STATES.SENDER) ? 'text-red-500 hover:text-red-400' : 'text-slate-600 hover:text-slate-400'"
          >
            <LogOut v-if="isGracePeriod && appState === STATES.SENDER" class="w-3 h-3 group-hover:translate-x-1 transition-transform" />
            {{ (isGracePeriod && appState === STATES.SENDER) ? 'End Session' : 'Continue for now' }}
          </button>

          <p class="mt-4 text-[8px] text-slate-700 font-bold uppercase tracking-[0.2em]">Validated for any device for 24 hours from activation.</p>
        </div>
      </div>
    </Transition>

    <footer v-if="appState !== STATES.RECEIVER_ACTIVE" class="px-8 md:px-12 py-10 border-t border-slate-900 flex flex-col lg:flex-row justify-between items-center gap-10">
      <div class="flex items-center gap-4 bg-slate-900/40 p-4 rounded-[1.5rem] border border-slate-800 shadow-xl group cursor-default">
        <div class="w-12 h-12 rounded-2xl bg-slate-950 flex items-center justify-center border border-slate-800 text-amber-500 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.2)] transition-all">
          <User class="w-6 h-6" />
        </div>
        <div class="flex flex-col">
          <span class="text-slate-300 font-black text-[10px] uppercase tracking-widest leading-tight">Lead Architect</span>
          <span class="text-slate-500 text-[10px] font-medium tracking-tight">Minghua Liu</span>
        </div>
      </div>
      
      <div class="flex flex-wrap justify-center gap-6 md:gap-12 text-[10px] font-black text-slate-600 uppercase tracking-[0.4em]">
        <button @click="activeModal = 'docs'" class="hover:text-amber-500 transition-colors">Documentation</button>
        <button @click="activeModal = 'privacy'" class="hover:text-amber-500 transition-colors">Privacy Policy</button>
        <button @click="activeModal = 'source'" class="hover:text-amber-500 transition-colors">Open Source</button>
        <button @click="activeModal = 'contact'" class="hover:text-amber-500 transition-colors">Enterprise</button>
      </div>
    </footer>

    <Transition name="modal">
      <div v-if="activeModal" class="fixed inset-0 z-[200] flex items-center justify-center p-6 backdrop-blur-xl bg-black/70" @click.self="activeModal = null">
        <div class="w-full max-w-xl bg-slate-900 border border-slate-800 rounded-[3rem] p-8 md:p-12 shadow-[0_0_50px_rgba(0,0,0,0.5)] relative overflow-hidden">
          <button @click="activeModal = null" class="absolute top-8 right-8 p-2 text-slate-500 hover:text-white transition-colors"><X class="w-6 h-6" /></button>
          
          <div v-if="activeModal === 'docs'" class="flex flex-col gap-6 animate-slideUp">
            <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center text-amber-500"><BookOpen class="w-9 h-9" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">Operations Guide</h3>
            <div class="space-y-4 text-slate-400 font-medium text-sm leading-relaxed">
              <p>1. <span class="text-white">Broadcast</span>: Select your source (Tab/Screen) and get a 6-digit key.</p>
              <p>2. <span class="text-white">Connect</span>: Recipient enters the key on their device.</p>
              <p>3. <span class="text-white">P2P Tunnel</span>: Media flows directly browser-to-browser with no relay server.</p>
            </div>
          </div>

          <div v-if="activeModal === 'privacy'" class="flex flex-col gap-6 animate-slideUp">
            <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center text-amber-500"><ShieldCheck class="w-9 h-9" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">Privacy Policy</h3>
            <div class="space-y-4 text-slate-400 font-medium text-sm leading-relaxed">
              <p>We do not store your media streams. No logs. No recordings. Pure WebRTC architecture ensures your data is ephemeral and encrypted.</p>
            </div>
          </div>

          <div v-if="activeModal === 'source'" class="flex flex-col gap-6 animate-slideUp">
            <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center text-amber-500"><Code2 class="w-9 h-9" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">Open Source</h3>
            <div class="space-y-4 text-slate-400 font-medium text-sm leading-relaxed">
              <p>CastNow is open for inspection. Check our official GitHub repository for architecture details and security audits.</p>
            </div>
          </div>

          <div v-if="activeModal === 'contact'" class="flex flex-col gap-6 text-center animate-slideUp">
            <div class="w-20 h-20 bg-amber-500/10 rounded-3xl flex items-center justify-center text-amber-500 mx-auto shadow-inner"><Layers class="w-10 h-10" /></div>
            <h3 class="text-3xl font-black uppercase tracking-tight">Commercial & Private</h3>
            <p class="text-slate-400 font-medium max-w-sm mx-auto text-sm leading-relaxed italic">
              Private on-premise deployments, Docker-based localized infrastructure, and commercial licensing for businesses.
            </p>
            <div class="bg-slate-950 p-8 rounded-3xl border border-slate-800 shadow-inner group transition-all">
              <p class="text-[9px] text-slate-600 font-black uppercase tracking-[0.4em] mb-4">Contact Author</p>
              <a href="mailto:mingh.liu@gmail.com" class="block select-all font-mono text-amber-500 font-black text-xl md:text-2xl hover:scale-105 transition-transform">
                mingh.liu@gmail.com
              </a>
            </div>
            <div class="flex items-center justify-center gap-4 mt-6">
              <span class="flex items-center gap-1 text-[10px] font-bold text-slate-500 uppercase tracking-widest"><ShieldCheck class="w-3.5 h-3.5" /> SLA Guaranteed</span>
              <span class="w-1 h-1 bg-slate-800 rounded-full"></span>
              <span class="flex items-center gap-1 text-[10px] font-bold text-slate-500 uppercase tracking-widest"><Monitor class="w-3.5 h-3.5" /> Docker Support</span>
            </div>
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

input[type="text"].bg-slate-950 {
  caret-color: #f59e0b;
}
</style>
