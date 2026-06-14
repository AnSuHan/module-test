import { useEffect, useState } from 'react'
import { BACKEND_URL } from './config.js'

// provider 가 redirect 로 돌려준 모든 쿼리 파라미터를 그대로 수집
function collectRedirectParams() {
  const params = {}
  new URLSearchParams(window.location.search).forEach((value, key) => {
    params[key] = value
  })
  return params
}

// 인가 코드(code)는 1회용이라 백엔드 login 호출은 페이지당 정확히 한 번만 일어나야 한다.
// React StrictMode(dev)는 effect 를 두 번 실행하므로, 모듈 스코프 promise 로 호출을 1회만 캐시한다.
// (콜백 페이지는 매번 전체 로드되므로 이 캐시는 자연스럽게 초기화된다.)
let loginPromise = null
function loginOnce(redirectParams) {
  if (loginPromise) return loginPromise
  loginPromise = (async () => {
    const code = redirectParams.code
    const state = redirectParams.state
    const provider = localStorage.getItem('social_login_provider')

    if (redirectParams.error) {
      return 'Provider 에러: ' + JSON.stringify(redirectParams, null, 2)
    }
    if (!code || !state || !provider) {
      return '필수 파라미터가 누락되었습니다. (code/state/provider)'
    }

    try {
      const response = await fetch(`${BACKEND_URL}/auth/social/${provider}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code,
          state,
          // authorize 때의 REDIRECT_URI 와 동일해야 한다 (= origin + /callback)
          redirectUri: window.location.origin + window.location.pathname,
        }),
      })

      const data = await response.json()
      if (response.ok) {
        localStorage.removeItem('social_login_state')
        localStorage.removeItem('social_login_provider')
      }
      return `HTTP ${response.status} ${response.statusText}\n\n` + JSON.stringify(data, null, 2)
    } catch (err) {
      console.error('Login error:', err)
      return '로그인 처리 중 오류 발생: ' + err.message
    }
  })()
  return loginPromise
}

export default function CallbackPage() {
  const redirectParams = collectRedirectParams()
  const providerResult = JSON.stringify(redirectParams, null, 2)
  const [result, setResult] = useState('응답을 기다리는 중...')

  useEffect(() => {
    let cancelled = false
    loginOnce(redirectParams).then((text) => {
      if (!cancelled) setResult(text)
    })
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <main>
      <h1>Processing Login...</h1>

      <h3>Provider Redirect (received from provider):</h3>
      <pre>{providerResult}</pre>

      <h3>Backend Response:</h3>
      <pre>{result}</pre>

      <br />
      <a href="/">메인으로 돌아가기</a>
    </main>
  )
}
