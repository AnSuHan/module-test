# social-login-fe / webapp

`social-login-be`(소셜 로그인 백엔드)를 **웹앱(React + Vite) 형태**로 테스트하기 위한 프론트엔드입니다.
빌드 없이 HTML 2개로 검증하는 [`../vanilla-html`](../vanilla-html)와 동일한 OAuth2 인가 코드 흐름을,
컴포넌트/상태 기반의 SPA로 재구성합니다.

> 현재 상태: **로그인/콜백 화면 구현 완료.**
> - 로그인 화면(`/`): Google / Kakao / Naver 버튼 3개 → `GET /authorize` 후 공급자로 이동
> - 콜백 화면(`/callback.html`): 공급자가 돌려준 파라미터 표시 + `POST /login` 응답(JWT 등) 표시
> - 라우터 라이브러리 없이 `pathname`으로 두 화면을 분기 (각 단계가 전체 페이지 로드)
> - **포트·콜백 경로를 vanilla-html과 동일하게(`http://localhost:3005/callback.html`)** 맞춰,
>   공급자 콘솔에 이미 등록된 redirect URI를 그대로 재사용한다(추가 등록 불필요).

---

## 스택

| 항목 | 값 |
|---|---|
| 프레임워크 | React |
| 번들러/dev 서버 | Vite (멀티 페이지: `index.html` + `callback.html`) |
| dev 포트 | `3005` (고정, `vite.config.js`의 `strictPort`) |
| 콜백 경로 | `/callback.html` (vanilla-html과 동일) |
| 백엔드 | `http://localhost:8080` |

> **포트 주의:** vanilla-html과 **같은 3005 포트**를 사용한다. 따라서 둘을 **동시에 띄울 수 없고**
> 하나씩 실행한다. 같은 redirect URI(`http://localhost:3005/callback.html`)를 공유하므로
> 공급자 콘솔 재등록이 필요 없다.
> (백엔드 CORS 허용 origin: `3005`, `5173`, `5500`, `5000`. 다른 포트를 쓰면 `CorsConfig`에 추가 필요.)

---

## 실행 방법

> ⚠️ `vanilla-html`은 `npm start`지만, **webapp은 `npm run dev`** 입니다 (Vite 기본 스크립트).

```bash
cd webapp
npm install      # 최초 1회 (이미 설치돼 있으면 생략)
npm run dev      # = vite  →  http://localhost:3005
```

| 명령 | 동작 |
|---|---|
| `npm run dev` | 개발 서버 실행 (HMR) → http://localhost:3005 |
| `npm run build` | 프로덕션 번들 빌드 (`dist/`, `index.html`+`callback.html`) |
| `npm run preview` | 빌드 결과물 미리보기 서버 |
| `npm run lint` | ESLint 검사 |

사전 조건:
- `social-login-be`가 `http://localhost:8080`에서 기동 중이어야 합니다.
- 같은 3005 포트를 쓰는 **vanilla-html이 실행 중이면 먼저 종료**하세요(포트 충돌).
- 콜백 URL은 vanilla-html과 동일한 **`http://localhost:3005/callback.html`** 이므로,
  vanilla-html로 이미 검증했다면 공급자 콘솔에 **추가 등록이 필요 없습니다.**

---

## 흐름 (vanilla-html과 동일)

1. 로그인 버튼 → `GET /auth/social/{provider}/authorize?redirectUri=...` → 공급자 인가 페이지로 이동
2. 콜백 라우트에서 `code`+`state` 수신 → `POST /auth/social/{provider}/login` → 토큰 응답 표시

자세한 흐름과 백엔드 스펙은 [`../vanilla-html/README.md`](../vanilla-html/README.md)와
`../../social-login-be/docs/API.md`를 참고하세요.
