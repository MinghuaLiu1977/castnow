# ⚡️ CastNow

**CastNow** is a high-performance, serverless P2P screen sharing engine built for the modern web. No installations, no plugins, no account creation. Just high-fidelity casting directly between browsers.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Deployed on Vercel](https://img.shields.io/badge/Vercel-Deployed-black?logo=vercel)](https://castnow.vercel.app)
[![Vue Version](https://img.shields.io/badge/Vue-3.x-4fc08d?logo=vue.js)](https://vuejs.org)

---

## 💎 The Vision

Traditional screen-sharing tools like TeamViewer or Zoom introduce unnecessary friction: bloated desktop clients, mandatory sign-ups, and centralized servers that sit in the middle of your data.

**CastNow** changes the paradigm:
- **Zero-Trust & Privacy-First**: Your media stream never touches our servers. It stays encrypted in the P2P tunnel between you and your recipient.
- **Zero Friction**: If you have a browser, you have a broadcasting studio. No `.exe` or `.dmg` files required.
- **Sub-Second Latency**: Optimized WebRTC handshakes for real-time collaboration.

---

## 🚀 Key Features

- **⚡️ Zero-Config Handshake**: Generate a 6-digit access key and start streaming in seconds.
- **🔒 E2EE P2P Tunneling**: Leveraging WebRTC and PeerJS for direct, secure browser-to-browser communication.
- **📺 4K & High-FPS Support**: Native resolution broadcasting limited only by your hardware and bandwidth.
- **🌍 Geo-Optimized**: Intelligent STUN/ICE routing that automatically selects the lowest-latency nodes based on your region (including optimized nodes for Mainland China).
- **📱 Responsive Player**: A cinema-grade viewing experience with full-screen support and adaptive layout.

---

## 🛠 Tech Stack

- **Framework**: [Vue 3](https://vuejs.org/) (Composition API)
- **Build Tool**: [Vite](https://vitejs.dev/)
- **Styling**: [Tailwind CSS](https://tailwindcss.com/)
- **Protocol**: [WebRTC](https://webrtc.org/) via [PeerJS](https://peerjs.com/)
- **Icons**: [Lucide Vue Next](https://lucide.dev/)
- **Insights**: [Vercel Web Analytics](https://vercel.com/analytics)

---

## 💻 Self-Hosting & Development

CastNow is designed to be easily deployable on any static hosting provider.

### 1. Clone the repository
```bash
git clone https://github.com/MinghuaLiu1977/castnow.git
cd castnow
```

### 2. Install dependencies
```bash
npm install
```

### 3. Run development server
```bash
npm run dev
```

### 4. Build for production
```bash
npm run build
```

---

## 🗺 Roadmap

- [x] P2P Media Handshake
- [x] Regional STUN Optimization
- [x] Vercel Analytics Integration
- [ ] **CastNow Pro (Coming Soon)**: Dedicated relay servers (TURN) for restricted corporate networks.
- [ ] **Local Discovery**: Cast to devices on your same Wi-Fi without entering a code.
- [ ] **Multi-Receiver Mode**: Broadcast to up to 5 peers simultaneously.
- [ ] **Mobile Source Support**: Experimental screen capture for Android/iOS browsers.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  Built with 💛 by the CastNow Engineering Team.
</p>