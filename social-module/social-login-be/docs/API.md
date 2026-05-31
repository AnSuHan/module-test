# social-login-be API 문서

이 애플리케이션은 [`com.ashmodule:ash-social-module`](https://github.com/AshModule/ash-social-module) `0.0.1-SNAPSHOT` 을
통합한 **소셜 로그인 테스트 백엔드** 입니다. 아래 HTTP 엔드포인트는 모두 모듈의 AutoConfiguration
(`SocialLoginAutoConfiguration`)이 자동 등록한 것으로, 호스트(본 앱)는 의존성·설정만 제공합니다.

- 스택: Spring Boot 4.1.0-RC1 / Java 25 / Spring Security 6.x
- 영속성: `persistence.mode=jpa`, `datasource.mode=shared` → 호스트의 PostgreSQL DataSource 재사용
- Base path: `/auth/social` (`ash.social-login.web.base-path`)
- 인증: 모듈 엔드포인트는 기본 `SecurityFilterChain` 에서 `permitAll` (`{base-path}/**`)

---

## 1. 실행 방법

### 1.1 사전 준비

| 항목 | 값 |
|---|---|
| JDK | 25 (Gradle toolchain 이 자동 사용) |
| PostgreSQL | 로컬 `localhost:5432`, DB `ash_social` |
| GitHub Packages | `ash-social-module` 가 private 패키지라 `read:packages` 토큰 필요 |

### 1.2 모듈 의존성 (GitHub Packages 인증)

`build.gradle` 에 GitHub Packages 저장소가 등록되어 있습니다. 자격증명은 다음 중 하나로 제공합니다.

- 환경변수: `LOCAL_GITHUB_TOKEN` (username 기본값 `AnSuHan`), 또는
- `~/.gradle/gradle.properties`:
  ```properties
  gpr.user=<github-username>
  gpr.token=<personal-access-token, read:packages>
  ```

### 1.3 자격증명 / 설정 (`.env`)

`.env.example` 를 복사해 `.env` 를 만들고 값을 채웁니다. `build.gradle` 의 `bootRun`/`test` 태스크가
`.env` 를 읽어 환경변수로 주입합니다(Spring 이 `application.yml` 의 `${...}` 플레이스홀더로 해석).

```dotenv
ASH_SOCIAL_DB_USERNAME=postgres
ASH_SOCIAL_DB_PASSWORD=0000
ASH_SOCIAL_TOKEN_SECRET=dev-only-change-me-please-0123456789abcdef   # 32자 이상 필수
GOOGLE_CLIENT_ID=...        # 실제 로그인 테스트 시 채우기 (미설정 시 더미값)
GOOGLE_CLIENT_SECRET=...
```

> spring-dotenv 가 Spring Boot 4 에서 `.env` 를 자동 인식하지 못해, Gradle 태스크에서 직접 `.env` 를
> 주입하도록 구성했습니다. IDE 등 Gradle 밖에서 실행할 때는 동일한 키를 OS 환경변수로 설정하세요.

### 1.4 기동

```bash
./gradlew bootRun          # http://localhost:8080
```

기동 시 모듈이 `ash_provider_config`, `ash_oauth_state` 등 자체 테이블을 생성하고
(`ddl-auto=update`), `ash.social-login.seed.providers.*` 의 provider 설정을 DB 에 적재합니다.

---

## 2. HTTP 엔드포인트

### 공통 에러 응답

```json
{ "code": "INVALID_STATE", "message": "상세 메시지" }
```

| HTTP | code | 발생 상황 |
|---|---|---|
| 400 | `INVALID_REQUEST` | 요청 필드 누락/공백, Bean Validation 실패 |
| 401 | `INVALID_CODE` | 소셜 공급자가 인증 코드를 거부 |
| 401 | `INVALID_STATE` | state 없거나 만료됨 (CSRF 검증 실패) |
| 404 | `UNSUPPORTED_PROVIDER` | 등록되지 않은 provider |
| 502 | `PROVIDER_ERROR` | 소셜 공급자 API 호출 실패 |

---

### 2.1 `GET /auth/social/{provider}/authorize`

소셜 공급자 인가 URL 과 CSRF `state` 를 발급합니다. 클라이언트는 반환된 `authorizationUrl` 로
사용자를 리다이렉트하고, `state` 를 보관했다가 콜백 시 검증에 사용합니다.

**Path / Query**

| 위치 | 이름 | 타입 | 필수 | 설명 |
|---|---|---|---|---|
| path | `provider` | string | ✓ | `google` / `kakao` / `naver` |
| query | `redirectUri` | string | | 미전달 시 우선순위: 요청 파라미터 → `provider.<id>.redirect-uri` → DB |

**Response 200**

```json
{
  "authorizationUrl": "https://accounts.google.com/o/oauth2/v2/auth?response_type=code&client_id=...&redirect_uri=...&scope=openid+email+profile&state=...&nonce=...",
  "state": "QEugmoRskYkqdwpxONfJe1MI4gi7mKkKSJsBOU5aQjw"
}
```

**예시**

```bash
curl "http://localhost:8080/auth/social/google/authorize"
```

미등록 provider →

```bash
curl -i "http://localhost:8080/auth/social/foobar/authorize"
# HTTP 404  {"code":"UNSUPPORTED_PROVIDER","message":"No provider configuration stored for providerId=foobar"}
```

---

### 2.2 `POST /auth/social/{provider}/login`

소셜 공급자로부터 받은 인증 코드와 `state` 를 검증하고 모듈 자체 JWT 토큰을 발급합니다.
`state` 는 검증 즉시 삭제됩니다(one-time use).

**Path**

| 이름 | 타입 | 설명 |
|---|---|---|
| `provider` | string | `google` / `kakao` / `naver` |

**Request Body** (`application/json`)

```json
{
  "code": "OAuth 인증 코드 (필수)",
  "state": "authorize 단계에서 받은 state (필수)",
  "redirectUri": "선택 — authorize 와 동일해야 함"
}
```

**Response 200**

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<jwt>",
  "expiresIn": 3600
}
```

발급 토큰은 HS256 서명 JWT 이며 `sub`, `iss`, `iat`, `exp`, `email`, `name` 클레임을 포함합니다.
리프레시 토큰에는 `token_type=refresh` 가 추가됩니다.

**예시 (state 미존재 → 401)**

```bash
curl -i -X POST "http://localhost:8080/auth/social/google/login" \
  -H "Content-Type: application/json" \
  -d '{"code":"x","state":"nope"}'
# HTTP 401  {"code":"INVALID_STATE","message":"OAuth state 를 찾을 수 없습니다: providerId=google, state=nope"}
```

> 실제 토큰 발급까지 보려면 유효한 `client-id`/`client-secret`(`.env` 의 `GOOGLE_CLIENT_ID` 등)과
> 소셜 공급자 콘솔에 등록된 `redirect-uri`, 그리고 실제 OAuth 콜백으로 받은 `code` 가 필요합니다.

---

## 3. 설정 요약 (`application.yml`)

| 키 | 본 앱 설정값 | 의미 |
|---|---|---|
| `ash.social-login.persistence.mode` | `jpa` | provider 설정·OAuth state 를 RDB 에 저장 |
| `ash.social-login.datasource.mode` | `shared` | 호스트의 `spring.datasource` 재사용 |
| `ash.social-login.datasource.ddl-auto` | `update` | 모듈 테이블 자동 생성 (운영은 `validate` + `docs/db/schema.sql` 권장) |
| `ash.social-login.token.secret` | `${ASH_SOCIAL_TOKEN_SECRET}` | HS256 서명 키 (32자+) |
| `ash.social-login.web.base-path` | `/auth/social` | 엔드포인트 base path |
| `ash.social-login.provider.{google,kakao,naver}.enabled` | `true` | 레퍼런스 공급자 활성화 |
| `ash.social-login.seed.providers.*` | (더미 키) | 기동 시 DB 에 upsert 되는 provider 설정 |

전체 설정 키·확장 포인트(SPI)는 모듈 저장소의 `docs/API.md`, `docs/FEATURES.md` 를 참고하세요.

---

## 4. 검증 상태 (2026-05-31)

로컬 PostgreSQL 18 + JDK 25 환경에서 다음을 확인했습니다.

### 4.1 기동 / 인프라
- `./gradlew bootRun` 기동 성공 (Spring Boot 4.1.0-RC1, Tomcat 8080).
- 모듈 테이블 자동 생성: `ash_provider_config`(+`_scopes`/`_extra`), `ash_oauth_state`.
- 시드 적재: `google`/`kakao`/`naver` provider 설정이 DB 에 upsert 됨.

### 4.2 엔드포인트 단위
- `GET /auth/social/google/authorize` → **200**, Google 인가 URL + state/nonce 발급, state 가 DB 에 저장됨.
- `GET /auth/social/foobar/authorize` → **404 UNSUPPORTED_PROVIDER**.
- `POST /auth/social/google/login` (잘못된 state) → **401 INVALID_STATE**.

### 4.3 실제 소셜 로그인 E2E (✅ Google / Kakao / Naver 전체 성공)
실제 공급자 콘솔에 등록한 client-id/secret 과 `social-login-fe`(정적 테스트 FE, `index.html` → `callback.html`)
를 사용해 **3개 공급자 모두 전체 OAuth2 Authorization Code 흐름을 통과**했습니다.

- `GET /authorize` → 공급자 동의 화면 리다이렉트 → 콜백으로 `code`+`state` 수신.
- `POST /{provider}/login` → code↔토큰 교환 + UserInfo 조회 → **모듈 자체 JWT(accessToken/refreshToken) 발급 성공**.
- 검증된 공급자: **Google ✅ / Kakao ✅ / Naver ✅**.
- state 1회성 검증(one-time use) 및 콜백 redirectUri 일치 확인.
