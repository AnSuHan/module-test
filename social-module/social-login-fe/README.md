# social-login-fe

`social-login-be`(소셜 로그인 백엔드)를 브라우저에서 직접 테스트하기 위한 **정적 프론트엔드**입니다.
빌드 단계 없이 HTML 2개(`index.html`, `callback.html`)로 OAuth2 인가 코드 흐름 전체를 수동 검증합니다.

> 검증 상태(2026-05-31): 이 FE로 **Google / Kakao / Naver 로그인 전체 성공** 확인.

---

## 1. 구성 파일

| 파일 | 역할 |
|---|---|
| `index.html` | Google/Kakao/Naver 로그인 버튼. `GET /authorize` 호출 후 공급자 인가 페이지로 리다이렉트 |
| `callback.html` | 공급자가 `code`+`state`를 붙여 돌려주는 콜백 페이지. `POST /login` 호출 후 결과(JWT 등) 표시 |
| `package.json` | `serve`로 정적 서버 실행 (포트 **3005**) |
| `serve.json` | `serve` 설정 (`cleanUrls:false`, `trailingSlash:false`) |

백엔드 주소는 두 HTML 모두 `const BACKEND_URL = 'http://localhost:8080'` 로 하드코딩되어 있습니다.

---

## 2. 동작 흐름

```
[index.html]                          [social-login-be :8080]        [Social Provider]
  ① 버튼 클릭
  └─ GET /auth/social/{provider}/authorize?redirectUri=.../callback.html
                                        │ state 생성·DB 저장
  ◀──────────── {authorizationUrl, state} ┘
  ② state·provider 를 localStorage 저장
  └─ authorizationUrl 로 이동 ───────────────────────────────────────▶ ③ 로그인/동의
[callback.html]  ◀── code+state 로 리다이렉트 ───────────────────────────┘
  ④ 쿼리의 code/state + localStorage 의 provider 로
     POST /auth/social/{provider}/login  { code, state, redirectUri }
  ◀──────────── {accessToken, refreshToken, expiresIn} ──────────────
  ⑤ 응답을 화면에 출력하고 localStorage 정리
```

- `index.html`: `redirectUri`는 현재 경로 기준 `.../callback.html`로 계산해 `authorize`에 전달.
- 발급받은 `state`/`provider`는 `localStorage`(`social_login_state`, `social_login_provider`)에 저장.
- `callback.html`: `login` 호출 시 `redirectUri`는 `window.location.origin + pathname`(= 콜백 URL)을
  보내며, **`authorize` 때와 동일해야** 합니다(불일치 시 백엔드가 거부).
- 공급자가 에러(`?error=...`)를 돌려주거나 `code/state/provider`가 누락되면 화면에 사유를 표시합니다.

---

## 3. 실행 방법

### 3.1 사전 조건
- `social-login-be`가 `http://localhost:8080`에서 기동 중일 것 (`./gradlew bootRun`).
- 각 공급자 콘솔에 **이 FE의 콜백 URL**(`http://localhost:3005/callback.html`)이
  redirect URI로 등록되어 있을 것.

### 3.2 정적 서버 기동
```bash
npm install      # 최초 1회 (serve 설치)
npm start        # = serve -l 3005 .  →  http://localhost:3005
```
이후 브라우저에서 `http://localhost:3005/index.html` 접속 → 원하는 공급자 버튼 클릭.

> **포트 주의:** 백엔드 CORS(`CorsConfig`)는 `3005`, `5173`, `5500`, `5000` origin을 허용합니다.
> 다른 포트로 띄우면 CORS 차단되므로, 포트를 바꾸면 백엔드 `CorsConfig`의 `allowedOrigins`도 함께 추가하세요.

---

## 4. 관련 백엔드 문서

- 엔드포인트/요청·응답 스펙: `../social-login-be/docs/API.md`
- 전체 아키텍처(호스트-모듈 구조): `../social-login-be/docs/ARCHITECTURE.md`
- 제공 기능: `../social-login-be/docs/FEATURES.md`
