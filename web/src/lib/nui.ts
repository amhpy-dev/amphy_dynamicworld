import { useEffect, useRef } from 'react'

declare global {
  interface Window {
    GetParentResourceName?: () => string
    invokeNative?: unknown
  }
}

/** True in a plain browser, where there is no NUI to talk to. */
export const isEnvBrowser = () => !window.invokeNative

/** POST to a RegisterNUICallback on the client. */
export async function fetchNui<T = unknown>(event: string, data?: unknown): Promise<T | null> {
  if (isEnvBrowser()) {
    window.dispatchEvent(new CustomEvent('dev:nui', { detail: { name: event, data } }))
    return null
  }

  const resource = window.GetParentResourceName?.() ?? 'amphy_dynamicworld'

  try {
    const response = await fetch(`https://${resource}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data ?? {})
    })

    return (await response.json()) as T
  } catch {
    return null
  }
}

/** Listen for one SendNUIMessage action. */
export function useNuiEvent<T = unknown>(action: string, handler: (data: T) => void) {
  const saved = useRef(handler)
  saved.current = handler

  useEffect(() => {
    const listener = (event: MessageEvent) => {
      if (event.data?.action === action) saved.current(event.data as T)
    }

    window.addEventListener('message', listener)
    return () => window.removeEventListener('message', listener)
  }, [action])
}
