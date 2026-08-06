import { ref, computed, watch } from 'vue';

export function useMediaStream() {
  const castingMode = ref('screen');
  const facingMode = ref('user');
  const localStream = ref(null);
  const localVideo = ref(null);
  const localScreenStream = ref(null);
  const localCameraStream = ref(null);
  const localScreenVideo = ref(null);
  const localCameraVideo = ref(null);
  const isMicMuted = ref(true);

  const isScreenShareSupported = computed(() => {
    if (typeof window === 'undefined' || typeof navigator === 'undefined') return false;
    return !!(navigator.mediaDevices && navigator.mediaDevices.getDisplayMedia);
  });

  const videoDevices = ref([]);
  const audioDevices = ref([]);
  const isDeviceEnumerated = ref(false);
  const isCameraDenied = ref(false);
  const isMicDenied = ref(false);

  const hasCamera = computed(() => {
    if (!isDeviceEnumerated.value) return true; // Before enum, assume true until checked
    return videoDevices.value.length > 0;
  });

  const hasMicrophone = computed(() => {
    if (!isDeviceEnumerated.value) return true; // Before enum, assume true until checked
    return audioDevices.value.length > 0;
  });

  const isCameraAvailable = computed(() => hasCamera.value && !isCameraDenied.value);
  const isMicAvailable = computed(() => hasMicrophone.value && !isMicDenied.value);

  watch(isCameraDenied, (denied) => {
    if (denied) {
      const idx = selectedSources.value.indexOf('camera');
      if (idx > -1) selectedSources.value.splice(idx, 1);
    }
  }, { flush: 'sync' });

  watch(isMicDenied, (denied) => {
    if (denied) {
      const idx = selectedSources.value.indexOf('mic');
      if (idx > -1) selectedSources.value.splice(idx, 1);
    }
  }, { flush: 'sync' });

  const selectedSources = ref(
    isScreenShareSupported.value ? ['screen', 'camera', 'mic'] : ['camera', 'mic']
  );

  const hasMultipleCameras = computed(() => videoDevices.value.length > 1);

  // Watch video element bindings
  watch([localVideo, localStream], ([el, stream]) => {
    if (el && stream) el.srcObject = stream;
  });
  watch([localScreenVideo, localScreenStream], ([el, stream]) => {
    if (el && stream) el.srcObject = stream;
  });
  watch([localCameraVideo, localCameraStream], ([el, stream]) => {
    if (el && stream) el.srcObject = stream;
  });

  const toggleSource = (source) => {
    if (source === 'screen' && !isScreenShareSupported.value) return;
    if (source === 'camera' && !isCameraAvailable.value) return;
    if (source === 'mic' && !isMicAvailable.value) return;

    const index = selectedSources.value.indexOf(source);
    if (index > -1) {
      if (source === 'screen' || source === 'camera') {
        const otherVideo = source === 'screen' ? 'camera' : 'screen';
        if (!selectedSources.value.includes(otherVideo)) return;
      }
      selectedSources.value.splice(index, 1);
    } else {
      selectedSources.value.push(source);
    }
  };

  const getIceServers = () => {
    return [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun.miwifi.com:3478' },
      { urls: 'stun:stun.cdn.aliyun.com:3478' },
      { urls: 'stun:stun.cloudflare.com:3478' },
      { urls: 'stun:stun.tuna.tsinghua.edu.cn:3478' },
    ];
  };

  const captureMediaStreams = async () => {
    let combinedStream = new MediaStream();

    if (selectedSources.value.includes('screen')) {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getDisplayMedia) {
        throw new Error('screen_share_unsupported');
      }
      const ss = await navigator.mediaDevices.getDisplayMedia({
        video: { cursor: 'always' },
        audio: false,
      });
      ss.getVideoTracks().forEach(t => combinedStream.addTrack(t));
      localScreenStream.value = new MediaStream(ss.getVideoTracks());
      ss.getVideoTracks()[0].onended = () => {
        // Signal that screen share ended via browser UI
        return true;
      };
    }

    if (selectedSources.value.includes('camera')) {
      try {
        const cs = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: facingMode.value,
            width: { ideal: 1280 },
            height: { ideal: 720 },
          },
          audio: false,
        });
        cs.getVideoTracks().forEach(t => {
          localCameraStream.value = new MediaStream([t]);
          combinedStream.addTrack(t);
        });
        isCameraDenied.value = false;
      } catch (err) {
        if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
          isCameraDenied.value = true;
          const idx = selectedSources.value.indexOf('camera');
          if (idx > -1) selectedSources.value.splice(idx, 1);
        }
        throw err;
      }
    }

    if (selectedSources.value.includes('mic')) {
      try {
        const as = await navigator.mediaDevices.getUserMedia({
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          },
        });
        as.getAudioTracks().forEach(t => {
          t.enabled = !isMicMuted.value;
          combinedStream.addTrack(t);
        });
        isMicDenied.value = false;
      } catch (e) {
        console.error('Failed to capture microphone', e);
        if (e.name === 'NotAllowedError' || e.name === 'PermissionDeniedError') {
          isMicDenied.value = true;
          const idx = selectedSources.value.indexOf('mic');
          if (idx > -1) selectedSources.value.splice(idx, 1);
        }
      }
    }

    return combinedStream;
  };

  const toggleMic = () => {
    if (localStream.value) {
      isMicMuted.value = !isMicMuted.value;
      localStream.value.getAudioTracks().forEach((track) => {
        track.enabled = !isMicMuted.value;
      });
    }
  };

  const toggleCamera = async () => {
    if (!selectedSources.value.includes('camera') || !localStream.value || !localCameraStream.value) return;

    const oldMode = facingMode.value;
    facingMode.value = facingMode.value === 'user' ? 'environment' : 'user';

    try {
      const newStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: facingMode.value, width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false,
      });

      const newVideoTrack = newStream.getVideoTracks()[0];
      const oldCameraTrackId = localCameraStream.value.getVideoTracks()[0]?.id;

      localCameraStream.value = new MediaStream([newVideoTrack]);

      const oldCameraTrack = localStream.value.getVideoTracks().find(t => t.id === oldCameraTrackId);
      if (oldCameraTrack) {
        oldCameraTrack.stop();
        localStream.value.removeTrack(oldCameraTrack);
      }
      localStream.value.addTrack(newVideoTrack);

      return { switched: true };
    } catch (err) {
      facingMode.value = oldMode;
      return { switched: false, error: err };
    }
  };

  const checkPermissionQueries = async () => {
    if (typeof navigator !== 'undefined' && navigator.permissions && navigator.permissions.query) {
      try {
        const cam = await navigator.permissions.query({ name: 'camera' });
        if (cam.state === 'denied') isCameraDenied.value = true;
        cam.onchange = () => {
          if (cam.state === 'denied') {
            isCameraDenied.value = true;
            const idx = selectedSources.value.indexOf('camera');
            if (idx > -1) selectedSources.value.splice(idx, 1);
          } else if (cam.state === 'granted') {
            isCameraDenied.value = false;
          }
        };
      } catch (_) {}

      try {
        const mic = await navigator.permissions.query({ name: 'microphone' });
        if (mic.state === 'denied') isMicDenied.value = true;
        mic.onchange = () => {
          if (mic.state === 'denied') {
            isMicDenied.value = true;
            const idx = selectedSources.value.indexOf('mic');
            if (idx > -1) selectedSources.value.splice(idx, 1);
          } else if (mic.state === 'granted') {
            isMicDenied.value = false;
          }
        };
      } catch (_) {}
    }
  };

  const enumerateDevices = async () => {
    try {
      await checkPermissionQueries();
      if (typeof navigator !== 'undefined' && navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
        const devices = await navigator.mediaDevices.enumerateDevices();
        videoDevices.value = devices.filter(d => d.kind === 'videoinput');
        audioDevices.value = devices.filter(d => d.kind === 'audioinput');
        isDeviceEnumerated.value = true;

        if (videoDevices.value.length === 0 || isCameraDenied.value) {
          const idx = selectedSources.value.indexOf('camera');
          if (idx > -1) selectedSources.value.splice(idx, 1);
        }
        if (audioDevices.value.length === 0 || isMicDenied.value) {
          const idx = selectedSources.value.indexOf('mic');
          if (idx > -1) selectedSources.value.splice(idx, 1);
        }
      }
    } catch (e) {
      console.error('Device detection failed', e);
    }
  };

  const stopAllStreams = () => {
    const streams = [
      localStream.value,
      localScreenStream.value,
      localCameraStream.value,
    ];
    streams.forEach(s => {
      if (s && s.getTracks) {
        s.getTracks().forEach(t => t.stop());
      }
    });
  };

  const resetMediaState = () => {
    localStream.value = null;
    localScreenStream.value = null;
    localCameraStream.value = null;
  };

  return {
    castingMode,
    facingMode,
    localStream,
    localVideo,
    localScreenStream,
    localCameraStream,
    localScreenVideo,
    localCameraVideo,
    isMicMuted,
    selectedSources,
    isScreenShareSupported,
    videoDevices,
    audioDevices,
    hasCamera,
    hasMicrophone,
    isCameraDenied,
    isMicDenied,
    isCameraAvailable,
    isMicAvailable,
    hasMultipleCameras,
    toggleSource,
    getIceServers,
    captureMediaStreams,
    toggleMic,
    toggleCamera,
    enumerateDevices,
    resetMediaState,
  };
}
