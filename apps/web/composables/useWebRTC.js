import { ref, watch } from 'vue';

export function useWebRTC(getIceServers) {
  const peerId = ref('');
  const peerInstance = ref(null);
  const isConnecting = ref(false);
  const error = ref(null);
  const activeConnections = ref([]);
  const remoteDeviceInfo = ref('');
  const lastReceiverInfo = ref('');

  // Receiver state
  const joinCode = ref('');
  const remoteStream = ref(null);
  const screenStream = ref(null);
  const cameraStream = ref(null);
  const screenVideo = ref(null);
  const cameraVideo = ref(null);
  const remoteVideo = ref(null);
  const remoteRoot = ref(null);

  // Intercom state
  const isReceiverMicActive = ref(false);
  const receiverMicStream = ref(null);
  const receiverAudioStream = ref(null);
  const receiverAudioElement = ref(null);
  const activeReceiverCall = ref(null);
  const activeTalkbackCall = ref(null);

  // Free trial
  const freeTrialUsed = ref(false);
  const isPro = ref(true);

  let sessionInterval = null;

  // Watch intercom audio
  watch([receiverAudioElement, receiverAudioStream], ([el, stream]) => {
    if (el && stream) {
      el.srcObject = stream;
      // 不要强制 muted=false：静音状态由模板 :muted 绑定控制（toggleMute）
      el.play().then(() => {
        console.log('🔊 [WEBRTC] Intercom audio playback started successfully');
      }).catch(e => {
        console.error('❌ [WEBRTC] Broadcaster audio playback failed (Auto-play policy?):', e);
      });
    }
  });

  const setupRemoteVideo = async (el, stream) => {
    if (!el || !stream) return;
    el.srcObject = stream;
    el.setAttribute('playsinline', 'true');
    el.setAttribute('webkit-playsinline', 'true');
    el.load();
    try {
      await el.play();
    } catch (err) {
      if (err.name !== 'AbortError') {
        console.warn('📥 Play failed:', err);
      }
    }
  };

  watch([screenVideo, screenStream], ([el, stream]) => setupRemoteVideo(el, stream));
  watch([cameraVideo, cameraStream], ([el, stream]) => setupRemoteVideo(el, stream));
  watch([remoteVideo, remoteStream], ([el, stream]) => {
    if (el && stream && (!screenStream.value || !cameraStream.value)) {
      setupRemoteVideo(el, stream);
    }
  });

  const getOS = () => {
    const ua = navigator.userAgent;
    if (/Windows/i.test(ua)) return 'Windows';
    if (/Mac/i.test(ua)) return 'macOS';
    if (/Linux/i.test(ua)) return 'Linux';
    if (/Android/i.test(ua)) return 'Android';
    if (/iPhone|iPad|iPod/i.test(ua)) return 'iOS';
    return 'System';
  };

  const getBrowser = () => {
    const ua = navigator.userAgent;
    if (/Chrome/i.test(ua)) return 'Chrome';
    if (/Safari/i.test(ua) && !/Chrome/i.test(ua)) return 'Safari';
    if (/Firefox/i.test(ua)) return 'Firefox';
    if (/Edg/i.test(ua)) return 'Edge';
    return 'Browser';
  };

  const handlePeerError = (err, showFirefoxGuideRef) => {
    console.error('PeerJS Error:', err);
    if (err.type === 'unavailable-id') {
      error.value = 'Code collision. Please try again.';
    } else if (err.type === 'network') {
      error.value = 'Network error. Check connection/firewall.';
    } else if (err.type === 'browser-incompatible' || (err.message && err.message.includes('not support WebRTC'))) {
      if (showFirefoxGuideRef) showFirefoxGuideRef.value = true;
      error.value = null;
      return;
    } else {
      error.value = `Connection failed. Check code.: ${err.message}`;
    }
    isConnecting.value = false;
  };

  const setupCallHandlers = (call) => {
    call.on('stream', (rs) => {
      // Audio track from iOS broadcaster (remote speaker)
      const audioTracks = rs.getAudioTracks();
      if (audioTracks.length > 0) {
        const audioStream = new MediaStream(audioTracks);
        receiverAudioStream.value = audioStream;
        console.log('🔊 [WebRTC] Remote audio tracks received:', audioTracks.length);
      }
    });

    if (call.peerConnection) {
      call.peerConnection.ontrack = (event) => {
        if (event.track.kind === 'audio') {
          const stream = event.streams[0] || new MediaStream([event.track]);
          receiverAudioStream.value = stream;
          // Ensure track is enabled
          event.track.enabled = true;
          console.log('🔊 [WebRTC] ontrack audio received, enabled:', event.track.enabled);
        }
      };
    }

    call.on('error', (err) => {
      console.error('Call Error:', err);
    });

    call.on('close', () => {
      activeConnections.value = activeConnections.value.filter(c => c.peer !== call.peer);
    });
  };

  const startSenderPeer = (code, localStream, showFirefoxGuideRef, showToast, setAppState, STATES, resetApp) => {
    const peer = new window.Peer(code, {
      debug: 1,
      config: {
        iceServers: getIceServers(),
        sdpSemantics: 'unified-plan',
      },
    });

    peerInstance.value = peer;
    peer.on('open', (id) => {
      peerId.value = id;
      isConnecting.value = false;
    });

    peer.on('call', (incomingCall) => {
      if (incomingCall.peer.startsWith('cnv_')) {
        const parts = incomingCall.peer.split('_');
        if (parts.length >= 3) {
          lastReceiverInfo.value = `${parts[1]} on ${parts[2]}`;
        }
      }

      if (incomingCall.metadata && !lastReceiverInfo.value) {
        const payload = incomingCall.metadata;
        if (payload && payload.type === 'dev') {
          lastReceiverInfo.value = `${payload.browser || 'Browser'} on ${payload.os}`;
        }
      }

      incomingCall.close();

      setTimeout(() => {
        if (!localStream.value) return;
        const forwardCall = peer.call(incomingCall.peer, localStream.value);
        setupCallHandlers(forwardCall);
        
        // CRITICAL FIX: Force downscale of the video stream on the sender side!
        // Browsers often ignore max width/height in getDisplayMedia for Retina screens,
        // resulting in massive 15K streams that crash the iOS Metal renderer.
        if (forwardCall.peerConnection) {
          const senders = forwardCall.peerConnection.getSenders();
          senders.forEach(sender => {
            if (sender.track && sender.track.kind === 'video') {
              const params = sender.getParameters();
              if (!params.encodings) {
                params.encodings = [{}];
              }
              // Downscale by 2 or 4 depending on how large the track is, or just hardcode maxBitrate.
              // To be safe for 15K streams, we'll downscale by 4. If it's a normal screen, downscale by 2.
              const settings = sender.track.getSettings();
              let scaleFactor = 1;
              if (settings.width) {
                  if (settings.width >= 7000) scaleFactor = 4;
                  else if (settings.width >= 3000) scaleFactor = 2;
              }
              
              console.log(`📡 [WebRTC Sender] Track size: ${settings.width}x${settings.height}, Downscaling by: ${scaleFactor}`);
              
              if (scaleFactor > 1) {
                  params.encodings[0].scaleResolutionDownBy = scaleFactor;
                  sender.setParameters(params)
                      .then(() => console.log(`✅ [WebRTC Sender] Downscale applied successfully.`))
                      .catch(e => console.error('❌ [WebRTC Sender] Failed to set encoding params', e));
              }
            }
          });
        }
      }, 1000);
    });

    peer.on('error', (err) => handlePeerError(err, showFirefoxGuideRef));
  };

  const startReceiverPeer = (code, setAppState, STATES, showToast, resetApp) => {
    const browser = getBrowser().replace(/\s+/g, '');
    const os = getOS().replace(/\s+/g, '');
    const randomPart = Math.random().toString(36).substring(7);
    const richId = `cnv_${browser}_${os}_${randomPart}`;

    const peer = new window.Peer(richId, {
      config: {
        iceServers: getIceServers(),
        sdpSemantics: 'unified-plan',
      },
    });

    peerInstance.value = peer;

    peer.on('open', (id) => {
      console.log('[WebRTC] Knocking to peer:', code);
      
      const tracks = receiverMicStream.value ? receiverMicStream.value.getTracks() : [];
      const streamToSend = new MediaStream(tracks);
      
      // Force video and audio transceiver generation in the Offer by adding dummy tracks if needed
      try {
        const canvas = document.createElement('canvas');
        canvas.width = 1;
        canvas.height = 1;
        const canvasStream = canvas.captureStream(1);
        const dummyVideoTrack = canvasStream.getVideoTracks()[0];
        if (dummyVideoTrack && streamToSend.getVideoTracks().length === 0) {
          streamToSend.addTrack(dummyVideoTrack);
        }
        
        // Also force audio just in case receiverMicStream was empty (e.g. mic permission denied)
        if (streamToSend.getAudioTracks().length === 0) {
          const AudioContext = window.AudioContext || window.webkitAudioContext;
          if (AudioContext) {
            const ctx = new AudioContext();
            const dest = ctx.createMediaStreamDestination();
            const dummyAudioTrack = dest.stream.getAudioTracks()[0];
            if (dummyAudioTrack) {
              streamToSend.addTrack(dummyAudioTrack);
            }
          }
        }
      } catch (e) {
        console.warn('Could not create dummy tracks:', e);
      }

      const knockCall = peer.call(code, streamToSend);

      const timeout = setTimeout(() => {
        if (!document.querySelector('[data-receiver-root]')) {
          isConnecting.value = false;
          error.value = '连接失败，请检查配对码。';
        }
      }, 10000);

      knockCall.on('error', (err) => {
        console.log('[WebRTC] Knock error:', err.type, err.message);
        clearTimeout(timeout);
        error.value = '连接失败，请检查配对码。';
        isConnecting.value = false;
      });
    });

    peer.on('call', (call) => {
      activeReceiverCall.value = call;
      setAppState(STATES.RECEIVER_ACTIVE);
      isConnecting.value = false;

      // Answer with mic stream if available; iOS needs to receive this to enable remote speaker
      const micStream = receiverMicStream.value;
      call.answer(micStream || undefined);
      console.log('📞 [WebRTC] Answered iOS call, mic stream tracks:', micStream?.getTracks().length ?? 0);

      call.on('close', () => {
        if (resetApp) resetApp();
      });

      call.on('stream', (rs) => {
        // Enable all received tracks immediately
        rs.getTracks().forEach(t => { t.enabled = true; });

        const audioTracks = rs.getAudioTracks();
        if (audioTracks.length > 0) {
          receiverAudioStream.value = new MediaStream(audioTracks);
          console.log('🔊 [WebRTC] Receiver got remote audio from iOS, tracks:', audioTracks.length);
        }

        if (call.peerConnection) {
          call.peerConnection.oniceconnectionstatechange = () => {
            const state = call.peerConnection.iceConnectionState;
            console.log('🔗 [WebRTC] ICE state:', state);
            if (state === 'failed' || state === 'closed') {
              if (resetApp) resetApp();
            } else if (state === 'disconnected') {
              // disconnected 可自愈：iOS 后台恢复 + ICE 重启需较长时间，给 15 秒恢复期
              setTimeout(() => {
                if (call.peerConnection &&
                    call.peerConnection.iceConnectionState === 'disconnected') {
                  console.warn('🔗 [WebRTC] ICE stuck disconnected 15s → reset');
                  if (resetApp) resetApp();
                }
              }, 15000);
            }
          };

          call.peerConnection.ontrack = () => {
            updateSplitStreams(call);
          };
        }

        const checkAllTracksEnded = () => {
          if (!rs) return;
          const liveTracks = rs.getTracks().filter(t => t.readyState === 'live');
          if (liveTracks.length === 0) {
            if (resetApp) resetApp();
          }
        };

        rs.getTracks().forEach(track => {
          track.onended = () => checkAllTracksEnded();
        });

        updateSplitStreams(call);
        setTimeout(() => updateSplitStreams(call), 1000);
        setTimeout(() => updateSplitStreams(call), 2500);

        // 视频诊断：每 3 秒打印接收状态（定位黑屏：无数据 vs 解码失败）
        if (!window.__castnowDiag) {
          window.__castnowDiag = setInterval(async () => {
            const el = document.querySelector('video');
            const track = screenStream.value?.getVideoTracks()[0];
            let bytes = 0, fps = 0, codec = '';
            try {
              const stats = await call.peerConnection?.getStats();
              stats?.forEach(s => {
                if (s.type === 'inbound-rtp' && s.kind === 'video') {
                  bytes = s.bytesReceived; fps = s.framesPerSecond || 0;
                  const codecId = s.codecId;
                  if (codecId && stats.get(codecId)) codec = stats.get(codecId).mimeType;
                }
              });
            } catch (e) { /* ignore */ }
            console.log(`📊 [diag] video ${el?.videoWidth ?? '-'}x${el?.videoHeight ?? '-'} ready=${el?.readyState ?? '-'} muted=${track?.muted ?? '-'} recv=${(bytes/1024).toFixed(0)}KB fps=${fps} codec=${codec}`);
          }, 3000);
        }
      });
    });

    peer.on('error', (err) => {
      handlePeerError(err, null);
      joinCode.value = '';
    });
  };

  const updateSplitStreams = (call) => {
    const currentStream = call.remoteStream;
    if (!currentStream) return;

    const videoTracks = currentStream.getVideoTracks();
    const audioTracks = currentStream.getAudioTracks();

    if (videoTracks.length > 0) {
      screenStream.value = new MediaStream([videoTracks[0], ...audioTracks]);
    }

    if (videoTracks.length > 1) {
      cameraStream.value = new MediaStream([videoTracks[1]]);
    } else {
      cameraStream.value = null;
      remoteStream.value = new MediaStream(currentStream.getTracks());
    }
  };

  const toggleReceiverMic = async (showToastFn) => {
    if (!receiverMicStream.value) {
      showToastFn('Microphone access denied', 'error');
      return;
    }
    isReceiverMicActive.value = !isReceiverMicActive.value;
    receiverMicStream.value.getAudioTracks().forEach(t => {
      t.enabled = isReceiverMicActive.value;
    });
    if (isReceiverMicActive.value) {
      showToastFn('Microphone ON', 'success');
    } else {
      showToastFn('Microphone OFF', 'info');
    }
  };

  const closeActiveCalls = () => {
    if (activeReceiverCall.value) {
      try {
        activeReceiverCall.value.close();
      } catch (e) {
        console.warn('Call close failed (likely already gone)', e);
      }
      activeReceiverCall.value = null;
    }
  };

  const destroyPeer = () => {
    if (peerInstance.value) {
      peerInstance.value.destroy();
      peerInstance.value = null;
    }
    if (sessionInterval) {
      clearInterval(sessionInterval);
      sessionInterval = null;
    }
  };

  const cleanUpStreams = () => {
    if (window.__castnowDiag) {
      clearInterval(window.__castnowDiag);
      window.__castnowDiag = null;
    }
    const streams = [
      remoteStream.value,
      screenStream.value,
      cameraStream.value,
      receiverMicStream.value,
      receiverAudioStream.value,
    ];
    streams.forEach(s => {
      if (s && s.getTracks) {
        s.getTracks().forEach(t => t.stop());
      }
    });
  };

  const resetState = () => {
    peerId.value = '';
    remoteStream.value = null;
    screenStream.value = null;
    cameraStream.value = null;
    activeReceiverCall.value = null;
    joinCode.value = '';
    isConnecting.value = false;
    error.value = null;
    lastReceiverInfo.value = '';
    remoteDeviceInfo.value = '';
    receiverAudioStream.value = null;
  };

  const persistTrial = () => {
    if (!isPro.value && !freeTrialUsed.value) {
      freeTrialUsed.value = true;
      localStorage.setItem('free_trial_used', 'true');
    }
  };

  return {
    peerId,
    peerInstance,
    isConnecting,
    error,
    activeConnections,
    remoteDeviceInfo,
    lastReceiverInfo,
    joinCode,
    remoteStream,
    screenStream,
    cameraStream,
    screenVideo,
    cameraVideo,
    remoteVideo,
    isReceiverMicActive,
    receiverMicStream,
    receiverAudioStream,
    receiverAudioElement,
    activeReceiverCall,
    activeTalkbackCall,
    freeTrialUsed,
    isPro,
    setupCallHandlers,
    startSenderPeer,
    startReceiverPeer,
    toggleReceiverMic,
    closeActiveCalls,
    destroyPeer,
    cleanUpStreams,
    resetState,
    persistTrial,
    getOS,
    getBrowser,
    handlePeerError,
  };
}
