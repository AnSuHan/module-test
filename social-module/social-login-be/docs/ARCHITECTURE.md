# Architecture

이 프로젝트는 **호스트-모듈 구조**를 따르며, 핵심 비즈니스 로직은 `ash-social-module`에 위임되어 있습니다.

## 1. 전체 구조

```mermaid
graph TD
    FE[social-login-fe (정적 테스트 FE)] <--> Host[social-login-be (Host App)]
    FE <--> Providers[Social Providers (Google, Kakao, Naver)]
    Host <--> Module[ash-social-module]
    Module <--> DB[(PostgreSQL)]
    Module <--> Providers
```

> 브라우저 클라이언트로는 동일 리포의 `social-login-fe`(정적 `index.html`/`callback.html`)를
> 사용하며, 이 FE로 Google/Kakao/Naver 로그인 전체 흐름이 검증되었습니다(2026-05-31).
> 상세는 `social-login-fe/README.md` 참고.

## 2. 주요 컴포넌트

### 호스트 애플리케이션 (`social-login-be`)
- **역할**: 실행 환경(Spring Boot), 데이터베이스 연결, 외부 설정 제공.
- **핵심 파일**:
  - `SocialLoginApplication.java`: 메인 엔트리 포인트.
  - `application.yml`: 모듈 활성화 및 DB 설정.
  - `build.gradle`: 의존성 관리 및 빌드 설정.

### 소셜 로그인 모듈 (`ash-social-module`)
- **AutoConfiguration**: `SocialLoginAutoConfiguration`을 통해 컨트롤러, 서비스, 보안 설정을 자동 등록.
- **Web Layer**: `/auth/social/**` 경로의 API 제공.
- **Persistence Layer**: `SocialProviderConfigRepository`, `OAuthStateRepository` 등을 통해 DB 연동.
- **Service Layer**: OAuth2 프로토콜 처리 및 JWT 생성.

## 3. 데이터 흐름

1. **인가 요청**: Client -> Host(`/authorize`) -> Module(URL 생성 & State 저장) -> Client
2. **소셜 인증**: Client -> Social Provider -> Client(Callback with code)
3. **토큰 요청**: Client -> Host(`/login`) -> Module(Code 검증 & UserInfo 획득 & JWT 생성) -> Client

## 4. 확장 포인트

- **신규 공급자 추가**: `SocialLoginProvider` 인터페이스를 구현하여 새로운 소셜 로그인 수단을 동적으로 추가할 수 있습니다.
- **커스텀 필터/보안**: 호스트의 `SecurityFilterChain` 설정을 통해 모듈 엔드포인트의 보안 정책을 조정할 수 있습니다.
