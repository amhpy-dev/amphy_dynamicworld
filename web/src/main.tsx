import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import 'leaflet/dist/leaflet.css'
import './index.css'
import App from './App'
import { isEnvBrowser } from './lib/nui'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
)

if (import.meta.env.DEV && isEnvBrowser()) {
  void import('./dev/mock').then(({ start }) => setTimeout(start, 100))
}
