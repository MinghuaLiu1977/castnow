import { describe, it, expect } from 'vitest';
import { useMediaStream } from './composables/useMediaStream';
import { getDefaultLocale } from './composables/useI18n';
import zhMessages from './public/locales/zh.json';
import enMessages from './public/locales/en.json';

describe('CastNow Web Transition and Source Selection Logic', () => {
  it('should determine default locale based on hostname correctly', () => {
    expect(getDefaultLocale('castnow.padap.cn', 'en-US')).toBe('zh');
    expect(getDefaultLocale('castnow.vercel.app', 'zh-CN')).toBe('en');
    expect(getDefaultLocale('my-preview.vercel.app', 'zh-CN')).toBe('en');
    expect(getDefaultLocale('localhost', 'zh-CN')).toBe('zh');
    expect(getDefaultLocale('localhost', 'en-US')).toBe('en');
  });

  it('should have distinct primary button titles for landing and source select in locales', () => {
    expect(zhMessages.landing.broadcast).toBe('发起投屏');
    expect(zhMessages.source.start).toBe('确认并开始投屏');
    expect(zhMessages.landing.broadcast).not.toBe(zhMessages.source.start);

    expect(enMessages.landing.broadcast).toBe('Start Cast');
    expect(enMessages.source.start).toBe('Confirm & Start');
    expect(enMessages.landing.broadcast).not.toBe(enMessages.source.start);
  });

  it('should compute isScreenShareSupported and export stopAllStreams function correctly', () => {
    const media = useMediaStream();
    expect(typeof media.isScreenShareSupported.value).toBe('boolean');
    expect(typeof media.stopAllStreams).toBe('function');
  });

  it('should handle camera and microphone availability and denial checks correctly', () => {
    const media = useMediaStream();
    expect(typeof media.hasCamera.value).toBe('boolean');
    expect(typeof media.hasMicrophone.value).toBe('boolean');
    expect(media.isCameraDenied.value).toBe(false);
    expect(media.isMicDenied.value).toBe(false);

    media.isCameraDenied.value = true;
    expect(media.isCameraAvailable.value).toBe(false);
    media.toggleSource('camera');
    expect(media.selectedSources.value).not.toContain('camera');

    media.isMicDenied.value = true;
    expect(media.isMicAvailable.value).toBe(false);
    media.toggleSource('mic');
    expect(media.selectedSources.value).not.toContain('mic');
  });

  it('should handle toggleSource correctly when screen is unsupported', () => {
    const media = useMediaStream();
    if (!media.isScreenShareSupported.value) {
      expect(media.selectedSources.value).not.toContain('screen');
      media.toggleSource('screen');
      expect(media.selectedSources.value).not.toContain('screen');
    }
  });
});
