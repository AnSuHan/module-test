// 백엔드 주소. vanilla-html과 동일하게 하드코딩.
export const BACKEND_URL = 'http://localhost:8080'

// OAuth 인가 후 공급자가 브라우저를 돌려보낼 콜백 URL.
// 공급자 콘솔에 등록된 값(= vanilla-html과 동일한 http://localhost:3005/callback.html)과
// 정확히 일치해야 한다. authorize 요청과 login 요청 모두 이 값을 사용한다.
export const REDIRECT_URI = window.location.origin + '/callback.html'
