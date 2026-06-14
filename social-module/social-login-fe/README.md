# social-login-fe

`social-login-be`(소셜 로그인 백엔드)를 브라우저에서 테스트하기 위한 프론트엔드 모음입니다.
구현 방식별로 폴더를 나눠 두 가지 테스트 클라이언트를 제공합니다.

| 폴더 | 방식 | 설명 |
|---|---|---|
| [`vanilla-html/`](vanilla-html) | 정적 HTML | 빌드 없이 `index.html` + `callback.html` 2개로 OAuth2 흐름을 수동 검증. `serve`로 포트 **3005**에서 실행. |
| [`webapp/`](webapp) | React + Vite | 동일한 흐름을 SPA로 재구성한 웹앱. 콜백 화면까지 구현 완료. vanilla-html과 같은 포트 **3005**·콜백 경로(`/callback.html`)를 사용. |

두 클라이언트 모두 백엔드 `http://localhost:8080`을 대상으로 동작합니다.
**둘 다 포트 3005를 사용하므로 동시에 띄울 수 없고, 하나씩 실행**합니다. 같은 redirect URI
(`http://localhost:3005/callback.html`)를 공유하므로 공급자 콘솔 등록은 한 번이면 됩니다.

## 빠른 시작

> 두 폴더의 실행 명령이 다릅니다 — vanilla-html은 `npm start`, webapp은 `npm run dev`. (포트는 둘 다 3005, 동시 실행 불가)

```bash
# 정적 HTML (포트 3005)
cd vanilla-html && npm install && npm start

# 웹앱 (포트 3005) — vanilla-html을 띄웠다면 먼저 종료
cd webapp && npm install && npm run dev
```

자세한 내용은 [`vanilla-html/README.md`](vanilla-html/README.md), [`webapp/README.md`](webapp/README.md) 참고.

## 관련 백엔드 문서

- 엔드포인트/요청·응답 스펙: `../social-login-be/docs/API.md`
- 전체 아키텍처: `../social-login-be/docs/ARCHITECTURE.md`
