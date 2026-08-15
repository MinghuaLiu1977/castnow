
import { createApp } from 'vue';
import App from './App.vue';
import './style.css';

const app = createApp(App);

// 全局错误兜底：渲染异常时显示错误条而不是整页白屏
const showErrorBar = (msg) => {
  let bar = document.getElementById('global-error-bar');
  if (!bar) {
    bar = document.createElement('div');
    bar.id = 'global-error-bar';
    bar.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:99999;background:#dc2626;color:#fff;padding:8px 16px;font:600 12px/1.4 system-ui;word-break:break-all';
    document.body.appendChild(bar);
  }
  bar.textContent = 'Error: ' + msg;
};
app.config.errorHandler = (err) => {
  console.error('[Vue]', err);
  showErrorBar(err?.message || String(err));
};
window.addEventListener('error', (e) => showErrorBar(e.message));

app.mount('#root');

// PWA Service Worker Registration
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    // Register from root /sw.js which Vite serves from public/sw.js
    navigator.serviceWorker.register('/sw.js')
      .then(reg => console.log('Service Worker registered', reg))
      .catch(err => console.error('Service Worker registration failed', err));
  });
}
