import LoginPage from './LoginPage.jsx'
import CallbackPage from './CallbackPage.jsx'

// OAuth 흐름은 매번 전체 페이지 이동(공급자로 나갔다가 callback.html 로 복귀)이므로
// 클라이언트 라우터 없이 pathname 으로 두 화면을 분기한다. (vanilla-html의 두 HTML 파일과 동일한 구조)
// 콜백 경로는 바닐라와 동일한 /callback.html.
export default function App() {
  const isCallback = window.location.pathname.endsWith('callback.html')
  return isCallback ? <CallbackPage /> : <LoginPage />
}
