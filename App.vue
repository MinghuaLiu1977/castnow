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

// Cleanup function
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
  isConnecting.value = false;
  console.log('[CastNow] Cleanup finished.');
};

onUnmounted(cleanup);

// Sync video elements with streams
watch(localStream, async (stream) => {
  if (stream) {
    await nextTick();
    if (localVideo.value) {
      console.log('[CastNow] Binding local stream to preview');
      localVideo.value.srcObject = stream;
    }
  }
});

watch(remoteStream, async (stream) => {
  if (stream) {
    await nextTick();
    if (remoteVideo.value) {
      console.log('[CastNow] Binding remote stream to player');
      remoteVideo.value.srcObject = stream;
    }
  }
});

const generateCode = () => Math.floor(100000 + Math.random() * 900000).toString();

const copyToClipboard = () => {
  navigator.clipboard.writeText(peerId.value);
  isCopied.value = true;
  setTimeout(() => isCopied.value = false, 2000);
};

// SENDER LOGIC
const handleStartCasting = async () => {
  try {
    console.log('[CastNow] Requesting screen sharing...');
    isConnecting.value = true;
    error.value = null;

    const stream = await navigator.mediaDevices.getDisplayMedia({
      video: { cursor: "always" },
      audio: true
    });
    console.log('[CastNow] Stream captured:', stream.id);
    
    localStream.value = stream;
    const code = generateCode();
    
    console.log('[CastNow] Initializing Peer as Sender with ID:', code);
    const peer = new window.Peer(code, { debug: 2 });
    peerInstance.value = peer;

    peer.on('open', (id) => {
      console.log('[CastNow] Sender online. Peer ID:', id);
      peerId.value = id;
      appState.value = STATES.SENDER;
      isConnecting.value = false;
    });

    peer.on('call', (call) => {
      console.log('[CastNow] Incoming connection from receiver:', call.peer);
      call.answer(stream);
      console.log('[CastNow] Call answered with local stream');
    });

    peer.on('error', (err) => {
      console.error('[CastNow] PeerJS Sender Error:', err.type);
      error.value = `Connection Error: ${err.type}`;
      cleanup();
      appState.value = STATES.LANDING;
    });

    stream.getVideoTracks()[0].onended = () => {
      console.log('[CastNow] User stopped screen sharing.');
      resetApp();
    };

  } catch (err) {
    console.error('[CastNow] Media capture failed:', err);
    error.value = 'Failed to start screen share. Please check permissions.';
    isConnecting.value = false;
  }
};

// RECEIVER LOGIC
const handleReceiveCast = () => {
  if (inputCode.value.length !== 6) {
    error.value = 'Please enter a 6-digit code.';
    return;
  }

  console.log('[CastNow] Attempting to receive cast from:', inputCode.value);
  isConnecting.value = true;
  error.value = null;

  const peer = new window.Peer({ debug: 2 });
  peerInstance.value = peer;

  peer.on('open', (id) => {
    console.log('[CastNow] Receiver Peer opened. ID:', id);
    // Initiating call with an empty stream to force the handshake
    const call = peer.call(inputCode.value, new MediaStream());
    
    const timeout = setTimeout(() => {
      if (appState.value !== STATES.RECEIVER_ACTIVE) {
        console.warn('[CastNow] Connection timed out after 15s');
        error.value = 'Connection timed out. Ensure the sender is still active.';
        isConnecting.value = false;
        cleanup();
        appState.value = STATES.RECEIVER_INPUT;
      }
    }, 15000);

    call.on('stream', (stream) => {
      clearTimeout(timeout);
      console.log('[CastNow] Remote stream received successfully!');
      remoteStream.value = stream;
      appState.value = STATES.RECEIVER_ACTIVE;
      isConnecting.value = false;
    });

    call.on('error', (err) => {
      clearTimeout(timeout);
      console.error('[CastNow] Call error:', err);
      error.value = 'Failed to connect to sender.';
      isConnecting.value = false;
    });
  });

  peer.on('error', (err) => {
    console.error('[CastNow] Receiver Peer Error:', err.type);
    if (err.type === 'peer-unavailable') {
      error.value = 'Invalid code or sender is offline.';
    } else {
      error.value = `Error: ${err.type}`;
    }
    isConnecting.value = false;
  });
};

const resetApp = () => {
  console.log('[CastNow] Resetting app state to Landing.');
  cleanup();
  appState.value = STATES.LANDING;
};
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30">
    <header class="flex items-center justify-between px-6 py-4 md:px-12 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-2 cursor-pointer group" @click="resetApp">
        <div class="w-8 h-8 bg-amber-500 rounded-lg flex items-center justify-center group-hover:rotate-12 transition-transform duration-300 shadow-lg shadow-amber-500/20">
          <Zap class="text-slate-950 w-5 h-5 fill-current" />
        </div>
        <span class="text-2xl font-extrabold tracking-tighter uppercase">CastNow</span>
      </div>
      <div class="flex items-center gap-4">
        <button class="px-4 py-1.5 text-xs font-bold uppercase tracking-widest text-amber-500 border border-amber-500/30 rounded-full hover:bg-amber-500/10 transition-all">
          Pro
        </button>
      </div>
    </header>

    <main class="flex-1 flex flex-col relative">
      <Transition name="fade" mode="out-in">
        <!-- Landing -->
        <div v-if="appState === STATES.LANDING" key="landing" class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="mb-6 inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-500 text-xs font-black uppercase tracking-[0.2em]">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
            </span>
            Live Connection
          </div>
          <h1 class="text-5xl md:text-8xl font-black mb-8 tracking-tighter leading-[0.9]">
            No installs. <br class="hidden md:block" />
            No sign-ups. <br />
            <span class="text-amber-500">Just cast.</span>
          </h1>
          <p class="text-slate-400 text-lg md:text-xl mb-12 max-w-2xl font-medium">
            Fastest P2P screen sharing solution. Instant, private, and secure.
          </p>

          <div class="grid md:grid-cols-2 gap-6 w-full max-w-3xl">
            <button @click="handleStartCasting" :disabled="isConnecting" class="group flex flex-col items-center justify-center p-12 bg-amber-500 hover:bg-amber-400 rounded-[2.5rem] transition-all duration-500 shadow-2xl shadow-amber-500/10 hover:-translate-y-2 active:scale-95 disabled:opacity-50">
              <Monitor v-if="!isConnecting" class="w-16 h-16 text-slate-950 mb-6 group-hover:scale-110 transition-transform duration-500" />
              <Loader2 v-else class="w-16 h-16 text-slate-950 mb-6 animate-spin" />
              <span class="text-slate-950 font-black text-3xl tracking-tight">Start Casting</span>
              <span class="text-slate-900/60 font-bold text-sm mt-2">Share your screen now</span>
            </button>
            <button @click="appState = STATES.RECEIVER_INPUT" class="group flex flex-col items-center justify-center p-12 bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-[2.5rem] transition-all duration-500 hover:-translate-y-2 active:scale-95">
              <Download class="w-16 h-16 text-amber-500 mb-6 group-hover:scale-110 transition-transform duration-500" />
              <span class="text-white font-black text-3xl tracking-tight">Receive Cast</span>
              <span class="text-slate-500 font-bold text-sm mt-2">Enter code to watch</span>
            </button>
          </div>

          <div v-if="error" class="mt-8 flex items-center gap-2 text-red-400 font-bold bg-red-400/10 px-6 py-3 rounded-2xl border border-red-400/20">
            <AlertCircle class="w-5 h-5" />
            {{ error }}
          </div>
        </div>

        <!-- Sender -->
        <div v-else-if="appState === STATES.SENDER" key="sender" class="flex-1 flex flex-col items-center justify-center p-6">
          <div class="w-full max-w-2xl bg-slate-900/50 border border-slate-800 rounded-[3rem] p-12 text-center shadow-2xl backdrop-blur-sm">
            <h2 class="text-slate-500 font-black text-sm mb-6 tracking-[0.3em] uppercase">Session Code</h2>
            <div class="flex items-center justify-center gap-4 mb-10 relative group">
              <template v-for="(char, i) in peerId.split('')" :key="i">
                <span class="text-5xl md:text-8xl font-black text-white bg-slate-950 w-16 md:w-24 py-6 rounded-3xl border border-slate-800 shadow-inner group-hover:border-amber-500/50 transition-colors">
                  {{ char }}
                </span>
                <span v-if="i === 2" class="text-4xl text-slate-700 font-bold mx-1">-</span>
              </template>
              <button @click="copyToClipboard" class="absolute -right-16 p-4 rounded-full bg-slate-800 hover:bg-amber-500 hover:text-slate-950 transition-all active:scale-90 shadow-lg">
                <Check v-if="isCopied" class="w-6 h-6" />
                <Copy v-else class="w-6 h-6" />
              </button>
            </div>
            <div class="aspect-video bg-slate-950 rounded-3xl border border-slate-800 overflow-hidden mb-10 shadow-inner">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-contain" />
            </div>
            <button @click="resetApp" class="px-10 py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-sm">
              Stop Casting
            </button>
          </div>
        </div>

        <!-- Receiver Input -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT" key="input" class="flex-1 flex flex-col items-center justify-center p-6">
          <div class="w-full max-w-lg bg-slate-900/50 border border-slate-800 rounded-[3rem] p-12 text-center shadow-2xl backdrop-blur-sm">
            <h2 class="text-4xl font-black text-white mb-4 tracking-tighter">Enter Code</h2>
            <p class="text-slate-400 mb-10">Input the 6-digit code to start watching</p>
            <input v-model="inputCode" type="text" maxlength="6" placeholder="000000" class="w-full bg-slate-950 border-4 border-slate-800 focus:border-amber-500 rounded-3xl px-8 py-8 text-6xl font-black tracking-[0.5em] text-center text-white outline-none transition-all placeholder:text-slate-900 mb-10" @keyup.enter="handleReceiveCast" />
            <div class="grid grid-cols-2 gap-4">
              <button @click="appState = STATES.LANDING" class="px-8 py-6 bg-slate-800 hover:bg-slate-700 text-white font-black rounded-2xl transition-all">Back</button>
              <button @click="handleReceiveCast" :disabled="inputCode.length !== 6 || isConnecting" class="px-8 py-6 font-black rounded-2xl transition-all shadow-xl shadow-amber-500/10 flex items-center justify-center gap-2" :class="inputCode.length === 6 ? 'bg-amber-500 text-slate-950 hover:bg-amber-400' : 'bg-slate-800 text-slate-600'">
                <Loader2 v-if="isConnecting" class="w-5 h-5 animate-spin" />
                {{ isConnecting ? 'Connecting' : 'Watch' }}
              </button>
            </div>
            <div v-if="error" class="mt-6 flex items-center justify-center gap-2 text-red-400 font-bold text-sm">
              <AlertCircle class="w-4 h-4" />
              {{ error }}
            </div>
          </div>
        </div>

        <!-- Receiver Player -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE" key="active" class="fixed inset-0 bg-black z-[100] flex items-center justify-center overflow-hidden">
          <video ref="remoteVideo" autoplay playsinline class="w-full h-full object-contain" />
          <div class="absolute top-10 left-10 flex items-center gap-4 bg-black/60 backdrop-blur-2xl px-6 py-3 rounded-full border border-white/10">
            <div class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
            <span class="text-xs font-black text-white uppercase tracking-widest">Live Cast</span>
          </div>
          <button @click="resetApp" class="absolute top-10 right-10 w-16 h-16 flex items-center justify-center bg-white/10 hover:bg-red-500 backdrop-blur-2xl rounded-full text-white transition-all">
            <X class="w-8 h-8" />
          </button>
        </div>
      </Transition>
    </main>

    <footer v-if="appState !== STATES.RECEIVER_ACTIVE" class="px-12 py-10 border-t border-slate-800/50 flex flex-col md:flex-row justify-between items-center bg-slate-950/50 backdrop-blur-md gap-6">
      <div class="text-[10px] font-black text-slate-500 uppercase tracking-[0.4em]">© 2024 CastNow P2P. No logs. No trackers.</div>
      <div class="flex gap-10 text-[10px] font-black text-slate-500 uppercase tracking-widest">
        <a href="#" class="hover:text-amber-500 transition-colors">Documentation</a>
        <a href="#" class="hover:text-amber-500 transition-colors">Privacy</a>
      </div>
    </footer>
  </div>
</template>