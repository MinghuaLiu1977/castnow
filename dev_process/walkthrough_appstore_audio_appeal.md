# App Store 审核 (Guideline 2.5.4 - 投屏+摄像头+双向对接) 申诉 Walkthrough

## 变更与说明更新
完善针对 **投屏 (Screen Sharing) + 摄像头 (Camera Stream) + 双向对接 (Two-way Interactive Communication)** 功能的完整 App Store Connect 英文申诉文本及真机演示流程。

---

## 验证与测试结果

### 自动化单元测试
配置文件合规性单元测试验证通过：
- **mobile_ios_pro**: `apps/mobile_ios_pro/test/info_plist_test.dart` -> **Passed**
- **mobile_ios_standard**: `apps/mobile_ios_standard/test/info_plist_test.dart` -> **Passed**

---

## App Store Connect 录屏指引与申诉回复模板

### 步骤一：真机录屏演示（投屏+摄像头+双向对接）
1. 打开 CastNow 启动屏幕投屏/摄像头推流，并开启双向语音对讲。
2. 切回系统 Home 桌面或打开要演示的 App。
3. 对着麦克风说话，展示远端能实时接收本地语音；同时远端说话，展示后台依然能实时播放远端的语音。
4. 将视频上传（如 iCloud 共享链接/百度网盘/YouTube Unlisted），并填入 App Store Connect 的 `App Review Information` -> `Notes` 审核备注中。

---

### 步骤二：App Store Connect 申诉回复模板 (英文)

```text
Hello App Review Team,

Thank you for your review feedback regarding Submission 1dfb2b80-f99d-4bb9-9ca7-1dc8a867285a (Guideline 2.5.4 - Performance - Software Requirements).

We would like to clarify that CastNow is a real-time collaborative application providing Screen Sharing (Casting), Camera Video Streaming, and Two-Way Interactive Voice Communication. 

During an active session, users routinely navigate away from CastNow to the Home Screen or other apps to present slide decks, documents, or apps while maintaining live screen/video streaming and voice communication with remote peers.

While operating in the background, CastNow requires persistent background audio ("audio" in UIBackgroundModes) to support seamless two-way audio interaction during active sessions:
1. Background Microphone Streaming: Capturing local voice input so the presenter's explanations are continuously transmitted to remote participants while demonstrating other apps.
2. Background Audio Playback: Playing back incoming audio from remote peers through the speaker/headset so the user can hear questions and feedback from remote participants while outside the CastNow app.

As requested in Next Steps, we have provided a screen recording on a physical iOS device demonstrating this two-way background audio feature (both microphone streaming and remote voice playback) while navigating on the Home Screen.

You can find the video recording URL in the "Notes" section under App Review Information in App Store Connect.

Please let us know if any further information is needed. Thank you for your support and review!

Best regards,
CastNow Team
```
