import { useState } from 'react'
import { BACKEND_URL, REDIRECT_URI } from './config.js'

const PROVIDERS = [
  { id: 'google', label: 'Google Login' },
  { id: 'kakao', label: 'Kakao Login' },
  { id: 'naver', label: 'Naver Login' },
]

export default function LoginPage() {
  const [error, setError] = useState('')

  async function authorize(provider) {
    setError('')
    try {
      const url = `${BACKEND_URL}/auth/social/${provider}/authorize?redirectUri=${encodeURIComponent(REDIRECT_URI)}`
      const response = await fetch(url)
      const data = await response.json()

      if (response.ok) {
        localStorage.setItem('social_login_state', data.state)
        localStorage.setItem('social_login_provider', provider)
        window.location.assign(data.authorizationUrl)
      } else {
        setError('Error: ' + (data.message || 'Unknown error'))
      }
    } catch (err) {
      console.error('Authorize error:', err)
      setError('백엔드 서버가 실행 중인지 확인하세요. (' + err.message + ')')
    }
  }

  return (
    <main>
      <h1>Social Login Test (webapp)</h1>
      <div className="buttons">
        {PROVIDERS.map((p) => (
          <button key={p.id} onClick={() => authorize(p.id)}>
            {p.label}
          </button>
        ))}
      </div>
      {error && <p className="error">{error}</p>}
    </main>
  )
}
