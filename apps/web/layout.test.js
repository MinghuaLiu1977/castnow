import { describe, it, expect } from 'vitest';
import { useLayout } from './composables/useLayout';

describe('useLayout Composable & PiP Magnetic Snapping', () => {
  it('should initialize with default pip mode and correct initial values', () => {
    const layout = useLayout();
    expect(layout.layoutMode.value).toBe('pip');
    expect(layout.isSwapped.value).toBe(false);
    expect(layout.isMuted.value).toBe(false);
    expect(layout.pipWidth.value).toBe(320);
    expect(layout.pipHeight.value).toBe(180);
    expect(layout.splitRatio.value).toBe(0.5);
  });

  it('should toggle layout mode between pip and side-by-side', () => {
    const layout = useLayout();
    expect(layout.layoutMode.value).toBe('pip');
    layout.toggleLayout();
    expect(layout.layoutMode.value).toBe('side-by-side');
    layout.toggleLayout();
    expect(layout.layoutMode.value).toBe('pip');
  });

  it('should toggle swapped state correctly', () => {
    const layout = useLayout();
    expect(layout.isSwapped.value).toBe(false);
    layout.swapStreams();
    expect(layout.isSwapped.value).toBe(true);
    layout.swapStreams();
    expect(layout.isSwapped.value).toBe(false);
  });

  it('should clamp position within screen bounds', () => {
    const layout = useLayout();
    const bounds = { width: 1000, height: 800 };
    const width = 300;
    const height = 200;

    // Test negative coordinates (out of bounds top/left)
    const clampedNegative = layout.clampPosition({ x: -50, y: -20 }, width, height, bounds);
    expect(clampedNegative.x).toBe(20);
    expect(clampedNegative.y).toBe(20);

    // Test excessive coordinates (out of bounds bottom/right)
    const clampedExcessive = layout.clampPosition({ x: 900, y: 750 }, width, height, bounds);
    expect(clampedExcessive.x).toBe(1000 - width - 20); // 680
    expect(clampedExcessive.y).toBe(800 - height - 20); // 580

    // Test valid inside coordinates
    const clampedInside = layout.clampPosition({ x: 200, y: 300 }, width, height, bounds);
    expect(clampedInside.x).toBe(200);
    expect(clampedInside.y).toBe(300);
  });

  it('should calculate nearest corner correctly based on position', () => {
    const layout = useLayout();
    const bounds = { width: 1000, height: 800 };
    const width = 200;
    const height = 100;

    // Top-Left quadrant
    expect(layout.calculateNearestCorner({ x: 50, y: 50 }, width, height, bounds)).toBe('top-left');

    // Top-Right quadrant
    expect(layout.calculateNearestCorner({ x: 700, y: 50 }, width, height, bounds)).toBe('top-right');

    // Bottom-Left quadrant
    expect(layout.calculateNearestCorner({ x: 50, y: 600 }, width, height, bounds)).toBe('bottom-left');

    // Bottom-Right quadrant
    expect(layout.calculateNearestCorner({ x: 700, y: 600 }, width, height, bounds)).toBe('bottom-right');
  });

  it('should snap to target corners accurately', () => {
    const layout = useLayout();
    const bounds = { width: 1200, height: 800 };

    layout.snapToCorner('top-left', bounds);
    expect(layout.pipPosition.value).toEqual({ x: 20, y: 20 });
    expect(layout.activeCorner.value).toBe('top-left');

    layout.snapToCorner('top-right', bounds);
    expect(layout.pipPosition.value).toEqual({ x: 1200 - layout.pipWidth.value - 20, y: 20 });
    expect(layout.activeCorner.value).toBe('top-right');

    layout.snapToCorner('bottom-left', bounds);
    expect(layout.pipPosition.value).toEqual({ x: 20, y: 800 - layout.pipHeight.value - 20 });
    expect(layout.activeCorner.value).toBe('bottom-left');

    layout.snapToCorner('bottom-right', bounds);
    expect(layout.pipPosition.value).toEqual({
      x: 1200 - layout.pipWidth.value - 20,
      y: 800 - layout.pipHeight.value - 20,
    });
    expect(layout.activeCorner.value).toBe('bottom-right');
  });
});
