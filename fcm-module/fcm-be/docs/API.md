# FCM 모듈 실행 프로젝트 — API 문서

이 프로젝트(`fcm`)는 **실행(런처) 전용**입니다. 모든 기능은 GitHub Packages 에 배포된
`com.ashmodule:ash-fcm-module:0.0.1-SNAPSHOT` 모듈이 제공하며, 이 프로젝트는 모듈의
`com.ashmodule.fcm.FcmApplication` 을 부팅할 뿐입니다.

> ℹ️ 모듈 자체에는 `@RestController` 가 없습니다(서비스 빈만 제공). **REST API 는 이 프로젝트
> (`com.ashmodule.fcm.domain.notification.controller`)가 모듈 서비스를 감싸 추가**한 것입니다.
> 컨트롤러/보안/CORS 클래스는 모듈의 `FcmApplication` 컴포넌트 스캔(`com.ashmodule.fcm`) 범위에
> 포함되어 자동 등록됩니다. 내부 서비스/DTO/엔티티 상세는 아래 절을 참고.

---

## 1. 실행 방법

```powershell
# 개발 모드 실행 (모듈의 application-dev.properties 로드)
./gradlew bootRun

# 실행 가능한 jar 빌드
./gradlew bootJar
java -jar build/libs/fcm-0.0.1-SNAPSHOT.jar
```

GitHub Packages(비공개) 인증이 필요합니다. Gradle 이 아래 순서로 자격증명을 찾습니다.

| 용도 | Gradle 프로퍼티 | 환경변수 (대체) | 최종 기본값 |
|---|---|---|---|
| 사용자 | `gpr.user` | `LOCAL_GITHUB_ACTOR` → `GITHUB_ACTOR` | `AnSuHan` |
| 토큰 | `gpr.token` | `LOCAL_GITHUB_TOKEN` → `GITHUB_TOKEN` | (없음) |

토큰에는 `read:packages` 권한이 필요합니다.

---

## 2. REST API

이 프로젝트가 추가한 엔드포인트입니다. 모두 `/api/**` 이며 인증 없이 호출 가능(`SecurityConfig`),
CORS 는 `app.cors.allowed-origins` 로 제어합니다. 요청/응답 본문은 JSON.

### 2.1 알림 발송 — `NotificationController`

| 메서드 | 경로 | 요청 본문 | 응답 | 설명 |
|---|---|---|---|---|
| POST | `/api/notifications` | `SendNotificationRequest` | `NotificationResponse` | 단건 발송(서버 재시도 포함) |
| POST | `/api/notifications/topic` | `SendTopicRequest` | `NotificationResponse` | 토픽 발송 |
| POST | `/api/notifications/multicast` | `SendMulticastRequest` | `MulticastResponse` | 다중 토큰 발송 |
| GET | `/api/notifications` | — (`?token=` / `?topic=`) | `Notification[]` | 이력 조회(필터 없으면 전체) |
| GET | `/api/notifications/statistics` | — (`?start=` / `?end=` ISO-8601) | `NotificationStatisticsResponse` | 발송 통계 |

요청 예시 (단건):
```http
POST /api/notifications
Content-Type: application/json

{ "token": "<device-token>", "title": "제목", "body": "내용",
  "image": null, "sound": null, "clickAction": null, "data": { "k": "v" } }
```
응답 예시:
```json
{ "messageId": "projects/.../messages/0:...", "success": true, "errorMessage": null, "errorCode": null }
```

### 2.2 예약 발송 — `ScheduledNotificationController`

| 메서드 | 경로 | 요청 본문 | 응답 | 설명 |
|---|---|---|---|---|
| POST | `/api/notifications/scheduled` | `ScheduleNotificationRequest` | `202 Accepted` | 예약 등록(실제 발송은 모듈 스케줄러가 매 분 처리) |

`ScheduleNotificationRequest` 필드: `token` 또는 `topic`(택1), `title`, `body`, `image`, `sound`,
`clickAction`, `scheduledAt`(ISO-8601 `LocalDateTime`, 예 `2030-01-01T10:00:00`).

### 2.3 토큰 관리 — `FcmTokenController`

| 메서드 | 경로 | 응답 | 설명 |
|---|---|---|---|
| GET | `/api/fcm-tokens/{token}/valid` | `{ "valid": true }` | 토큰 유효성 확인 |
| POST | `/api/fcm-tokens/{token}/invalidate` | `204 No Content` | 토큰 만료 처리(`?reason=` 선택, 기본 `MANUAL`) |

> 요청 DTO(`Send*Request`, `Schedule*Request`)는 이 프로젝트의 record 이며, 모듈의 빌더 전용
> DTO 로 매핑됩니다. 필드 정의는 5절(요청 DTO)과 동일합니다.

---

## 3. HTTP API (Actuator / Prometheus)

모듈이 `spring-boot-starter-actuator` 와 `micrometer-registry-prometheus` 를 포함하므로
다음 엔드포인트가 제공됩니다. (노출 범위는 `management.endpoints.web.exposure.include`
설정에 따름 — 기본값은 `health`, `info`.)

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/actuator/health` | 애플리케이션 상태 |
| GET | `/actuator/info` | 빌드/앱 정보 |
| GET | `/actuator/prometheus` | Prometheus 스크래핑용 메트릭 (노출 설정 시) |

### 발행되는 커스텀 메트릭

| 메트릭 이름 | 타입 | 태그 | 증가 시점 |
|---|---|---|---|
| `fcm.notifications.success` | counter | — | 단건/토픽 발송 성공 시 |
| `fcm.notifications.failed` | counter | `code`=FCM 에러코드(없으면 `UNKNOWN`) | 발송 실패 시 |

---

## 4. 서비스(프로그래밍) API

모듈이 제공하는 Spring Bean 목록입니다. 패키지: `com.ashmodule.fcm.domain.notification.service`.

### 4.1 `NotificationSendService` — 알림 발송

| 메서드 | 시그니처 | 동작 |
|---|---|---|
| 단건(비동기) | `CompletableFuture<NotificationResponse> sendAsync(NotificationSendRequest)` | 토큰 유효성 검사 후 단일 기기로 발송, 이력 저장 |
| 단건(동기·재시도) | `NotificationResponse send(NotificationSendRequest)` | `sendAsync` 의 동기 래퍼. 일시 오류 시 최대 3회 재시도(지수 백오프 1s→2s→4s) |
| 토픽(비동기) | `CompletableFuture<NotificationResponse> sendToTopicAsync(TopicNotificationRequest)` | 토픽 구독자 전체 발송 |
| 토픽(동기) | `NotificationResponse sendToTopic(TopicNotificationRequest)` | 위의 동기 래퍼 |
| 멀티캐스트(비동기) | `CompletableFuture<MulticastResponse> sendMulticastAsync(MulticastNotificationRequest)` | 다중 토큰 동시 발송, 실패 토큰 수집 |
| 멀티캐스트(동기) | `MulticastResponse sendMulticast(MulticastNotificationRequest)` | 위의 동기 래퍼 |

**동작 특징**
- 발송 결과는 `notifications` 테이블에 항상 기록됩니다(성공/실패 모두).
- FCM `UNREGISTERED` 에러 시 해당 토큰을 자동으로 만료 처리합니다(`FcmTokenManagementService.invalidateToken`).
- `INTERNAL` / `UNAVAILABLE` 에러 시 운영 알림(`OperationAlertService.sendCriticalAlert`)을 호출합니다.
- 재시도 대상 에러코드: `UNAVAILABLE`, `INTERNAL`, `QUOTA_EXCEEDED`. 재시도 소진 시 `errorCode=RETRY_EXHAUSTED` 응답.

### 4.2 `NotificationLookupService` — 발송 이력 조회 (읽기 전용)

| 메서드 | 반환 |
|---|---|
| `List<Notification> findAll()` | 전체 발송 이력 |
| `List<Notification> findByToken(String token)` | 특정 토큰 대상 이력 |
| `List<Notification> findByTopic(String topic)` | 특정 토픽 대상 이력 |

### 4.3 `NotificationScheduleService` — 예약 발송

| 메서드 | 동작 |
|---|---|
| `void schedule(ScheduledNotification)` | 예약 알림 저장 |
| `void processScheduledNotifications()` | `@Scheduled(cron = "0 * * * * *")` — 매 분, 발송 시각이 지난 미발송 예약 건을 발송하고 `sent=true` 처리 |

### 4.4 `NotificationStatisticsService` — 통계 (읽기 전용)

| 메서드 | 동작 |
|---|---|
| `NotificationStatisticsResponse getStatistics(LocalDateTime start, LocalDateTime end)` | 기간(둘 다 지정 시) 또는 전체 발송 통계. 성공률·에러 분포 계산 |

> 에러 분포 키: `INVALID_TOKEN`("Invalid token" 포함), `QUOTA_EXCEEDED`("quota" 포함), 그 외 `OTHER_ERROR`.

### 4.5 `FcmTokenManagementService` — 토큰 관리

| 메서드 | 동작 |
|---|---|
| `void invalidateToken(String token, String reason)` | 토큰 만료 처리(없으면 만료 상태로 신규 등록) |
| `boolean isTokenValid(String token)` | 유효성 확인. 정보가 없으면 `true`(유효)로 간주 |

### 4.6 `FcmTokenBatchService` — 토큰 정리 배치

| 메서드 | 동작 |
|---|---|
| `void cleanupOldInvalidTokens()` | `@Scheduled(cron = "0 0 3 * * *")` — 매일 03:00, `fcm.token.cleanup-days`(기본 30)일 이상 지난 무효 토큰 삭제 |

### 4.7 `OperationAlertService` — 운영 알림

| 메서드 | 동작 |
|---|---|
| `void sendCriticalAlert(String message)` | Slack Webhook 으로 장애 알림 전송. `fcm.alert.slack-webhook-url` 미설정 시 생략 |

---

## 5. 요청 DTO

패키지: `com.ashmodule.fcm.domain.notification.dto.request` (모두 Lombok `@Builder`)

### `NotificationSendRequest` (단건)
| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `token` | String | ✅ | 대상 기기 토큰 |
| `title` | String | ✅ | 알림 제목 |
| `body` | String | ✅ | 알림 본문 |
| `image` | String | | 이미지 URL |
| `sound` | String | | 사운드(미지정 시 `default`) |
| `clickAction` | String | | 클릭 액션 |
| `data` | Map<String,String> | | 커스텀 데이터 페이로드 |

### `TopicNotificationRequest` (토픽)
`NotificationSendRequest` 와 동일하되 `token` 대신 **`topic`**(String, 필수).

### `MulticastNotificationRequest` (멀티캐스트)
`NotificationSendRequest` 와 동일하되 `token` 대신 **`tokens`**(`List<String>`, 필수).

---

## 6. 응답 DTO

패키지: `com.ashmodule.fcm.domain.notification.dto.response`

### `NotificationResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `messageId` | String | 성공 시 FCM 메시지 ID |
| `success` | boolean | 성공 여부 |
| `errorMessage` | String | 실패 메시지 |
| `errorCode` | String | FCM `MessagingErrorCode` 또는 `RETRY_EXHAUSTED` 등 |

정적 팩토리: `NotificationResponse.success(messageId)`, `NotificationResponse.failure(errorMessage, errorCode)`

### `MulticastResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `successCount` | int | 성공 건수 |
| `failureCount` | int | 실패 건수 |
| `failedTokens` | List<String> | 실패한 토큰 목록 |

### `NotificationStatisticsResponse`
| 필드 | 타입 | 설명 |
|---|---|---|
| `totalCount` | long | 전체 건수 |
| `successCount` | long | 성공 건수 |
| `failureCount` | long | 실패 건수 |
| `successRate` | double | 성공률(%) |
| `errorDistribution` | Map<String,Long> | 에러 유형별 건수 |

---

## 7. 영속 모델 (Entity)

패키지: `com.ashmodule.fcm.domain.notification.entity`

### `Notification` → 테이블 `notifications`
`id`, `title`(NN), `body`(NN), `targetToken`, `targetTopic`, `messageId`, `success`(NN), `errorMessage`, `sentAt`(`@CreatedDate`, 갱신불가)

### `FcmToken` → 테이블 `fcm_tokens`
`id`, `token`(NN, unique), `valid`(NN, 기본 true), `lastErrorMessage`, `createdAt`(`@CreatedDate`), `updatedAt`(`@LastModifiedDate`)
- 메서드: `invalidate(reason)`, `validate()`

### `ScheduledNotification` → 테이블 `scheduled_notifications`
`id`, `title`(NN), `body`(NN), `targetToken`, `targetTopic`, `scheduledAt`(NN), `sent`(기본 false), `image`, `sound`, `clickAction`
- 메서드: `markAsSent()`

> JPA Auditing 은 모듈의 `JpaConfig`(`@EnableJpaAuditing`) 로 활성화됩니다.

---

## 8. 설정 프로퍼티

| 키 | 기본값 | 설명 |
|---|---|---|
| `fcm.service-account-path` | `firebase-service-account.json` | 클래스패스 내 Firebase 서비스 계정 JSON 경로 |
| `fcm.token.cleanup-days` | `30` | 무효 토큰 정리 기준 일수 |
| `fcm.alert.slack-webhook-url` | (빈 값) | 장애 알림용 Slack Webhook URL |
| `spring.profiles.active` | `dev` (이 프로젝트에서 지정) | 활성 프로파일 |

> Firebase 초기화는 `FcmConfig` 의 `@PostConstruct` 에서 수행되며, 서비스 계정 파일 로드에
> 실패해도 예외를 던지지 않고 로그만 남깁니다(앱은 정상 기동). 실제 발송을 하려면 유효한
> `firebase-service-account.json` 을 클래스패스에 두어야 합니다.
