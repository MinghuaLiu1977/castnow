import { ref, computed } from 'vue';

export function useLayout() {
  const layoutMode = ref('pip');
  const isSwapped = ref(false);
  const pipPosition = ref({ x: 20, y: 20 });
  const pipWidth = ref(320);
  const splitRatio = ref(0.5);
  const dragType = ref(null);
  const isDragging = ref(false);
  const dragOffset = ref({ x: 0, y: 0 });
  const isMuted = ref(false);
  const activeCorner = ref('top-left');

  const PADDING = 20;
  const ASPECT_RATIO = 9 / 16;

  let pendingDragUpdate = false;

  const isTouchDevice = computed(() => {
    if (typeof window === 'undefined') return false;
    return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  });

  const isMobile = computed(() => {
    if (typeof navigator === 'undefined') return false;
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  });

  const pipHeight = computed(() => Math.round(pipWidth.value * ASPECT_RATIO));

  const toggleLayout = () => {
    layoutMode.value = layoutMode.value === 'pip' ? 'side-by-side' : 'pip';
  };

  const swapStreams = () => {
    isSwapped.value = !isSwapped.value;
  };

  const clampPosition = (pos, width, height, bounds) => {
    const maxX = Math.max(PADDING, bounds.width - width - PADDING);
    const maxY = Math.max(PADDING, bounds.height - height - PADDING);
    return {
      x: Math.min(Math.max(PADDING, pos.x), maxX),
      y: Math.min(Math.max(PADDING, pos.y), maxY),
    };
  };

  const calculateNearestCorner = (pos, width, height, bounds) => {
    const midX = bounds.width / 2;
    const midY = bounds.height / 2;
    const isLeft = (pos.x + width / 2) < midX;
    const isTop = (pos.y + height / 2) < midY;

    if (isTop && isLeft) return 'top-left';
    if (isTop && !isLeft) return 'top-right';
    if (!isTop && isLeft) return 'bottom-left';
    return 'bottom-right';
  };

  const snapToCorner = (corner = 'bottom-right', bounds = null) => {
    const winWidth = bounds?.width || (typeof window !== 'undefined' ? window.innerWidth : 1280);
    const winHeight = bounds?.height || (typeof window !== 'undefined' ? window.innerHeight : 720);
    const width = pipWidth.value;
    const height = pipHeight.value;

    let targetX = PADDING;
    let targetY = PADDING;

    switch (corner) {
      case 'top-left':
        targetX = PADDING;
        targetY = PADDING;
        break;
      case 'top-right':
        targetX = Math.max(PADDING, winWidth - width - PADDING);
        targetY = PADDING;
        break;
      case 'bottom-left':
        targetX = PADDING;
        targetY = Math.max(PADDING, winHeight - height - PADDING);
        break;
      case 'bottom-right':
      default:
        targetX = Math.max(PADDING, winWidth - width - PADDING);
        targetY = Math.max(PADDING, winHeight - height - PADDING);
        break;
    }

    pipPosition.value = { x: targetX, y: targetY };
    activeCorner.value = corner;
  };

  const handleDragStart = (e, type = 'move-pip') => {
    if (layoutMode.value === 'side-by-side' && type !== 'splitter') return;

    isDragging.value = true;
    dragType.value = type;

    const clientX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX;
    const clientY = e.type.includes('touch') ? e.touches[0].clientY : e.clientY;

    if (type === 'move-pip') {
      dragOffset.value = {
        x: clientX - pipPosition.value.x,
        y: clientY - pipPosition.value.y,
      };
    } else if (type === 'resize-pip') {
      dragOffset.value = {
        x: clientX,
        width: pipWidth.value,
      };
    } else if (type === 'splitter') {
      dragOffset.value = { x: clientX };
    }
  };

  const handleDragMove = (e) => {
    if (!isDragging.value) return;
    if (pendingDragUpdate) return;

    const clientX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX;
    const clientY = e.type.includes('touch') ? e.touches[0].clientY : e.clientY;

    pendingDragUpdate = true;
    requestAnimationFrame(() => {
      const bounds = {
        width: typeof window !== 'undefined' ? window.innerWidth : 1280,
        height: typeof window !== 'undefined' ? window.innerHeight : 720,
      };

      if (dragType.value === 'move-pip') {
        const rawPos = {
          x: clientX - dragOffset.value.x,
          y: clientY - dragOffset.value.y,
        };
        pipPosition.value = clampPosition(rawPos, pipWidth.value, pipHeight.value, bounds);
      } else if (dragType.value === 'resize-pip') {
        const deltaX = clientX - dragOffset.value.x;
        const newWidth = Math.min(Math.max(160, dragOffset.value.width + deltaX), bounds.width * 0.8);
        pipWidth.value = newWidth;
        pipPosition.value = clampPosition(pipPosition.value, newWidth, Math.round(newWidth * ASPECT_RATIO), bounds);
      } else if (dragType.value === 'splitter') {
        splitRatio.value = Math.min(0.9, Math.max(0.1, clientX / bounds.width));
      }
      pendingDragUpdate = false;
    });
  };

  const handleDragEnd = () => {
    if (isDragging.value && dragType.value === 'move-pip') {
      const bounds = {
        width: typeof window !== 'undefined' ? window.innerWidth : 1280,
        height: typeof window !== 'undefined' ? window.innerHeight : 720,
      };
      const nearest = calculateNearestCorner(pipPosition.value, pipWidth.value, pipHeight.value, bounds);
      snapToCorner(nearest, bounds);
    }
    isDragging.value = false;
    dragType.value = null;
  };

  const toggleMute = () => {
    isMuted.value = !isMuted.value;
  };

  const toggleFullscreen = (el) => {
    const target = el || document.querySelector('[data-receiver-root]') || document.documentElement;
    if (!document.fullscreenElement) {
      const req = target.requestFullscreen || target.webkitRequestFullscreen;
      if (req) req.call(target).catch((err) => console.log('[Layout] fullscreen failed:', err));
    } else {
      const exit = document.exitFullscreen || document.webkitExitFullscreen;
      if (exit) exit.call(document).catch(() => {});
    }
  };

  return {
    layoutMode,
    isSwapped,
    pipPosition,
    pipWidth,
    pipHeight,
    splitRatio,
    dragType,
    isDragging,
    dragOffset,
    isMuted,
    activeCorner,
    isTouchDevice,
    isMobile,
    toggleLayout,
    swapStreams,
    snapToCorner,
    clampPosition,
    calculateNearestCorner,
    handleDragStart,
    handleDragMove,
    handleDragEnd,
    toggleMute,
    toggleFullscreen,
  };
}
