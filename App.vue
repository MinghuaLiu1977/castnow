
<script setup>
import { ref, onUnmounted, watch, nextTick, computed, onMounted } from 'vue';
import { inject as injectAnalytics } from '@vercel/analytics';
import { 
  Monitor, X, Copy, Check, AlertCircle, Loader2, Camera, Repeat, Info, Activity, Globe, Download, Play, ArrowLeft, Volume2, VolumeX, Maximize, Smartphone, Shield, FileText, Code, ExternalLink, User, RefreshCw
} from 'lucide-vue-next';

const STATES = {
  LANDING: 'LANDING',
  SOURCE_SELECT: 'SOURCE_SELECT',
  SENDER: 'SENDER',
  RECEIVER_INPUT: 'RECEIVER_INPUT',
  RECEIVER_ACTIVE: 'RECEIVER_ACTIVE'
};

const appState = ref(STATES.LANDING);
const castingMode = ref('screen');
const facingMode = ref('user');
const isConnecting = ref(false);
const error = ref(null);
const peerId = ref('');
const peerInstance = ref(null);
const peerError = ref(null); // Dedicated error for PeerJS connection

// Streams
const localStream = ref(null);
const localVideo = ref(null);
const remoteStream = ref(null); // Added: Reactive remote stream
const remoteVideo = ref(null);
const activeConnections = ref([]);

// Receiver Refs
const joinCode = ref('');
// Autoplay policy usually requires muted. Start muted.
const isMuted = ref(true);
const showControls = ref(true);
let controlsTimeout = null;
let peerConnectionTimeout = null;

// Modals
const showPrivacy = ref(false);
const showTerms = ref(false);

// Environment Detection
const isMobile = computed(() => {
  if (typeof navigator === 'undefined') return false;
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
});

const isTouch = computed(() => {
  if (typeof navigator === 'undefined') return false;
  return navigator.maxTouchPoints > 0 || 'ontouchstart' in window;
});

// --- Actions ---
const openPro = () => {
  window.open('https://minghster.gumroad.com/l/ihhtg', '_blank');
};

const openSource = () => {
  window.open('https://github.com/MinghuaLiu1977/castnow', '_blank');
};

// --- WebRTC Core ---
const getIceServers = () => {
  const isChina = () => {
    try {
      const locale = navigator.language || '';
      return locale.toLowerCase().includes('zh');
    } catch (e) { return false; }
  };
  return isChina() 
    ? [{ urls: 'stun:stun.miwifi.com:3478' }, { urls: 'stun:stun.cdn.aliyun.com:3478' }] 
    : [{ urls: 'stun:stun.cloudflare.com:3478' }, { urls: 'stun:stun.l.google.com:19302' }];
};

// Helper for High-Quality Video Constraints
const getVideoConstraints = (facing) => ({
  video: { 
    facingMode: facing,
    width: { ideal: 1920 }, // Request 1080p for sharpness
    height: { ideal: 1080 },
    frameRate: { ideal: 30 }
  },
  audio: true
});

// --- Watchers for Video Elements (Robust Rendering) ---

// 1. Local Video Binding
watch(localVideo, (videoEl) => {
  if (videoEl && localStream.value) {
    videoEl.srcObject = localStream.value;
    videoEl.play().catch(e => console.error("Local preview play error:", e));
  } else if (videoEl) {
    videoEl.srcObject = null;
  }
});
watch(localStream, (newStream) => {
  if (localVideo.value) {
    localVideo.value.srcObject = newStream || null;
    if (newStream) {
      localVideo.value.play().catch(e => console.error("Local preview play error:", e));
    }
  }
});

// 2. Remote Video Binding (Fix for Screen Sharing Black Screen)
watch(remoteVideo, (videoEl) => {
  if (videoEl && remoteStream.value) {
    videoEl.srcObject = remoteStream.value;
    // Ensure muted for mobile autoplay
    videoEl.muted = isMuted.value;
    videoEl.play().catch(e => console.log("Remote autoplay blocked/pending interaction", e));
  } else if (videoEl) {
    videoEl.srcObject = null;
  }
});
watch(remoteStream, (newStream) => {
  if (remoteVideo.value) {
    remoteVideo.value.srcObject = newStream || null;
    if (newStream) {
      remoteVideo.value.muted = isMuted.value;
      remoteVideo.value.play().catch(e => console.log("Remote autoplay blocked/pending interaction", e));
    }
  }
});

// --- Keyboard Event Handling ---
const handleKeydown = (e) => {
  if (appState.value !== STATES.RECEIVER_INPUT) return;

  // Numbers
  if (/^[0-9]$/.test(e.key)) {
    handleDigitInput(e.key);
  }
  // Backspace
  else if (e.key === 'Backspace') {
    handleBackspace();
  }
  // Enter
  else if (e.key === 'Enter') {
    if (joinCode.value.length === 6 && !isConnecting.value) {
      handleJoin();
    }
  }
};

onMounted(() => {
  window.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown);
  resetApp();
});

// --- Sender Logic ---
const initPeerConnection = () => {
  if (peerInstance.value) peerInstance.value.destroy();
  peerError.value = null;
  peerId.value = '';

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Set a timeout to warn user if connection hangs
  if (peerConnectionTimeout) clearTimeout(peerConnectionTimeout);
  peerConnectionTimeout = setTimeout(() => {
    if (!peerId.value) {
      peerError.value = "Connection timed out.";
    }
  }, 15000); // 15s timeout for mobile networks

  const peer = new window.Peer(code, {
    debug: 1,
    pingInterval: 5000, // Keep-alive for mobile
    config: { iceServers: getIceServers() }
  });
  
  peerInstance.value = peer;
  
  peer.on('open', (id) => { 
      console.log('Peer Open:', id);
      if (peerConnectionTimeout) clearTimeout(peerConnectionTimeout);
      peerId.value = id; 
      isConnecting.value = false; 
      peerError.value = null;
  });
  
  peer.on('error', (err) => {
      console.error('Peer Error:', err);
      if (peerConnectionTimeout) clearTimeout(peerConnectionTimeout);

      if (err.type === 'unavailable-id') {
        // Retry automatically with a new ID if collision
        console.log('ID collision, retrying...');
        setTimeout(() => initPeerConnection(), 500);
        return;
      }
      
      if (err.type === 'network' || err.type === 'peer-unavailable' || err.type === 'server-error' || err.type === 'socket-error' || err.type === 'socket-closed') {
         peerError.value = "Network unstable. Retrying...";
      } else {
         peerError.value = "Connection Error.";
      }
      isConnecting.value = false;
  });

  peer.on('connection', (conn) => {
    activeConnections.value.push(conn);
    if (localStream.value) {
       peer.call(conn.peer, localStream.value);
    }
  });
};

const handleStartCasting = async (mode) => {
  // Mobile Screen Share Check
  if (mode === 'screen') {
    if (isMobile.value) {
      error.value = "Screen sharing not supported on mobile.";
      setTimeout(() => error.value = null, 3000);
      return; 
    }
    if (!navigator.mediaDevices || !navigator.mediaDevices.getDisplayMedia) {
      error.value = "Browser not supported.";
      setTimeout(() => error.value = null, 3000);
      return;
    }
  }

  // Stop any existing stream before starting a new one
  if (localStream.value) {
    localStream.value.getTracks().forEach(t => t.stop());
    localStream.value = null;
  }

  castingMode.value = mode;

  try {
    isConnecting.value = true;
    error.value = null;

    let stream = null;
    if (mode === 'screen') {
      stream = await navigator.mediaDevices.getDisplayMedia({ 
        video: { cursor: "always" }, 
        audio: true 
      });
    } else {
      // Use helper for consistent high quality
      stream = await navigator.mediaDevices.getUserMedia(getVideoConstraints(facingMode.value));
    }

    // Check if user canceled operation while waiting for stream
    if (!isConnecting.value) {
      stream.getTracks().forEach(t => t.stop());
      return;
    }

    localStream.value = stream;
    appState.value = STATES.SENDER;
    
    // Initialize PeerJS *after* we have the stream to ensure UI is ready
    initPeerConnection();
    
    stream.getVideoTracks()[0].onended = () => resetApp();

  } catch (err) {
    console.error(err);
    if (err.name === 'NotAllowedError') {
      error.value = null;
      isConnecting.value = false;
      return;
    }
    error.value = "Device access denied or not supported.";
    isConnecting.value = false;
    // Do not reset app here completely, just ensure stream is clear
    if (localStream.value) {
       localStream.value.getTracks().forEach(t => t.stop());
       localStream.value = null;
    }
  }
};

const retryPeerConnection = () => {
  peerError.value = null;
  initPeerConnection();
};

const toggleCamera = async () => {
  if (castingMode.value !== 'camera' || !localStream.value) return;
  
  // Prevent double clicks or race conditions if needed, 
  // but for now simple swap is okay.
  
  const newFacing = facingMode.value === 'user' ? 'environment' : 'user';
  
  try {
    // 1. Stop current tracks explicitly
    localStream.value.getTracks().forEach(track => track.stop());
    
    // 2. Get new stream
    const newStream = await navigator.mediaDevices.getUserMedia(getVideoConstraints(newFacing));
    
    // 3. Update state
    facingMode.value = newFacing;
    localStream.value = newStream;
    
    // 4. Update existing peer connections
    activeConnections.value.forEach(conn => {
       // Replace track in peer connection if supported, or recall
       // PeerJS simplifies this by calling again usually, or we can use replaceTrack if we had direct access to RTCPeerConnection
       // For PeerJS, calling again is the standard way to switch streams in simple scenarios
       peerInstance.value.call(conn.peer, newStream);
    });
  } catch (err) {
    console.error("Camera switch failed", err);
  }
};

// --- Receiver Logic ---
const handleDigitInput = (digit) => {
  if (joinCode.value.length < 6) joinCode.value += digit;
};

const handleBackspace = () => {
  joinCode.value = joinCode.value.slice(0, -1);
};

const handleJoin = () => {
  if (joinCode.value.length !== 6) return;
  
  isConnecting.value = true;
  error.value = null;

  const peer = new window.Peer({
    config: { iceServers: getIceServers() }
  });
  
  peerInstance.value = peer;

  peer.on('open', () => {
    const conn = peer.connect(joinCode.value);
    
    conn.on('open', () => {
      console.log("Connected to broadcaster signaling");
      appState.value = STATES.RECEIVER_ACTIVE;
      isConnecting.value = false;
    });

    conn.on('error', (err) => {
      console.error("Connection Error", err);
      error.value = "Connection failed. Check code.";
      isConnecting.value = false;
    });
    
    // Auto close if broadcaster leaves (removed alert)
    conn.on('close', () => {
        resetApp();
    });
  });

  peer.on('call', (call) => {
    call.answer(); 
    call.on('stream', (stream) => {
      // Use reactive variable to trigger watcher
      remoteStream.value = stream;
    });
  });

  peer.on('error', (err) => {
    console.error(err);
    error.value = "Invalid Code or Connection Error";
    isConnecting.value = false;
    joinCode.value = '';
  });
};

const toggleMute = () => {
  if (remoteVideo.value) {
    remoteVideo.value.muted = !remoteVideo.value.muted;
    isMuted.value = remoteVideo.value.muted;
  }
};

const toggleFullscreen = () => {
  if (!document.fullscreenElement && remoteVideo.value) {
    remoteVideo.value.parentElement.requestFullscreen().catch(err => console.log(err));
  } else {
    document.exitFullscreen();
  }
};

const handleMouseMove = () => {
  showControls.value = true;
  if (controlsTimeout) clearTimeout(controlsTimeout);
  controlsTimeout = setTimeout(() => {
    showControls.value = false;
  }, 3000);
};

// --- Shared ---
const resetApp = () => {
  // 1. Clear Timeouts
  if (peerConnectionTimeout) clearTimeout(peerConnectionTimeout);
  
  // 2. Stop Local Stream Tracks (CRITICAL for removing camera icon)
  if (localStream.value) {
    localStream.value.getTracks().forEach(t => t.stop());
    localStream.value = null;
  }
  
  // 3. Clear Video Elements
  if (localVideo.value) localVideo.value.srcObject = null;
  if (remoteVideo.value) remoteVideo.value.srcObject = null;

  // 4. Destroy Peer
  if (peerInstance.value) {
    peerInstance.value.destroy();
    peerInstance.value = null;
  }
  
  // 5. Reset State
  appState.value = STATES.LANDING;
  peerId.value = '';
  remoteStream.value = null;
  activeConnections.value = [];
  joinCode.value = '';
  isConnecting.value = false;
  error.value = null;
  peerError.value = null;
};
</script>

<template>
  <div class="min-h-[100dvh] flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30">
    <header v-if="appState !== STATES.RECEIVER_ACTIVE" class="flex items-center justify-between px-6 py-4 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-3 cursor-pointer group" @click="resetApp">
        <!-- Logo Icon -->
        <img src="/icon.svg" alt="CastNow" class="w-10 h-10 rounded-xl shadow-lg shadow-amber-500/10 group-hover:scale-105 transition-transform duration-300" />
        <span class="text-xl font-black uppercase tracking-tighter italic bg-gradient-to-r from-slate-100 to-slate-400 bg-clip-text text-transparent pr-2">CastNow</span>
      </div>
      <div class="flex items-center gap-2">
        <button @click="openPro" class="hidden md:flex px-3 py-1 bg-amber-500/10 hover:bg-amber-500/20 text-amber-500 border border-amber-500/20 rounded-full items-center gap-2 text-[10px] font-bold uppercase tracking-tighter transition-all mr-2">
            <span>Get Pro</span>
        </button>
        <div class="px-3 py-1 bg-slate-900 rounded-full border border-slate-800 flex items-center gap-2">
           <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
           <span class="text-[10px] font-bold uppercase tracking-tighter">P2P Secure</span>
        </div>
      </div>
    </header>

    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        <!-- Landing -->
        <div v-if="appState === STATES.LANDING" class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="mb-4 px-4 py-1 bg-amber-500/10 border border-amber-500/20 rounded-full flex items-center gap-2">
            <Globe class="w-3 h-3 text-amber-500" />
            <span class="text-[10px] font-black uppercase text-amber-500 tracking-widest">Secure P2P Protocol Engine</span>
          </div>
          <h1 class="text-6xl md:text-8xl font-black mb-6 tracking-tighter leading-none">Instant<br/><span class="text-amber-500">Casting.</span></h1>
          <p class="text-slate-500 max-w-xs mb-10 text-sm font-medium italic">No plugins. No latency. Pure P2P screen sharing for mobile & desktop.</p>
          
          <div class="flex flex-col gap-4 w-full max-w-xs">
            <button @click="appState = STATES.SOURCE_SELECT" class="group relative py-6 bg-amber-500 text-slate-950 rounded-3xl font-black text-xl uppercase shadow-xl shadow-amber-500/20 active:scale-95 transition-all overflow-hidden">
              <span class="relative z-10">Broadcast</span>
              <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform"></div>
            </button>
            <button @click="appState = STATES.RECEIVER_INPUT" class="py-6 bg-slate-900 border border-slate-800 rounded-3xl font-black text-xl uppercase active:scale-95 transition-all flex items-center justify-center gap-3 hover:border-slate-700">
              <Download class="w-6 h-6" />
              Receive
            </button>
          </div>
          
          <div class="mt-auto pb-6 flex flex-col items-center gap-4 pt-10">
            <div class="flex items-center gap-8 text-slate-600 font-bold text-[10px] uppercase tracking-[0.2em]">
               <button @click="openSource" class="hover:text-amber-500 transition-colors">Source</button>
               <button @click="showPrivacy = true" class="hover:text-amber-500 transition-colors">Privacy</button>
               <button @click="showTerms = true" class="hover:text-amber-500 transition-colors">Terms</button>
            </div>
            <div class="text-slate-700 text-[10px] font-medium flex items-center gap-1">
               <span>Designed by</span>
               <span class="text-slate-500">Matthew Liu</span>
            </div>
          </div>
        </div>

        <!-- Source Selection -->
        <div v-else-if="appState === STATES.SOURCE_SELECT" class="flex-1 flex flex-col items-center justify-center p-6">
           <h2 class="text-2xl font-black uppercase mb-12 tracking-widest flex items-center gap-3">
             <span class="w-8 h-[2px] bg-amber-500"></span>
             Choose Source
             <span class="w-8 h-[2px] bg-amber-500"></span>
           </h2>
           <div class="grid grid-cols-1 gap-4 w-full max-w-sm">
              <button @click="handleStartCasting('screen')" :class="{'opacity-50 cursor-not-allowed': isMobile}" class="flex items-center gap-6 p-6 bg-slate-900 border border-slate-800 rounded-[2rem] hover:border-amber-500 transition-all group text-left relative overflow-hidden">
                <div class="w-16 h-16 bg-slate-950 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform">
                  <Monitor class="w-8 h-8 text-amber-500" />
                </div>
                <div>
                  <span class="block font-black uppercase tracking-widest text-lg">Screen Share</span>
                  <p class="text-[10px] text-slate-500 uppercase font-bold mt-1">
                    {{ isMobile ? 'Not Supported on Mobile' : 'System Mirroring' }}
                  </p>
                </div>
              </button>
              
              <button @click="handleStartCasting('camera')" class="flex items-center gap-6 p-6 bg-slate-900 border border-slate-800 rounded-[2rem] hover:border-amber-500 transition-all group text-left">
                <div class="w-16 h-16 bg-slate-950 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform">
                  <Camera class="w-8 h-8 text-amber-500" />
                </div>
                <div>
                  <span class="block font-black uppercase tracking-widest text-lg">Camera</span>
                  <p class="text-[10px] text-slate-500 uppercase font-bold mt-1">Mobile Broadcast</p>
                </div>
              </button>
           </div>
           
           <!-- Error Toast Area -->
           <div v-if="error" class="mt-6 px-4 py-2 bg-red-500/10 border border-red-500/20 text-red-500 rounded-full text-xs font-bold uppercase tracking-widest animate-pulse">
             {{ error }}
           </div>

           <button @click="resetApp" class="mt-12 text-slate-500 font-black uppercase tracking-widest text-[10px] hover:text-white transition-colors">← Cancel Operation</button>
        </div>

        <!-- Sender View -->
        <div v-else-if="appState === STATES.SENDER" class="flex-1 flex flex-col items-center justify-center p-4">
          <div class="w-full max-w-xl bg-slate-900 border border-slate-800 rounded-[3rem] p-8 text-center relative overflow-hidden shadow-2xl">
            <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-amber-500 to-transparent animate-pulse"></div>
            
            <div class="flex items-center justify-between mb-8">
               <div class="flex items-center gap-2">
                 <Activity class="w-4 h-4 text-amber-500" />
                 <span class="text-[10px] font-black text-slate-500 uppercase tracking-widest">Active Tunnel</span>
               </div>
               <button v-if="castingMode === 'camera'" @click="toggleCamera" class="flex items-center gap-2 px-3 py-1.5 bg-slate-800 rounded-full hover:bg-amber-500 hover:text-slate-950 transition-all">
                  <Repeat class="w-3 h-3" />
                  <span class="text-[10px] font-black uppercase">{{ facingMode === 'user' ? 'Front' : 'Back' }}</span>
               </button>
            </div>
            
            <div class="mb-10">
              <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] mb-4">Sharing Access Key</p>
              
              <!-- Connection State Handler -->
              <div v-if="!peerId && !peerError" class="flex items-center justify-center gap-2">
                 <!-- Loading Skeleton -->
                 <div v-for="n in 6" :key="n" class="w-12 h-16 bg-slate-950 rounded-2xl border border-slate-800 animate-pulse"></div>
              </div>
              
              <div v-else-if="peerError" class="flex flex-col items-center gap-3">
                 <p class="text-red-500 font-bold uppercase text-xs">{{ peerError }}</p>
                 <button @click="retryPeerConnection" class="flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-400 text-slate-950 rounded-full font-bold text-xs uppercase tracking-widest transition-all">
                    <RefreshCw class="w-3 h-3" /> Retry
                 </button>
              </div>

              <div v-else class="flex items-center justify-center gap-2">
                 <template v-for="(char, i) in peerId.split('')" :key="i">
                    <span class="text-4xl md:text-6xl font-black bg-slate-950 w-12 md:w-16 h-16 md:h-24 flex items-center justify-center rounded-2xl border border-slate-800 text-amber-500 shadow-inner">{{ char }}</span>
                    <span v-if="i === 2" class="text-slate-800 font-black text-2xl">-</span>
                  </template>
              </div>
            </div>

            <div class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative mb-8 group shadow-inner">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-cover" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
              <div class="absolute bottom-4 left-6 flex items-center gap-3">
                <div class="w-2 h-2 bg-red-500 rounded-full animate-ping"></div>
                <span class="text-[10px] font-black uppercase tracking-widest">{{ castingMode === 'screen' ? 'Desktop Mirror' : 'Camera Feed' }}</span>
              </div>
            </div>
            
            <button @click="resetApp" class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-xs">Terminate Stream</button>
          </div>
        </div>

        <!-- Receiver Input -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT" class="flex-1 flex flex-col items-center justify-center p-6">
           <h2 class="text-2xl font-black uppercase mb-8 tracking-widest flex items-center gap-3 whitespace-nowrap">
             <span class="w-8 h-[2px] bg-amber-500"></span>
             Enter Access Key
             <span class="w-8 h-[2px] bg-amber-500"></span>
           </h2>

           <!-- Display -->
           <div class="mb-6 flex gap-2 h-20 md:h-24">
              <div v-for="i in 6" :key="i" class="w-12 md:w-16 bg-slate-900 border border-slate-800 rounded-2xl flex items-center justify-center text-3xl md:text-4xl font-black text-white shadow-inner transition-colors duration-200" :class="{'border-amber-500/50 text-amber-500': joinCode[i-1], 'animate-pulse bg-slate-800/50': joinCode.length === i-1}">
                {{ joinCode[i-1] || '' }}
              </div>
           </div>
           
           <div v-if="!isTouch" class="mb-8 text-slate-500 text-sm font-medium animate-pulse">
             Type code on keyboard...
           </div>

           <!-- Touch Keypad (Only on Touch Devices) -->
           <div v-if="isTouch" class="grid grid-cols-3 gap-3 w-full max-w-[280px] mb-6">
              <button v-for="n in 9" :key="n" @click="handleDigitInput(n.toString())" class="h-14 rounded-2xl bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">
                {{ n }}
              </button>
              <button @click="resetApp" class="h-14 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
                 <X class="w-6 h-6" />
              </button>
              <button @click="handleDigitInput('0')" class="h-14 rounded-2xl bg-slate-950 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">0</button>
              <button @click="handleBackspace" class="h-14 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
                 <ArrowLeft class="w-6 h-6" />
              </button>
           </div>
           
           <button @click="handleJoin" :disabled="joinCode.length !== 6 || isConnecting" class="w-full max-w-[280px] py-5 bg-amber-500 disabled:bg-slate-800 disabled:text-slate-600 text-slate-950 font-black rounded-2xl text-lg uppercase tracking-widest shadow-xl shadow-amber-500/20 active:scale-95 transition-all flex items-center justify-center gap-2">
             <Loader2 v-if="isConnecting" class="w-5 h-5 animate-spin" />
             <span v-else>Connect Now</span>
           </button>
           
           <p v-if="error" class="mt-4 text-red-500 text-xs font-bold uppercase tracking-widest flex items-center gap-2">
             <AlertCircle class="w-4 h-4" /> {{ error }}
           </p>
        </div>

        <!-- Receiver Active -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE" class="fixed inset-0 bg-black flex items-center justify-center" @mousemove="handleMouseMove" @touchstart="handleMouseMove">
           <video ref="remoteVideo" autoplay playsinline :muted="isMuted" class="w-full h-full object-contain" />
           
           <!-- Overlay Controls -->
           <div class="absolute inset-0 bg-gradient-to-b from-black/60 via-transparent to-black/60 transition-opacity duration-300 pointer-events-none" :class="{'opacity-0': !showControls}"></div>
           
           <div class="absolute top-6 left-6 transition-opacity duration-300 z-10" :class="{'opacity-0': !showControls}">
              <button @click="resetApp" class="flex items-center gap-2 px-4 py-2 bg-white/10 backdrop-blur-md rounded-full text-white/90 hover:bg-white/20 transition-all font-bold text-sm">
                <ArrowLeft class="w-4 h-4" /> Leave
              </button>
           </div>

           <div class="absolute bottom-10 left-0 w-full px-8 flex items-end justify-between transition-opacity duration-300 z-10" :class="{'opacity-0': !showControls}">
              <div>
                <div class="flex items-center gap-2 mb-2">
                   <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
                   <span class="text-red-500 text-[10px] font-black uppercase tracking-widest">Live Feed</span>
                </div>
                <h3 class="text-white font-bold text-lg">P2P Secure Stream</h3>
              </div>
              
              <div class="flex items-center gap-4">
                 <button @click="toggleMute" class="p-3 bg-white/10 backdrop-blur-md rounded-full text-white hover:bg-white/20 transition-all active:scale-95">
                   <VolumeX v-if="isMuted" class="w-6 h-6" />
                   <Volume2 v-else class="w-6 h-6" />
                 </button>
                 <button @click="toggleFullscreen" class="p-3 bg-white/10 backdrop-blur-md rounded-full text-white hover:bg-white/20 transition-all active:scale-95">
                   <Maximize class="w-6 h-6" />
                 </button>
              </div>
           </div>
        </div>
      </Transition>

      <!-- Modals (Privacy & Terms) -->
      <Transition name="fade">
        <div v-if="showPrivacy" class="fixed inset-0 z-[60] bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-6">
           <div class="bg-slate-900 border border-slate-800 p-8 rounded-3xl max-w-lg w-full relative">
              <button @click="showPrivacy = false" class="absolute top-4 right-4 text-slate-500 hover:text-white"><X class="w-6 h-6" /></button>
              <div class="flex items-center gap-3 mb-6">
                <Shield class="w-8 h-8 text-amber-500" />
                <h2 class="text-2xl font-black uppercase">Privacy Policy</h2>
              </div>
              <div class="space-y-4 text-slate-400 text-sm leading-relaxed h-64 overflow-y-auto pr-2 custom-scrollbar">
                <p><strong>1. Zero Data Collection:</strong> CastNow operates on a strictly peer-to-peer basis. Your video and audio streams are encrypted and transmitted directly between your device and the receiver's device. No stream data passes through or is stored on our servers.</p>
                <p><strong>2. Connection Metadata:</strong> To establish a connection, a temporary signaling handshake occurs. This involves exchanging random connection tokens. This data is ephemeral and discarded immediately after connection.</p>
                <p><strong>3. Local Processing:</strong> All media processing (encoding, rendering) happens locally on your device.</p>
                <p><strong>4. No Accounts:</strong> We do not require sign-ups, emails, or personal information.</p>
              </div>
           </div>
        </div>
      </Transition>

      <Transition name="fade">
        <div v-if="showTerms" class="fixed inset-0 z-[60] bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-6">
           <div class="bg-slate-900 border border-slate-800 p-8 rounded-3xl max-w-lg w-full relative">
              <button @click="showTerms = false" class="absolute top-4 right-4 text-slate-500 hover:text-white"><X class="w-6 h-6" /></button>
              <div class="flex items-center gap-3 mb-6">
                <FileText class="w-8 h-8 text-amber-500" />
                <h2 class="text-2xl font-black uppercase">Terms of Service</h2>
              </div>
              <div class="space-y-4 text-slate-400 text-sm leading-relaxed h-64 overflow-y-auto pr-2 custom-scrollbar">
                <p><strong>1. Usage:</strong> CastNow is provided "as is" for personal and commercial use. You agree not to use this service for illegal activities or to stream content you do not own rights to.</p>
                <p><strong>2. Liability:</strong> The creators of CastNow are not liable for any damages arising from the use or inability to use the service.</p>
                <p><strong>3. Availability:</strong> While we strive for 99.9% uptime, we do not guarantee uninterrupted service.</p>
                <p><strong>4. Changes:</strong> We reserve the right to update these terms at any time.</p>
              </div>
           </div>
        </div>
      </Transition>

    </main>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1); }
.fade-enter-from { opacity: 0; transform: translateY(10px); }
.fade-leave-to { opacity: 0; transform: translateY(-10px); }

.custom-scrollbar::-webkit-scrollbar {
  width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: rgba(30, 41, 59, 0.5); 
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background: rgba(245, 158, 11, 0.5); 
  border-radius: 10px;
}
</style>
