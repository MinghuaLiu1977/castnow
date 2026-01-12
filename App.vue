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
  Loader2
} from 'lucide-vue-next';

// App States
const STATES = {
  LANDING: 'LANDING',
  SENDER: 'SENDER',
  RECEIVER_INPUT: 'RECEIVER_INPUT',
  RECEIVER_ACTIVE: 'RECEIVER_ACTIVE'
};

// PeerJS Configuration with multiple public STUN servers for better NAT traversal
const PEER_CONFIG = {
  debug: 2,
  config: {
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
      { urls: 'stun:stun2.l.google.com:19302' },
      { urls: 'stun:stun3.l.google.com:19302' },
      { urls: 'stun:stun4.l.google.com:19302' },
      { urls: 'stun:stun.services.mozilla.com' },
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

const peerInstance = ref(null);
const localStream = ref(null);
const remoteStream = ref(null);

const localVideo = ref(null);
const remoteVideo = ref(null);

// Cleanup function to release resources
const cleanup = () => {
  console.log('[CastNow] Starting cleanup sequence...');
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
  isConnecting.value = false;
  console.log('[CastNow] Cleanup completed.');
};

onUnmounted(cleanup);

// Watchers to bind streams to video elements
watch(localStream, async (stream) => {
  if (stream) {
    await nextTick();
    if (localVideo.value) {
      console.log('[CastNow] Local stream bound to video element.');
      localVideo.value.srcObject = stream;
    }
  }
});

watch(remoteStream, async (stream) => {
  if (stream) {
    await nextTick();
    if (remoteVideo.value) {
      console.log('[CastNow] Remote stream bound to video element.');
      remoteVideo.value.srcObject = stream;
    }
  }
});

const generateCode = () => Math.floor(100000 + Math.random() * 900000).toString();

const copyToClipboard = () => {
  if (!peerId.value) return;
  navigator.clipboard.writeText(peerId.value);
  isCopied.value = true;
  setTimeout(() => isCopied.value = false, 2000);
};

// SENDER LOGIC
const handleStartCasting = async () => {
  try {
    console.log('[CastNow] Initiating screen capture...');
    isConnecting.value = true;
    error.value = null;

    const stream = await navigator.mediaDevices.getDisplayMedia({
      video: { cursor: "always", frameRate: 30 },
      audio: {
        echoCancellation: true,
        noiseSuppression: true
      }
    });
    console.log('[CastNow] Screen share granted. Stream ID:', stream.id);
    
    localStream.value = stream;
    const code = generateCode();
    
    console.log('[CastNow] Initializing Peer (Sender) with Code:', code);
    const peer = new window.Peer(code, PEER_CONFIG);
    peerInstance.value = peer;

    peer.on('open', (id) => {
      console.log('[CastNow] Sender online and registered with server. ID:', id);
      peerId.value = id;
      appState.value = STATES.SENDER;
      isConnecting.value = false;
    });

    peer.on('call', (call) => {
      console.log('[CastNow] Inbound call from peer:', call.peer);
      call.answer(stream);
      console.log('[CastNow] Answered call. Establishing P2P stream...');
      
      call.on('error', (err) => console.error('[CastNow] Call object error:', err));
      call.on('close', () => {
        console.log('[CastNow] Receiver disconnected.');
      });
    });

    peer.on('disconnected', () => {
      console.warn('[CastNow] Peer server connection lost. Reconnecting...');
      peer.reconnect();
    });

    peer.on('error', (err) => {
      console.error('[CastNow] PeerJS Error:', err.type, err);
      if (err.type === 'unavailable-id') {
        error.value = 'Code conflict. Retrying...';
        handleStartCasting();
      } else {
        error.value = `Protocol error: ${err.type}`;
        cleanup();
        appState.value = STATES.LANDING;
      }
    });

    // Handle user clicking "Stop Sharing" in browser UI
    stream.getVideoTracks()[0].onended = () => {
      console.log('[CastNow] Stream manually stopped by user.');
      resetApp();
    };

  } catch (err) {
    console.error('[CastNow] Media capture failed:', err);
    error.value = 'Failed to access screen. Check browser permissions.';
    isConnecting.value = false;
  }
};

// RECEIVER LOGIC
const handleReceiveCast = () => {
  if (inputCode.value.length !== 6) {
    error.value = 'Please enter a valid 6-digit code.';
    return;
  }

  console.log('[CastNow] Connecting as Receiver to code:', inputCode.value);
  isConnecting.value = true;
  error.value = null;

  const peer = new window.Peer(PEER_CONFIG);
  peerInstance.value = peer;

  peer.on('open', (id) => {
    console.log('[CastNow] Receiver Peer ready. Temporary ID:', id);
    console.log('[CastNow] Calling Sender...');
    
    // We send a minimal MediaStream to initiate handshake
    const call = peer.call(inputCode.value, new MediaStream());
    
    const timeout = setTimeout(() => {
      if (appState.value !== STATES.RECEIVER_ACTIVE) {
        console.error('[CastNow] Connection timeout (15s). Handshake failed.');
        error.value = 'Connection timed out. NAT/Firewall might be blocking the stream.';
        isConnecting.value = false;
        cleanup();
        appState.value = STATES.RECEIVER_INPUT;
      }
    }, 15000);

    call.on('stream', (stream) => {
      console.log('[CastNow] Success! Remote stream received. Tracks:', stream.getTracks().length);
      clearTimeout(timeout);
      remoteStream.value = stream;
      appState.value = STATES.RECEIVER_ACTIVE;
      isConnecting.value = false;
    });

    call.on('error', (err) => {
      console.error('[CastNow] Call error:', err);
      error.value = 'P2P negotiation failed.';
      isConnecting.value = false;
      clearTimeout(timeout);
    });
  });

  peer.on('error', (err) => {
    console.error('[CastNow] Receiver Peer Error:', err.type);
    if (err.type === 'peer-unavailable') {
      error.value = 'Invalid code. Sender might be offline.';
    } else {
      error.value = `Connection error: ${err.type}`;
    }
    isConnecting.value = false;
  });
};

const resetApp = () => {
  console.log('[CastNow] Application reset triggered.');
  cleanup();
  appState.value = STATES.LANDING;
};
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30">
    <!-- Header -->
    <header class="flex items-center justify-between px-6 py-4 md:px-12 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-2 cursor-pointer group" @click="resetApp">
        <div class="w-8 h-8 bg-amber-500 rounded-lg flex items-center justify-center group-hover:rotate-12 transition-transform duration-300 shadow-lg shadow-amber-500/20">
          <Zap class="text-slate-950 w-5 h-5 fill-current" />
        </div>
        <span class="text-2xl font-extrabold tracking-tighter uppercase">CastNow</span>
      </div>
      <div class="flex items-center gap-4">
        <button class="px-4 py-1.5 text-xs font-bold uppercase tracking-widest text-amber-500 border border-amber-500/30 rounded-full hover:bg-amber-500/10 transition-all hover:scale-105 active:scale-95">
          Pro
        </button>
      </div>
    </header>

    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        <!-- Landing Section -->
        <div v-if="appState === STATES.LANDING" key="landing" class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="mb-6 inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-500 text-xs font-black uppercase tracking-[0.2em]">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
            </span>
            Real-Time P2P
          </div>
          <h1 class="text-5xl md:text-8xl font-black mb-8 tracking-tighter leading-[0.9]">
            No installs. <br class="hidden md:block" />
            No sign-ups. <br />
            <span class="text-amber-500">Just cast.</span>
          </h1>
          <p class="text-slate-400 text-lg md:text-xl mb-12 max-w-2xl font-medium leading-relaxed">
            Minimalist screen sharing for the modern web. <br class="hidden md:block" />
            Zero latency, total privacy, absolute speed.
          </p>

          <div class="grid md:grid-cols-2 gap-6 w-full max-w-3xl px-4">
            <button @click="handleStartCasting" :disabled="isConnecting" class="group flex flex-col items-center justify-center p-10 md:p-14 bg-amber-500 hover:bg-amber-400 rounded-[2.5rem] transition-all duration-500 shadow-2xl shadow-amber-500/10 hover:-translate-y-2 active:scale-95 disabled:opacity-50">
              <Monitor v-if="!isConnecting" class="w-14 h-14 md:w-16 md:h-16 text-slate-950 mb-6 group-hover:scale-110 transition-transform duration-500" />
              <Loader2 v-else class="w-14 h-14 md:w-16 md:h-16 text-slate-950 mb-6 animate-spin" />
              <span class="text-slate-950 font-black text-2xl md:text-3xl tracking-tight">Start Casting</span>
              <span class="text-slate-900/60 font-bold text-xs md:text-sm mt-2">Broadcast your screen</span>
            </button>
            <button @click="appState = STATES.RECEIVER_INPUT" class="group flex flex-col items-center justify-center p-10 md:p-14 bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-[2.5rem] transition-all duration-500 hover:-translate-y-2 active:scale-95">
              <Download class="w-14 h-14 md:w-16 md:h-16 text-amber-500 mb-6 group-hover:scale-110 transition-transform duration-500" />
              <span class="text-white font-black text-2xl md:text-3xl tracking-tight">Receive Cast</span>
              <span class="text-slate-500 font-bold text-xs md:text-sm mt-2">Watch a live session</span>
            </button>
          </div>

          <div v-if="error" class="mt-8 flex items-center gap-2 text-red-400 font-bold bg-red-400/10 px-6 py-3 rounded-2xl border border-red-400/20 text-sm md:text-base animate-pulse">
            <AlertCircle class="w-5 h-5" />
            {{ error }}
          </div>
        </div>

        <!-- Sender Interface -->
        <div v-else-if="appState === STATES.SENDER" key="sender" class="flex-1 flex flex-col items-center justify-center p-6">
          <div class="w-full max-w-2xl bg-slate-900/50 border border-slate-800 rounded-[3rem] p-8 md:p-12 text-center shadow-2xl backdrop-blur-sm">
            <h2 class="text-slate-500 font-black text-xs md:text-sm mb-6 tracking-[0.3em] uppercase">Broadcast Session Code</h2>
            <div class="flex items-center justify-center gap-2 md:gap-4 mb-10 relative group px-2">
              <template v-for="(char, i) in peerId.split('')" :key="i">
                <span class="text-4xl md:text-7xl font-black text-white bg-slate-950 w-12 md:w-20 py-4 md:py-6 rounded-2xl border border-slate-800 shadow-inner group-hover:border-amber-500/50 transition-colors">
                  {{ char }}
                </span>
                <span v-if="i === 2" class="text-2xl text-slate-700 font-bold mx-0.5">-</span>
              </template>
              <button @click="copyToClipboard" class="absolute -right-4 md:-right-16 p-3 md:p-4 rounded-full bg-slate-800 hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-90 shadow-lg">
                <Check v-if="isCopied" class="w-5 h-5 md:w-6 md:h-6" />
                <Copy v-else class="w-5 h-5 md:w-6 md:h-6" />
              </button>
            </div>
            <div class="aspect-video bg-slate-950 rounded-3xl border border-slate-800 overflow-hidden mb-10 shadow-inner">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-contain" />
            </div>
            <button @click="resetApp" class="px-8 md:px-12 py-4 md:py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-xs md:text-sm">
              Stop Broadcast
            </button>
          </div>
        </div>

        <!-- Receiver Input Interface -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT" key="input" class="flex-1 flex flex-col items-center justify-center p-6">
          <div class="w-full max-w-lg bg-slate-900/50 border border-slate-800 rounded-[3rem] p-8 md:p-12 text-center shadow-2xl backdrop-blur-sm">
            <h2 class="text-3xl md:text-4xl font-black text-white mb-4 tracking-tighter uppercase">Enter Cast Code</h2>
            <p class="text-slate-400 mb-10 font-medium">Connect to the broadcast with the 6-digit code</p>
            
            <div class="relative mb-10 group">
              <input v-model="inputCode" type="text" maxlength="6" placeholder="000000" class="w-full bg-slate-950 border-4 border-slate-800 focus:border-amber-500/50 rounded-3xl px-6 py-6 md:py-8 text-4xl md:text-6xl font-black tracking-[0.3em] md:tracking-[0.5em] text-center text-white outline-none transition-all placeholder:text-slate-900 shadow-inner" @keyup.enter="handleReceiveCast" />
              <div class="absolute inset-0 rounded-3xl pointer-events-none group-focus-within:ring-4 ring-amber-500/10 transition-all"></div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <button @click="appState = STATES.LANDING" class="px-6 py-4 md:py-6 bg-slate-800 hover:bg-slate-700 text-white font-black rounded-2xl transition-all uppercase tracking-widest text-xs md:text-sm">Cancel</button>
              <button @click="handleReceiveCast" :disabled="inputCode.length !== 6 || isConnecting" class="px-6 py-4 md:py-6 font-black rounded-2xl transition-all shadow-xl shadow-amber-500/10 flex items-center justify-center gap-2 uppercase tracking-widest text-xs md:text-sm" :class="inputCode.length === 6 && !isConnecting ? 'bg-amber-500 text-slate-950 hover:bg-amber-400' : 'bg-slate-800 text-slate-600 cursor-not-allowed'">
                <Loader2 v-if="isConnecting" class="w-4 h-4 md:w-5 md:h-5 animate-spin" />
                {{ isConnecting ? 'Linking' : 'Join' }}
              </button>
            </div>

            <div v-if="error" class="mt-8 flex items-center justify-center gap-2 text-red-400 font-bold text-xs md:text-sm">
              <AlertCircle class="w-4 h-4" />
              {{ error }}
            </div>
          </div>
        </div>

        <!-- Fullscreen Video View -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE" key="active" class="fixed inset-0 bg-black z-[100] flex items-center justify-center overflow-hidden">
          <video ref="remoteVideo" autoplay playsinline class="w-full h-full object-contain" />
          
          <!-- UI Overlay -->
          <div class="absolute top-6 left-6 md:top-10 md:left-10 flex items-center gap-4 bg-black/60 backdrop-blur-2xl px-5 py-2.5 rounded-full border border-white/10 shadow-2xl">
            <div class="w-2.5 h-2.5 bg-red-500 rounded-full animate-pulse shadow-[0_0_12px_rgba(239,68,68,0.6)]"></div>
            <span class="text-[10px] font-black text-white uppercase tracking-[0.2em]">Live Session</span>
          </div>

          <button @click="resetApp" class="absolute top-6 right-6 md:top-10 md:right-10 w-12 h-12 md:w-16 md:h-16 flex items-center justify-center bg-white/10 hover:bg-red-500 backdrop-blur-2xl rounded-full text-white transition-all group border border-white/10 shadow-2xl">
            <X class="w-6 h-6 md:w-8 md:h-8 group-hover:rotate-90 transition-transform duration-500" />
          </button>
        </div>
      </Transition>
    </main>

    <!-- Footer -->
    <footer v-if="appState !== STATES.RECEIVER_ACTIVE" class="px-8 md:px-12 py-8 md:py-10 border-t border-slate-800/50 flex flex-col md:flex-row justify-between items-center bg-slate-950/50 backdrop-blur-md gap-6 text-center md:text-left">
      <div class="text-[9px] md:text-[10px] font-black text-slate-500 uppercase tracking-[0.3em]">
        © 2024 CastNow P2P Protocol. Optimized for Low-Latency.
      </div>
      <div class="flex gap-8 md:gap-10 text-[9px] md:text-[10px] font-black text-slate-500 uppercase tracking-widest">
        <a href="#" class="hover:text-amber-500 transition-colors">Terms</a>
        <a href="#" class="hover:text-amber-500 transition-colors">Privacy</a>
        <a href="#" class="hover:text-amber-500 transition-colors">Security</a>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.4s cubic-bezier(0.4, 0, 0.2, 1), transform 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
  transform: scale(0.96);
}
</style>