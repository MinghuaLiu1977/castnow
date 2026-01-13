import { createApp } from 'vue';
import App from './App.vue';
import { inject } from '@vercel/analytics';

const app = createApp(App);
app.mount('#root');

// Initialize Vercel Web Analytics
inject();