<script setup>
import { ref, onUnmounted, watch, nextTick, computed, onMounted } from "vue";
import { inject as injectAnalytics } from "@vercel/analytics";
import {
  Monitor,
  X,
  Copy,
  Check,
  AlertCircle,
  Loader2,
  Camera,
  Repeat,
  Info,
  Activity,
  Globe,
  Download,
  Play,
  ArrowLeft,
  Volume2,
  VolumeX,
  Maximize,
  Smartphone,
} from "lucide-vue-next";

const STATES = {
  LANDING: "LANDING",
  SOURCE_SELECT: "SOURCE_SELECT",
  SENDER: "SENDER",
  RECEIVER_INPUT: "RECEIVER_INPUT",
  RECEIVER_ACTIVE: "RECEIVER_ACTIVE",
  BROADCAST_ENDED: "BROADCAST_ENDED",
};

const appState = ref(STATES.LANDING);
const isPro = ref(false); // Currently visual only or tied to a future validation logic
const castingMode = ref("screen");
const facingMode = ref("user");
const isConnecting = ref(false);
const error = ref(null);
const peerId = ref("");
const peerInstance = ref(null);
const localStream = ref(null);
const localVideo = ref(null);
const activeConnections = ref([]);

// Receiver Refs
const joinCode = ref("");
const remoteStream = ref(null);
const remoteVideo = ref(null);
const isMuted = ref(false);
const showControls = ref(true);
const showEndedDialog = ref(false);
const showInfo = ref(null); // 'source', 'privacy', 'terms'
const remainingSeconds = ref(1800); // 30 minutes
let controlsTimeout = null;
let sessionInterval = null;

// 监听 localVideo/remoteVideo 的挂载，确保 stream 能正确绑定
watch([localVideo, localStream], ([el, stream]) => {
  if (el && stream) {
    el.srcObject = stream;
  }
});

watch([remoteVideo, remoteStream], ([el, stream]) => {
  if (el && stream) {
    el.srcObject = stream;
    el.play().catch((e) => console.log("Remote autoplay blocked", e));

    // Start Session Limit Timer for Free Users if not already started
    if (!isPro.value && !sessionInterval) {
      remainingSeconds.value = 1800;
      sessionInterval = setInterval(() => {
        if (remainingSeconds.value > 0) {
          remainingSeconds.value--;
        } else {
          if (appState.value === STATES.RECEIVER_ACTIVE) {
            appState.value = STATES.BROADCAST_ENDED;
            resetApp();
            appState.value = STATES.BROADCAST_ENDED;
          }
        }
      }, 1000);
    }
  }
});



// Environment Detection
const isTouchDevice = computed(() => {
  if (typeof window === "undefined") return false;
  return "ontouchstart" in window || navigator.maxTouchPoints > 0;
});

const isMobile = computed(() => {
  if (typeof navigator === "undefined") return false;
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
    navigator.userAgent,
  );
});

// --- WebRTC Core ---
const getIceServers = () => {
  const isChina = () => {
    try {
      const locale = navigator.language || "";
      return locale.toLowerCase().includes("zh");
    } catch (e) {
      return false;
    }
  };
  return isChina()
    ? [
      { urls: "stun:stun.miwifi.com:3478" },
      { urls: "stun:stun.cdn.aliyun.com:3478" },
    ]
    : [
      { urls: "stun:stun.cloudflare.com:3478" },
      { urls: "stun:stun.l.google.com:19302" },
    ];
};

// --- Sender Logic ---
const handleStartCasting = async (mode) => {
  castingMode.value = mode;

  // 检查浏览器兼容性
  if (mode === "screen") {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getDisplayMedia) {
      // iOS WebView 或旧版安卓 WebView 可能不支持
      alert(
        "This device or browser does not support Screen Sharing.\n\nPlease try using the Camera broadcast mode instead.",
      );
      return;
    }
  }

  try {
    isConnecting.value = true;
    error.value = null;

    let stream = null;
    if (mode === "screen") {
      stream = await navigator.mediaDevices.getDisplayMedia({
        video: { cursor: "always" },
        audio: true,
      });
    } else {
      stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: facingMode.value,
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: true,
      });
    }

    localStream.value = stream;
    appState.value = STATES.SENDER;

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const peer = new window.Peer(code, {
      debug: 1,
      config: { iceServers: getIceServers() },
    });

    peerInstance.value = peer;
    peer.on("open", (id) => {
      peerId.value = id;
      isConnecting.value = false;
    });
    peer.on("connection", (conn) => {
      activeConnections.value.push(conn);
      // Sender initiates the call upon data connection
      peer.call(conn.peer, localStream.value);
    });

    // 如果是屏幕共享，监听停止事件（用户点击浏览器/系统自带的停止共享按钮）
    stream.getVideoTracks()[0].onended = () => resetApp();
  } catch (err) {
    console.error(err);
    // 处理用户取消屏幕共享的情况
    if (err.name === "NotAllowedError") {
      error.value = null;
      isConnecting.value = false;
      return;
    }
    error.value = "Device access denied or not supported.";
    isConnecting.value = false;
    appState.value = STATES.LANDING;
  }
};

const toggleCamera = async () => {
  if (castingMode.value !== "camera" || !localStream.value) return;
  facingMode.value = facingMode.value === "user" ? "environment" : "user";

  try {
    const newStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: facingMode.value },
      audio: true,
    });

    const oldTracks = localStream.value.getTracks();
    oldTracks.forEach((t) => t.stop());

    localStream.value = newStream;

    activeConnections.value.forEach((conn) => {
      peerInstance.value.call(conn.peer, newStream);
    });
  } catch (err) {
    alert("Camera switch failed");
  }
};

// --- Receiver Logic ---
const handleDigitInput = (digit) => {
  if (joinCode.value.length < 6) joinCode.value += digit;
};

const handleBackspace = () => {
  joinCode.value = joinCode.value.slice(0, -1);
};

const handleKeyDown = (e) => {
  if (appState.value !== STATES.RECEIVER_INPUT) return;
  if (isConnecting.value) return;

  if (/^[0-9]$/.test(e.key)) {
    handleDigitInput(e.key);
  } else if (e.key === "Backspace") {
    handleBackspace();
  } else if (e.key === "Enter") {
    handleJoin();
  } else if (e.key === "Escape") {
    resetApp();
  }
};

onMounted(() => {
  window.addEventListener("keydown", handleKeyDown);
});

onUnmounted(() => {
  window.removeEventListener("keydown", handleKeyDown);
});

const handleJoin = () => {
  if (joinCode.value.length !== 6) return;

  isConnecting.value = true;
  error.value = null;

  // Viewer needs their own Peer ID to receive the call
  const peer = new window.Peer({
    config: { iceServers: getIceServers() },
  });

  peerInstance.value = peer;

  peer.on("open", () => {
    // 1. Connect to Broadcaster (Signal intent)
    const conn = peer.connect(joinCode.value);

    conn.on("open", () => {
      console.log("Connected to broadcaster signaling");
      appState.value = STATES.RECEIVER_ACTIVE;
      isConnecting.value = false;
    });

    conn.on("error", (err) => {
      console.error("Connection Error", err);
      error.value = "Connection failed. Check code.";
      isConnecting.value = false;
    });

    // Auto close if broadcaster leaves
    conn.on("close", () => {
      appState.value = STATES.BROADCAST_ENDED;
      resetApp();
      // Overwrite the appState again because resetApp sets it to LANDING
      appState.value = STATES.BROADCAST_ENDED;
    });
  });

  // 2. Wait for Broadcaster to call us with the stream
  peer.on("call", (call) => {
    call.answer(); // Answer without sending a stream back
    call.on("stream", (rs) => {
      remoteStream.value = rs;
    });
  });

  peer.on("error", (err) => {
    console.error(err);
    error.value = "Invalid Code or Connection Error";
    isConnecting.value = false;
    joinCode.value = "";
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
    remoteVideo.value.parentElement
      .requestFullscreen()
      .catch((err) => console.log(err));
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
  if (localStream.value) localStream.value.getTracks().forEach((t) => t.stop());
  if (peerInstance.value) peerInstance.value.destroy();
  if (sessionInterval) {
    clearInterval(sessionInterval);
    sessionInterval = null;
  }


  // Ensure BROADCAST_ENDED dialog sticks if we just timed out, 
  // otherwise default to LANDING
  if (appState.value !== STATES.BROADCAST_ENDED) {
    appState.value = STATES.LANDING;
  }

  peerId.value = "";
  localStream.value = null;
  remoteStream.value = null;
  activeConnections.value = [];
  joinCode.value = "";
  isConnecting.value = false;
  error.value = null;
};

</script>

<template>
  <div class="min-h-[100dvh] flex flex-col bg-slate-950 text-slate-50 font-sans selection:bg-amber-500/30">
    <header v-if="appState !== STATES.RECEIVER_ACTIVE"
      class="flex items-center justify-between px-6 py-4 border-b border-slate-800/50 backdrop-blur-md sticky top-0 z-50">
      <div class="flex items-center gap-3 cursor-pointer group" @click="resetApp">
        <!-- Logo Icon -->
        <img src="/icon.svg" alt="CastNow"
          class="w-10 h-10 rounded-xl shadow-lg shadow-amber-500/10 group-hover:scale-105 transition-transform duration-300" />
        <span
          class="bg-gradient-to-r from-slate-100 to-slate-400 bg-clip-text text-xl font-black italic uppercase tracking-tight text-transparent pr-1">CastNow</span>

      </div>
      <div class="flex items-center gap-2">
        <div class="px-3 py-1 bg-slate-900 rounded-full border border-slate-800 flex items-center gap-2">
          <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
          <span class="text-[10px] font-bold uppercase tracking-tighter">P2P Secure</span>
        </div>
      </div>
    </header>

    <main class="flex-1 flex flex-col relative overflow-hidden">
      <Transition name="fade" mode="out-in">
        <!-- Landing -->
        <div v-if="appState === STATES.LANDING"
          class="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div class="mb-4 px-4 py-1 bg-amber-500/10 border border-amber-500/20 rounded-full flex items-center gap-2">
            <Globe class="w-3 h-3 text-amber-500" />
            <span class="text-[10px] font-black uppercase text-amber-500 tracking-widest">Secure P2P Protocol
              Engine</span>
          </div>
          <h1 class="text-6xl md:text-8xl font-black mb-6 tracking-tighter leading-none">
            Instant<br /><span class="text-amber-500">Casting.</span>
          </h1>
          <p class="text-slate-500 max-w-xs mb-10 text-sm font-medium italic">
            No plugins. No latency. Pure P2P screen sharing for mobile &
            desktop.
          </p>

          <div class="flex flex-col gap-4 w-full max-w-xs">
            <button @click="appState = STATES.SOURCE_SELECT"
              class="group relative py-6 bg-amber-500 text-slate-950 rounded-3xl font-black text-xl uppercase shadow-xl shadow-amber-500/20 active:scale-95 transition-all overflow-hidden">
              <span class="relative z-10">Broadcast</span>
              <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform">
              </div>
            </button>
            <button @click="appState = STATES.RECEIVER_INPUT"
              class="py-6 bg-slate-900 border border-slate-800 rounded-3xl font-black text-xl uppercase active:scale-95 transition-all flex items-center justify-center gap-3 hover:border-slate-700">
              <Download class="w-6 h-6" />
              Receive
            </button>

            <a href="https://minghster.gumroad.com/l/ihhtg" target="_blank"
              class="group mt-2 flex items-center justify-center gap-3 rounded-2xl border border-amber-500/20 bg-amber-500/5 px-6 py-4 hover:bg-amber-500/10 transition-all">
              <div
                class="rounded bg-amber-500 px-2 py-0.5 text-[10px] font-black uppercase tracking-tighter text-slate-950 transition-transform group-hover:scale-110">
                Pro
              </div>
              <span class="text-xs font-black uppercase tracking-widest text-amber-500">7-Day Unlimited Pass</span>
            </a>

          </div>


          <div class="mt-16 flex flex-col items-center gap-6">
            <div class="flex items-center gap-8 text-slate-600 font-bold text-[10px] uppercase tracking-[0.2em]">
              <button @click="showInfo = 'source'" class="hover:text-amber-500 transition-colors">Source</button>
              <button @click="showInfo = 'privacy'" class="hover:text-amber-500 transition-colors">Privacy</button>
              <button @click="showInfo = 'terms'" class="hover:text-amber-500 transition-colors">Terms</button>
            </div>

            <div class="text-[9px] font-black text-slate-800 uppercase tracking-[0.2em] flex items-center gap-2">
              <span class="w-4 h-px bg-slate-800"></span>
              Made by Eastlake Studio
              <span class="w-4 h-px bg-slate-800"></span>
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
            <!-- Desktop/Screen Option: Enabled for Mobile now -->
            <button @click="handleStartCasting('screen')"
              class="flex items-center gap-6 p-6 bg-slate-900 border border-slate-800 rounded-[2rem] hover:border-amber-500 transition-all group text-left relative overflow-hidden">
              <div
                class="w-16 h-16 bg-slate-950 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform">
                <Monitor class="w-8 h-8 text-amber-500" />
              </div>
              <div>
                <span class="block font-black uppercase tracking-widest text-lg">Screen Share</span>
                <p class="text-[10px] text-slate-500 uppercase font-bold mt-1">
                  {{
                    isMobile
                      ? "Experimental (Android Only)"
                      : "System Mirroring"
                  }}
                </p>
              </div>
            </button>

            <button @click="handleStartCasting('camera')"
              class="flex items-center gap-6 p-6 bg-slate-900 border border-slate-800 rounded-[2rem] hover:border-amber-500 transition-all group text-left">
              <div
                class="w-16 h-16 bg-slate-950 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform">
                <Camera class="w-8 h-8 text-amber-500" />
              </div>
              <div>
                <span class="block font-black uppercase tracking-widest text-lg">Camera</span>
                <p class="text-[10px] text-slate-500 uppercase font-bold mt-1">
                  Mobile Broadcast
                </p>
              </div>
            </button>
          </div>
          <button @click="appState = STATES.LANDING"
            class="mt-12 text-slate-500 font-black uppercase tracking-widest text-[10px] hover:text-white transition-colors">
            ← Cancel Operation
          </button>
        </div>

        <!-- Sender View -->
        <div v-else-if="appState === STATES.SENDER" class="flex-1 flex flex-col items-center justify-center p-4">
          <div
            class="w-full max-w-xl bg-slate-900 border border-slate-800 rounded-[3rem] p-8 text-center relative overflow-hidden shadow-2xl">
            <div
              class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-amber-500 to-transparent animate-pulse">
            </div>

            <div class="flex items-center justify-between mb-8">
              <div class="flex items-center gap-2">
                <Activity class="w-4 h-4 text-amber-500" />
                <span class="text-[10px] font-black text-slate-500 uppercase tracking-widest">Active Tunnel</span>
              </div>
              <button v-if="castingMode === 'camera'" @click="toggleCamera"
                class="flex items-center gap-2 px-3 py-1.5 bg-slate-800 rounded-full hover:bg-amber-500 hover:text-slate-950 transition-all">
                <Repeat class="w-3 h-3" />
                <span class="text-[10px] font-black uppercase">{{
                  facingMode === "user" ? "Front" : "Back"
                }}</span>
              </button>
            </div>

            <div class="mb-10">
              <p class="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] mb-4">
                Sharing Access Key
              </p>
              <div class="flex items-center justify-center gap-2">
                <template v-for="(char, i) in peerId.split('')" :key="i">
                  <span
                    class="text-4xl md:text-6xl font-black bg-slate-950 w-12 md:w-16 h-16 md:h-24 flex items-center justify-center rounded-2xl border border-slate-800 text-amber-500 shadow-inner">{{
                      char }}</span>
                  <span v-if="i === 2" class="text-slate-800 font-black text-2xl">-</span>
                </template>
                <div v-if="!peerId" class="flex gap-2">
                  <div v-for="n in 6" :key="n"
                    class="w-12 h-16 bg-slate-950 rounded-2xl border border-slate-800 animate-pulse"></div>
                </div>
              </div>
            </div>

            <div
              class="aspect-video bg-black rounded-3xl border border-slate-800 overflow-hidden relative mb-8 group shadow-inner">
              <video ref="localVideo" autoplay muted playsinline class="w-full h-full object-cover" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
              <div class="absolute bottom-4 left-6 flex items-center gap-3">
                <div class="w-2 h-2 bg-red-500 rounded-full animate-ping"></div>
                <span class="text-[10px] font-black uppercase tracking-widest">{{
                  castingMode === "screen" ? "Desktop Mirror" : "Camera Feed"
                  }}</span>
              </div>
            </div>

            <button @click="resetApp"
              class="w-full py-5 bg-red-500/10 hover:bg-red-500 text-red-500 hover:text-white font-black rounded-2xl transition-all border border-red-500/20 uppercase tracking-widest text-xs">
              Terminate Stream
            </button>
          </div>
        </div>

        <!-- Receiver Input -->
        <div v-else-if="appState === STATES.RECEIVER_INPUT"
          class="flex-1 flex flex-col items-center justify-center p-6">
          <h2 class="text-2xl font-black uppercase mb-10 tracking-widest flex items-center gap-3">
            <span class="w-8 h-[2px] bg-amber-500"></span>
            Enter Access Key
            <span class="w-8 h-[2px] bg-amber-500"></span>
          </h2>

          <!-- Display -->
          <div class="mb-10 flex gap-2 h-20 md:h-24">
            <div v-for="i in 6" :key="i"
              class="w-12 md:w-16 bg-slate-900 border border-slate-800 rounded-2xl flex items-center justify-center text-3xl md:text-4xl font-black text-white shadow-inner transition-colors duration-200"
              :class="{
                'border-amber-500/50 text-amber-500': joinCode[i - 1],
                'animate-pulse bg-slate-800/50': joinCode.length === i - 1,
              }">
              {{ joinCode[i - 1] || "" }}
            </div>
          </div>

          <!-- Keypad - Only show on touch devices -->
          <div v-if="isTouchDevice" class="grid grid-cols-3 gap-4 w-full max-w-[280px] mb-8">
            <button v-for="n in 9" :key="n" @click="handleDigitInput(n.toString())"
              class="h-16 rounded-2xl bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">
              {{ n }}
            </button>
            <button @click="resetApp"
              class="h-16 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
              <X class="w-6 h-6" />
            </button>
            <button @click="handleDigitInput('0')"
              class="h-16 rounded-2xl bg-slate-900 border border-slate-800 hover:bg-slate-800 text-xl font-bold active:scale-95 transition-all">
              0
            </button>
            <button @click="handleBackspace"
              class="h-16 rounded-2xl bg-slate-950 border border-slate-900 hover:bg-slate-900 text-slate-500 flex items-center justify-center active:scale-95 transition-all">
              <ArrowLeft class="w-6 h-6" />
            </button>
          </div>

          <div v-else class="mb-12 text-slate-500 text-xs font-bold uppercase tracking-widest animate-pulse">
            Type access key via physical keyboard
          </div>

          <button @click="handleJoin" :disabled="joinCode.length !== 6 || isConnecting"
            class="w-full max-w-[280px] py-5 bg-amber-500 disabled:bg-slate-800 disabled:text-slate-600 text-slate-950 font-black rounded-2xl text-lg uppercase tracking-widest shadow-xl shadow-amber-500/20 active:scale-95 transition-all flex items-center justify-center gap-2">
            <Loader2 v-if="isConnecting" class="w-5 h-5 animate-spin" />
            <span v-else>Connect Now</span>
          </button>

          <!-- Cancel Button during connecting -->
          <button v-if="isConnecting" @click="resetApp"
            class="mt-4 text-slate-500 font-bold uppercase tracking-widest text-[10px] hover:text-white transition-colors flex items-center gap-2">
            <X class="w-3 h-3" /> Stop Connecting
          </button>

          <p v-if="error" class="mt-4 text-red-500 text-xs font-bold uppercase tracking-widest flex items-center gap-2">
            <AlertCircle class="w-4 h-4" /> {{ error }}
          </p>
        </div>

        <!-- Broadcast Ended Dialog as a full state for cleaner transition -->
        <div v-else-if="appState === STATES.BROADCAST_ENDED"
          class="flex-1 flex items-center justify-center p-6 bg-slate-950">
          <div class="w-full max-w-sm bg-slate-900 border border-slate-800 rounded-[3rem] p-10 text-center shadow-2xl">
            <div
              class="w-24 h-24 bg-amber-500/10 rounded-full flex items-center justify-center mx-auto mb-8 animate-bounce">
              <Info class="w-12 h-12 text-amber-500" />
            </div>
            <h3 class="text-3xl font-black uppercase mb-4 tracking-tight text-white">
              Broadcast Ended
            </h3>
            <p class="text-slate-400 text-base mb-10 font-medium">
              The session has been terminated by the broadcaster.
            </p>
            <button @click="resetApp"
              class="w-full py-6 bg-amber-500 text-slate-950 font-black rounded-2xl uppercase tracking-widest text-sm active:scale-95 transition-all shadow-xl shadow-amber-500/20">
              Back to Home
            </button>
          </div>
        </div>

        <!-- Receiver Active -->
        <div v-else-if="appState === STATES.RECEIVER_ACTIVE"
          class="fixed inset-0 bg-black flex items-center justify-center overflow-hidden" @mousemove="handleMouseMove"
          @touchstart="handleMouseMove">
          <video ref="remoteVideo" autoplay playsinline class="w-full h-full object-contain bg-black" />

          <!-- Overlay Controls -->
          <div
            class="absolute inset-0 bg-gradient-to-b from-black/60 via-transparent to-black/60 transition-opacity duration-300 pointer-events-none"
            :class="{ 'opacity-0': !showControls }"></div>

          <div class="absolute top-6 left-6 transition-opacity duration-300 z-10"
            :class="{ 'opacity-0': !showControls }">
            <button @click="resetApp"
              class="flex items-center gap-2 px-4 py-2 bg-white/10 backdrop-blur-md rounded-full text-white/90 hover:bg-white/20 transition-all font-bold text-sm">
              <ArrowLeft class="w-4 h-4" /> Leave
            </button>
          </div>

          <div
            class="absolute bottom-10 left-0 w-full px-8 flex items-end justify-between transition-opacity duration-300 z-10"
            :class="{ 'opacity-0': !showControls }">
            <div>
              <div class="flex items-center gap-2 mb-2">
                <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
                <span class="text-red-500 text-[10px] font-black uppercase tracking-widest">Live Feed</span>
                <div v-if="!isPro"
                  class="ml-2 px-2 py-0.5 bg-slate-800/80 backdrop-blur-md rounded-md border border-slate-700 flex items-center gap-1.5 transition-opacity duration-300"
                  :class="{ 'opacity-100': remainingSeconds < 300, 'opacity-0': remainingSeconds >= 300 && !showControls }">
                  <div
                    :class="{ 'bg-red-500 animate-pulse': remainingSeconds < 300, 'bg-slate-400': remainingSeconds >= 300 }"
                    class="w-1.5 h-1.5 rounded-full"></div>
                  <span class="text-[9px] font-bold"
                    :class="{ 'text-red-500': remainingSeconds < 300, 'text-slate-300': remainingSeconds >= 300 }">
                    {{ remainingSeconds < 300 ? `Ending in ${Math.floor(remainingSeconds / 60)}:${(remainingSeconds %
                      60).toString().padStart(2, '0')}` : 'Free Session: 30m Limit' }} </span>
                </div>


              </div>
              <h3 class="text-white font-bold text-lg">P2P Secure Stream</h3>
            </div>


            <div class="flex items-center gap-4">
              <button @click="toggleMute"
                class="p-3 bg-white/10 backdrop-blur-md rounded-full text-white hover:bg-white/20 transition-all active:scale-95">
                <VolumeX v-if="isMuted" class="w-6 h-6" />
                <Volume2 v-else class="w-6 h-6" />
              </button>
              <button @click="toggleFullscreen"
                class="p-3 bg-white/10 backdrop-blur-md rounded-full text-white hover:bg-white/20 transition-all active:scale-95">
                <Maximize class="w-6 h-6" />
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </main>

    <!-- Info Modal -->
    <div v-if="showInfo"
      class="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-slate-950/90 backdrop-blur-xl"
      @click.self="showInfo = null">
      <div class="w-full max-w-lg bg-slate-900 border border-slate-800 rounded-[2.5rem] p-10 shadow-2xl relative">
        <button @click="showInfo = null"
          class="absolute top-8 right-8 text-slate-500 hover:text-white transition-colors">
          <X class="w-6 h-6" />
        </button>

        <div v-if="showInfo === 'source'">
          <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center mb-6">
            <Globe class="w-8 h-8 text-amber-500" />
          </div>
          <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">Source Code</h3>
          <p class="text-slate-400 text-sm leading-relaxed mb-8">
            CastNow is an open-source high-performance P2P engine. The source code is available on GitHub under the MIT
            license for community contributions and transparency.
          </p>
          <a href="https://github.com/MinghuaLiu1977/castnow" target="_blank"
            class="inline-flex items-center gap-2 px-6 py-3 bg-amber-500 text-slate-950 font-black rounded-xl uppercase tracking-widest text-[10px] hover:scale-105 transition-transform active:scale-95">
            View on GitHub
          </a>
        </div>

        <div v-else-if="showInfo === 'privacy'">
          <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center mb-6">
            <Activity class="w-8 h-8 text-amber-500" />
          </div>
          <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">Privacy Policy</h3>
          <p class="text-slate-400 text-sm leading-relaxed mb-4">
            We value your privacy. CastNow utilizes direct **End-to-End Peer-to-Peer** connections.
          </p>
          <ul class="text-slate-500 text-[11px] space-y-2 mb-8">
            <li>• Your stream data never touches our servers.</li>
            <li>• No recordings are stored or processed by us.</li>
            <li>• We do not collect or sell personal demographic data.</li>
          </ul>
          <button @click="showInfo = null"
            class="w-full py-4 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] active:scale-95 transition-all">Close</button>
        </div>

        <div v-else-if="showInfo === 'terms'">
          <div class="w-16 h-16 bg-amber-500/10 rounded-2xl flex items-center justify-center mb-6">
            <Info class="w-8 h-8 text-amber-500" />
          </div>
          <h3 class="text-2xl font-black uppercase mb-4 tracking-tight text-white">Terms of Service</h3>
          <p class="text-slate-400 text-sm leading-relaxed mb-6">
            By using CastNow, you agree that you are solely responsible for the content you broadcast.
          </p>
          <p class="text-slate-500 text-[11px] italic mb-8 border-l-2 border-amber-500/20 pl-4">
            The service is provided 'as is' without warranties of any kind. Misuse of the platform for illegal
            activities
            will result in termination of service availability.
          </p>
          <button @click="showInfo = null"
            class="w-full py-4 bg-slate-800 text-white font-black rounded-xl uppercase tracking-widest text-[10px] active:scale-95 transition-all">Agree
            & Close</button>
        </div>
      </div>
    </div>
  </div>
</template>


<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}

.fade-enter-from {
  opacity: 0;
  transform: translateY(10px);
}

.fade-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}
</style>
