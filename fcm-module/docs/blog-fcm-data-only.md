# FCM 알림, 앱이 꺼져 있어도 뜨게 만들기 — notification vs data-only 그리고 백그라운드 핸들러

스프링 부트 백엔드에서 FCM(Firebase Cloud Messaging) 푸시를 보내고, Flutter 앱에서 받는 구조를 만들었다. 그런데 막상 붙여보니 "앱이 떠 있을 때만 알림이 뜨고, 백그라운드/종료 상태에서는 동작이 들쭉날쭉한" 전형적인 문제에 부딪혔다.

이 글은 그 문제의 원인(= FCM 메시지 종류)을 정리하고, **data-only 방식으로 전환해서 앱이 모든 상태에서 동일하게 알림을 만들도록** 바꾼 과정을 모듈 / 백엔드 / 프론트 세 층으로 나눠 정리한 기록이다.

---

## 0. 전체 구조

```
ash-fcm-module (라이브러리, GitHub Packages 배포)
        │  발송/조회/통계/예약/토큰 서비스 빈 제공
        ▼
fcm-be (실행 전용 런처)
        │  모듈 서비스를 REST(/api/notifications)로 감쌈
        ▼
fcm-fe (Flutter 테스트 앱)
        │  토큰 발급 + 수신/표시
```

- **모듈(`ash-fcm-module`)**: FCM 발송 로직 자체. 다른 프로젝트에서도 의존성만 추가하면 자동 구성(Auto-configuration)되도록 라이브러리로 분리했다.
- **백엔드(`fcm-be`)**: 모듈을 부팅하고 REST API로 노출하는 얇은 런처. 비즈니스 로직은 없다.
- **프론트(`fcm-fe`)**: 폰의 FCM 토큰을 발급받아 화면에 표시하고, 백엔드가 보낸 메시지를 받아 기기 알림을 띄우는 테스트 앱.

---

## 1. 먼저 알아야 할 것 — FCM 메시지에는 3가지 종류가 있다

FCM 페이로드는 크게 `notification` 블록과 `data` 블록으로 나뉘고, 어떤 걸 싣느냐에 따라 **앱 상태별 동작이 완전히 달라진다.** 이게 모든 혼란의 근원이다.

| 메시지 종류 | 포그라운드(앱 켜짐) | 백그라운드 / 종료 |
|---|---|---|
| **notification 만** | OS 자동표시 안 함 → `onMessage` 콜백으로만 전달 | **OS가 시스템 트레이에 자동표시**. 앱 코드는 실행 안 됨 |
| **data 만 (data-only)** | `onMessage` 로 전달 (자동표시 없음) | **`onBackgroundMessage` 핸들러를 깨워 실행**. 앱이 직접 표시 |
| **notification + data** | `onMessage` (자동표시 없음) | OS가 notification 자동표시 + data 동반 |

여기서 핵심 함정 두 가지:

1. **포그라운드에서는 어떤 방식이든 OS가 알림을 자동으로 안 띄운다.** 앱이 켜져 있으면 무조건 콜백으로만 들어온다. 그래서 "앱 켜놓고 테스트하면 알림이 안 뜬다"는 경험을 하게 된다.
2. **notification 방식의 백그라운드 표시는 앱 코드를 거치지 않는다.** OS가 알아서 띄우는 거라, 알림 모양/동작을 앱에서 커스텀할 수 없고 탭하기 전엔 앱 코드가 돌지 않는다.

> 정리하면, "앱이 죽어 있어도 백엔드가 쏘면 **앱이 살아나서** 알림을 만든다"는 건 **data-only 방식에서만** 성립한다. notification 방식은 앱이 죽은 채로 OS가 대신 띄워주는 것이다.

---

## 2. 1차 시도 — notification + data 병행, 그리고 "data 복제"

처음에는 `notification + data`를 함께 보냈다. 백그라운드는 OS가 자동표시해주니 편하다. 문제는 **포그라운드**. 포그라운드에서는 `onMessage`로만 들어오는데, 이때 `notification` 블록의 정보로 직접 알림을 띄워줘야 한다.

그래서 모듈에서 발송할 때 **표시 정보(title/body/image/click_action)를 `data` 페이로드에도 복제**하도록 했다. 그래야 앱이 어떤 상태든 `data`만 보고 동일하게 알림을 구성할 수 있다.

```java
// 표시 정보를 data 페이로드에도 복제 — 포그라운드에서도 같은 정보로 알림을 만들 수 있게.
private Map<String, String> buildDataPayload(String title, String body, String image,
                                             String clickAction, Map<String, String> data) {
    Map<String, String> payload = new HashMap<>();
    if (title != null) payload.put("title", title);
    if (body != null)  payload.put("body", body);
    if (image != null) payload.put("image", image);
    if (clickAction != null) payload.put("click_action", clickAction);
    if (data != null)  payload.putAll(data); // 호출자가 지정한 키가 우선
    return payload;
}
```

추가로 **Android 신뢰성**을 위해 두 가지를 손봤다.

- `AndroidConfig` 우선순위를 `HIGH`로 — Doze/대기 모드에서도 기기를 즉시 깨워 전달.
- Android 8(Oreo)+ 에서 알림 표시에 필수인 **알림 채널 ID**를 페이로드에 지정 (`fcm.android.default-channel-id`, 기본값 `default`). 클라이언트는 같은 ID의 채널을 만들어둬야 한다.

여기까지 하면 포그라운드/백그라운드 모두 알림이 뜬다. 하지만 한 가지가 계속 걸렸다 — **상태에 따라 알림을 만드는 주체가 다르다는 것.** 포그라운드는 앱이, 백그라운드는 OS가 만든다. 알림 모양을 통일하거나, 종료 상태에서 앱 로직(예: 로컬 DB 기록, 커스텀 처리)을 태우고 싶으면 이 이원화가 발목을 잡는다.

---

## 3. 2차 — data-only로 전환, 표시 주체를 "앱"으로 통일

그래서 **data-only**로 바꿨다. `notification` 블록을 아예 빼면 OS는 자동표시를 하지 않고, 대신 **포그라운드/백그라운드/종료 어느 상태든 앱의 핸들러가 호출**된다. 알림을 만드는 주체가 항상 "앱" 하나로 통일되는 것이다.

### 3-1. 모듈: data-only 토글 추가

모듈에 `fcm.message.data-only` 프로퍼티(기본 `false`)를 두고, `true`면 `notification` 블록을 싣지 않도록 분기했다. 단건/토픽/멀티캐스트 발송 모두 동일하게 적용.

```java
@Value("${fcm.message.data-only:false}")
private boolean dataOnly;

Message.Builder builder = Message.builder()
        .setToken(request.getToken())
        .setAndroidConfig(createAndroidConfig(request.getSound(), request.getClickAction()))
        .setApnsConfig(createApnsConfig(request.getSound(), request.getClickAction()))
        .putAllData(buildDataPayload(/* title/body/image/click_action + data */));

if (!dataOnly) {
    // 기본 모드에서만 notification 블록을 싣는다 (백그라운드 OS 자동표시용).
    builder.setNotification(createFcmNotification(title, body, image));
}
```

`AndroidConfig`도 data-only일 때는 `AndroidNotification`(OS 표시용)을 빼고 우선순위만 HIGH로 남긴다.

```java
private AndroidConfig createAndroidConfig(String sound, String clickAction) {
    AndroidConfig.Builder builder = AndroidConfig.builder()
            .setPriority(AndroidConfig.Priority.HIGH); // Doze 에서도 즉시 깨움
    if (!dataOnly) {
        builder.setNotification(AndroidNotification.builder()
                .setSound(sound != null ? sound : "default")
                .setClickAction(clickAction)
                .setChannelId(defaultChannelId)
                .build());
    }
    return builder.build();
}
```

**iOS는 별도 처리가 필요하다.** iOS에서 data-only(무음 푸시)는 `content-available=1` 헤더가 있어야 백그라운드에서 앱을 깨운다.

```java
private ApnsConfig createApnsConfig(String sound, String clickAction) {
    if (dataOnly) {
        // iOS 무음 푸시: content-available=1 로 백그라운드에서 앱을 깨운다. alert 미포함.
        return ApnsConfig.builder()
                .putHeader("apns-priority", "5")
                .setAps(Aps.builder().setContentAvailable(true).build())
                .build();
    }
    return ApnsConfig.builder()
            .setAps(Aps.builder()
                    .setSound(sound != null ? sound : "default")
                    .setCategory(clickAction)
                    .build())
            .build();
}
```

### 3-2. 백엔드(런처): 프로퍼티만 켜기

모듈이 토글을 제공하니 런처는 설정만 바꾸면 된다. 코드 수정 없음.

```properties
# data-only 발송: notification 블록 없이 data 페이로드만 보낸다.
# → OS 자동표시 대신, 앱이 모든 상태에서 백그라운드 핸들러로 직접 알림을 생성.
fcm.message.data-only=true

# Android 8+ 알림 채널 ID — 클라이언트 앱이 동일 ID 채널을 만들어둬야 표시된다.
fcm.android.default-channel-id=default
```

발송 API는 그대로다. 예를 들어 단건 발송:

```http
POST /api/notifications
Content-Type: application/json

{
  "token": "폰 앱이 표시한 FCM 토큰",
  "title": "테스트 알림",
  "body": "백엔드에서 보낸 메시지입니다",
  "data": { "screen": "home" }
}
```

### 3-3. 프론트: 백그라운드 핸들러 구현

data-only로 바꾸면 **OS가 더 이상 알림을 자동으로 안 띄우므로**, 백그라운드/종료 상태 수신을 처리하는 `onBackgroundMessage` 핸들러를 반드시 직접 구현해야 한다. 이게 핵심이다.

여기서 가장 자주 실수하는 포인트:

- 백그라운드 핸들러는 **별도 isolate**에서 실행된다. `main()`에서 초기화해 둔 Firebase, 로컬 알림 플러그인, 채널이 **공유되지 않는다.** 핸들러 안에서 **다시 초기화**해야 한다.
- 핸들러는 반드시 **최상위(top-level) 함수**여야 하고 `@pragma("vm:entry-point")`를 붙여야 한다 (release 빌드에서 tree-shaking으로 잘려나가는 걸 막음).

```dart
// 별도 isolate 라 main() 의 초기화가 공유되지 않으니 여기서 다시 초기화한다.
@pragma("vm:entry-point")
Future<void> _bg(RemoteMessage m) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initLocalNotifications(); // 플러그인 + Android 채널 재생성
  final title = m.data['title'] ?? m.notification?.title ?? "No Title";
  final body  = m.data['body']  ?? m.notification?.body  ?? "";
  await _showDeviceNotification(title, body);
}
```

`main()`에서 핸들러를 등록한다.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb && !Platform.isWindows) {
    FirebaseMessaging.onBackgroundMessage(_bg); // 백그라운드/종료 수신
  }
  await _initLocalNotifications();
  runApp(const MyApp());
}
```

포그라운드 수신(`onMessage`)도 같은 방식으로 `data`를 우선 읽어 알림을 띄운다. 그래서 fg/bg/종료 **세 경로가 동일한 표시 로직**을 쓰게 된다.

```dart
FirebaseMessaging.onMessage.listen((msg) {
  final title = msg.data['title'] ?? msg.notification?.title ?? "No Title";
  final body  = msg.data['body']  ?? msg.notification?.body  ?? "";
  _showDeviceNotification(title, body);
});
```

알림 채널은 **백엔드가 보낸 채널 ID와 정확히 일치**해야 Android 8+에서 표시된다.

```dart
const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'default',            // ← 백엔드 fcm.android.default-channel-id 와 동일해야 함
  'Default',
  description: 'FCM 알림',
  importance: Importance.high, // 헤드업(상단 배너)
);
```

---

## 4. data-only의 트레이드오프 (꼭 알아둘 것)

data-only는 "앱이 표시 주체"라는 일관성을 주지만, 공짜가 아니다.

| | notification 방식 | data-only 방식 |
|---|---|---|
| 백그라운드/종료 표시 | **OS가 보장** (앱 못 깨워도 뜸) | 앱(백그라운드 isolate)이 깨어나야만 뜸 |
| 표시 커스텀 / 앱 로직 | 제한적 (탭해야 앱 실행) | 자유 (항상 앱 코드 실행) |
| 신뢰성 리스크 | 낮음 | 강제 종료·공격적 배터리 최적화 시 미표시 가능 |

특히 안드로이드에서:

- 사용자가 설정에서 **강제 종료(force-stop)** 한 앱은 백그라운드 isolate가 깨지 않는다 → 알림 안 뜸.
- **샤오미/화웨이/오포** 등 공격적인 OEM 배터리 최적화는 백그라운드 깨우기를 막는 경우가 있다.
- 일반적인 스와이프 종료 + `priority: high`면 깨어난다.

즉 **"무조건 떠야 하는 중요 알림"이면 notification 방식이 더 안전**하고, **"앱이 받아서 가공·표시까지 일관되게 제어"가 중요하면 data-only**가 맞다. 우리는 후자가 목적이라 data-only를 택했다.

> 참고: Windows는 FCM 수신 자체를 지원하지 않아, 데스크톱에서는 발송 테스트 용도로만 쓰고 표시는 로컬 알림으로 대체했다.

---

## 5. 마무리 체크리스트

data-only로 갈 때 빠뜨리기 쉬운 것들:

- [ ] 백엔드: `notification` 블록 제거, `data`에 표시 정보 포함, Android priority HIGH
- [ ] iOS: APNs `content-available=1` (무음 푸시)
- [ ] 프론트: `onBackgroundMessage` 핸들러를 **top-level + `@pragma("vm:entry-point")`** 로 구현
- [ ] 핸들러 내부에서 Firebase·로컬 알림 플러그인·채널 **재초기화** (isolate 분리)
- [ ] **백엔드 채널 ID == 프론트 채널 ID** (Android 8+ 필수)
- [ ] 포그라운드/백그라운드/종료 세 경로가 같은 표시 로직을 타는지 확인
- [ ] 강제 종료/배터리 최적화 환경에서의 미표시 가능성을 감안

푸시는 "보내면 무조건 뜬다"가 아니라, **메시지 종류 × 앱 상태 × OS 정책**의 조합으로 동작이 결정된다. 이 표를 머릿속에 넣어두면 디버깅 시간이 확 줄어든다.
