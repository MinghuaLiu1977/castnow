import { createApp } from 'vue';
import { injectSpeedInsights } from '@vercel/speed-insights';
import App from './App.vue';

// Initialize Vercel Speed Insights
injectSpeedInsights();

const app = createApp(App);
app.mount('#root');