import { createApp } from 'vue'
import App from './App.vue'
// Import a simple CSS reset or global styles if you have one
// import './assets/main.css' 

// PWA Service Worker registration - vite-plugin-pwa handles this if injectRegister is 'auto'
// If you need custom registration, you can do it here.
// import { registerSW } from 'virtual:pwa-register'
// if ('serviceWorker' in navigator) {
//   registerSW({ immediate: true })
// }


const app = createApp(App)
app.mount('#app')
