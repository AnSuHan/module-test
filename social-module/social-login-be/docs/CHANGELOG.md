# Changelog

이 프로젝트(`social-login-be`)의 모든 주요 변경 사항은 이 파일에 기록됩니다.

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 따르며,
이 프로젝트는 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 준수합니다.

## [0.0.1-SNAPSHOT] - 2026-05-31

### Verified
- **실제 소셜 로그인 E2E 성공 (Google / Kakao / Naver 전체).**
  - `social-login-fe`(정적 테스트 FE: `index.html` → `callback.html`)로 인가 → 콜백 → 토큰 발급까지 확인.
  - 각 공급자에서 `code`↔토큰 교환 + UserInfo 조회 후 모듈 자체 JWT(access/refresh) 발급 성공.
  - state 1회성 검증 및 콜백 `redirectUri` 일치 확인.

### Docs
- `docs/API.md` 검증 상태를 2026-05-31 기준으로 갱신 (4.3 실제 로그인 E2E 결과 추가).
- `social-login-fe/README.md` 신규 작성 (테스트 FE 동작·실행 방법 문서화).

## [0.0.1-SNAPSHOT] - 2026-05-30

### Added
- `com.ashmodule:ash-social-module:0.0.1-SNAPSHOT` 초기 통합.
  - 소셜 로그인 인가 및 토큰 발급 기능 확보.
- PostgreSQL 데이터소스 설정.
  - `persistence.mode=jpa`, `datasource.mode=shared` 설정을 통해 호스트의 DB 재사용.
- 주요 소셜 로그인 공급자 활성화 및 시드 데이터 구성.
  - Google, Kakao, Naver 지원.
- `.env` 파일 지원 및 Gradle 빌드 스크립트 연동.
  - `spring-dotenv` 및 Gradle `loadDotenv` 로직을 통해 환경 변수 주입.
- 초기 API 문서(`docs/API.md`) 작성.
- 통합 테스트 및 실기동 API 테스트를 통한 모듈 연동성 검증 완료.
