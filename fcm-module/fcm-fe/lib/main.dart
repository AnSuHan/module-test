import "dart:convert";
import "dart:io";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'firebase_options.dart';

// ── 백그라운드/종료 상태 수신 핸들러 ───────────────────────────────────
// data-only 발송이므로 OS 가 알림을 자동 표시하지 않는다. 앱이 백그라운드이거나 종료돼
// 있어도 FCM 이 이 핸들러를 별도 isolate 에서 깨워 실행하므로, 여기서 직접 기기 알림을 띄운다.
// 별도 isolate 라 main() 의 초기화(_localNotifications, 채널)가 공유되지 않으니 다시 초기화한다.
@pragma("vm:entry-point")
Future<void> _bg(RemoteMessage m) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _initLocalNotifications();
  final title = m.data['title'] ?? m.notification?.title ?? "No Title";
  final body = m.data['body'] ?? m.notification?.body ?? "";
  await _showDeviceNotification(title, body);
}

// ── 포그라운드 알림 표시 ─────────────────────────────────────────────
// FCM 은 앱이 포그라운드일 때 notification 블록을 자동 표시하지 않고 onMessage 로만
// 전달한다. 그래서 수신 시 직접 기기 알림을 띄운다. 백엔드(ash-fcm-module)가 표시 정보를
// data 페이로드에도 복제하므로, 앱 상태와 무관하게 동일 정보로 알림을 구성할 수 있다.

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// 백엔드 fcm.android.default-channel-id 와 반드시 동일해야 Android 8+ 에서 알림이 표시된다.
const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'default',
  'Default',
  description: 'FCM 포그라운드 알림',
  importance: Importance.high, // 헤드업(상단 배너) 표시
);

// flutter_local_notifications 로 실제 알림을 띄우는 플랫폼인지 (모바일/macOS).
bool get _supportsLocalNotifications =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

Future<void> _initLocalNotifications() async {
  if (!_supportsLocalNotifications) return;
  await _localNotifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    ),
  );
  // Android 8+ 채널 생성 (백엔드가 채널 id 'default' 로 전송).
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_defaultChannel);
}

Future<void> _showDeviceNotification(String title, String body) async {
  if (_supportsLocalNotifications) {
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'default',
          'Default',
          channelDescription: 'FCM 포그라운드 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  } else if (!kIsWeb && Platform.isWindows) {
    // Windows 는 FCM 수신 자체가 미지원이지만, 일관성을 위해 local_notifier 로 표시.
    LocalNotification(title: title, body: body).show();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isWindows) {
    await localNotifier.setup(
      appName: 'fcm_fe',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb && !Platform.isWindows) {
      FirebaseMessaging.onBackgroundMessage(_bg);
    }
    await _initLocalNotifications();
  } catch (e) {}
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: FcmHome());
  }
}

class FcmHome extends StatefulWidget {
  const FcmHome({super.key});
  @override
  State<FcmHome> createState() => _S();
}

class _S extends State<FcmHome> {
  String? _t;
  String _s = "Ready";
  final List<String> _n = [];
  // 화면에서 바로 확인하는 프론트 로그(요청/응답/에러). 최신이 위로.
  final List<String> _log = [];
  final TextEditingController _urlCtrl =
      TextEditingController(text: _defaultBackendUrl());

  // 받는 기기(폰)의 FCM 토큰. PC 에서 폰으로 보내려면 폰 앱이 표시한 토큰을 여기에 붙여넣는다.
  final TextEditingController _targetCtrl = TextEditingController();

  // 안드로이드 에뮬레이터는 10.0.2.2 가 호스트 PC. 데스크톱/웹은 localhost.
  // 실기기는 PC 의 LAN IP(예: http://192.168.0.10:8080)로 바꿔 입력.
  static String _defaultBackendUrl() {
    if (kIsWeb) return "http://localhost:8080";
    if (Platform.isAndroid) return "http://10.0.2.2:8080";
    return "http://localhost:8080";
  }

  // 사용자가 프론트에서 직접 커스텀하는 메시지 필드들.
  final TextEditingController _titleCtrl = TextEditingController(text: "Test");
  final TextEditingController _bodyCtrl = TextEditingController(text: "Msg");
  final TextEditingController _imageCtrl = TextEditingController();
  final TextEditingController _soundCtrl = TextEditingController();
  final TextEditingController _clickActionCtrl = TextEditingController();
  // 커스텀 data 페이로드(key-value 쌍). 비어 있으면 전송에서 제외.
  final List<_DataEntry> _data = [];

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _targetCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageCtrl.dispose();
    _soundCtrl.dispose();
    _clickActionCtrl.dispose();
    for (final e in _data) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _setup() async {
    if (!kIsWeb && Platform.isWindows) {
      setState(() => _s = "Windows: FCM 수신 미지원 (발송 전용)");
      _addLog("Windows 플랫폼: FCM 토큰 없음(정상). 발송 전용으로 사용.");
      return;
    }

    try {
      var m = FirebaseMessaging.instance;
      var s = await m.requestPermission(alert: true, badge: true, sound: true);
      _addLog("알림 권한 상태: ${s.authorizationStatus}");

      // 중요: FCM 토큰은 알림 표시 권한과 무관하게 발급된다.
      // 권한이 denied/provisional 이어도 토큰은 받아야 하므로 무조건 시도한다.
      // (Web 은 VAPID 키가 필요할 수 있음: m.getToken(vapidKey: 'YOUR_VAPID_KEY'))
      final token = await m.getToken();
      _t = token;
      if (token == null) {
        setState(() => _s = "토큰 획득 실패 (null)");
        _addLog("getToken() = null — Play Services/네트워크/설정 확인 필요");
      } else {
        // 받는 토큰이 비어있으면 같은 기기 테스트용으로 자기 토큰을 채워준다.
        if (_targetCtrl.text.trim().isEmpty) _targetCtrl.text = token;
        setState(() => _s = "토큰 획득 완료");
        _addLog("getToken() OK (len=${token.length})");
        // 테스트 캡처용: 실행 로그에서 전체 토큰을 집어내기 위한 마커.
        debugPrint("FCMTOKEN>>>$token<<<");
      }

      // 포그라운드 수신: 백엔드가 data 에도 복제한 표시 정보를 우선 사용하고,
      // 없으면 notification 블록으로 폴백한다. 받은 내용으로 기기 알림을 직접 띄운다.
      FirebaseMessaging.onMessage.listen((msg) {
        final title = msg.data['title'] ?? msg.notification?.title ?? "No Title";
        final body = msg.data['body'] ?? msg.notification?.body ?? "";
        _addLog("📥 포그라운드 수신: $title / $body (data=${msg.data})");
        setState(() => _n.insert(0, title));
        _showDeviceNotification(title, body);
      });

      // 백그라운드 알림을 탭해 앱이 열린 경우(참고용 로그).
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        final title = msg.data['title'] ?? msg.notification?.title ?? "No Title";
        _addLog("👆 알림 탭으로 앱 열림: $title");
      });
    } catch (e) {
      setState(() => _s = "토큰 오류: $e");
      _addLog("getToken 예외: $e");
    }
  }

  Future<void> _showLocal() async {
    LocalNotification n = LocalNotification(
      title: "Windows Test",
      body: "This is a local notification for Windows.",
    );
    n.show();
  }

  // 입력 폼에서 전송할 페이로드를 조립한다. 빈 값(선택 필드)은 제외.
  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{"token": _targetCtrl.text.trim()};
    void put(String key, String raw) {
      final v = raw.trim();
      if (v.isNotEmpty) payload[key] = v;
    }

    put("title", _titleCtrl.text);
    put("body", _bodyCtrl.text);
    put("image", _imageCtrl.text);
    put("sound", _soundCtrl.text);
    put("clickAction", _clickActionCtrl.text);

    final data = <String, String>{};
    for (final e in _data) {
      final k = e.key.text.trim();
      if (k.isNotEmpty) data[k] = e.value.text;
    }
    if (data.isNotEmpty) payload["data"] = data;
    return payload;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // 화면 로그 + 콘솔(stdout) 양쪽에 기록.
  void _addLog(String line) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    final entry = "[$ts] $line";
    debugPrint(entry);
    if (mounted) setState(() => _log.insert(0, entry));
  }

  Future<void> _send() async {
    if (_targetCtrl.text.trim().isEmpty) {
      setState(() => _s = "받는 기기 토큰 입력 필요");
      _snack("받는 기기 FCM 토큰을 입력하세요.");
      _addLog("SEND 중단: 받는 기기 토큰 비어있음");
      return;
    }
    var base = _urlCtrl.text.trim();
    if (base.isEmpty) {
      setState(() => _s = "URL 입력 필요");
      _snack("Backend URL 을 입력하세요.");
      _addLog("SEND 중단: Backend URL 비어있음");
      return;
    }
    while (base.endsWith("/")) {
      base = base.substring(0, base.length - 1);
    }
    final url = "$base/api/notifications";
    final body = jsonEncode(_buildPayload());
    setState(() => _s = "Sending... ($url)");
    _addLog("POST $url\n  body: $body");
    try {
      var r = await http
          .post(Uri.parse(url),
              headers: {"Content-Type": "application/json"}, body: body)
          .timeout(const Duration(seconds: 10));
      final ok = r.statusCode == 200;
      setState(() => _s = ok ? "Sent (200)" : "Fail (${r.statusCode})");
      _addLog("← HTTP ${r.statusCode}: ${r.body}");
      _snack(ok
          ? "전송 성공 (200)\n응답: ${r.body}"
          : "전송 실패 HTTP ${r.statusCode}\n$url\n${r.body}");
    } catch (e) {
      setState(() => _s = "NetErr");
      // 연결 실패 원인(잘못된 URL/방화벽/백엔드 미실행)을 그대로 노출.
      _addLog("✗ 연결 실패: $e");
      _snack("연결 실패: $url\n$e");
    }
  }

  void _addData() {
    setState(() => _data.add(_DataEntry()));
  }

  void _removeData(int i) {
    setState(() {
      _data.removeAt(i).dispose();
    });
  }

  Widget _field(TextEditingController c, String label,
      {String? hint, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: c,
        keyboardType: type,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FCM")),
      body: Column(children: [
        Text("Stat: $_s"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: SelectableText("내 토큰: ${_t ?? "(없음)"}",
                  maxLines: 2),
            ),
            IconButton(
              tooltip: "내 토큰 복사",
              onPressed: _t == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _t!));
                      setState(() => _s = "내 토큰 복사됨");
                    },
              icon: const Icon(Icons.copy),
            ),
          ]),
        ),
        Expanded(
          child: ListView(children: [
            _field(_urlCtrl, "Backend URL",
                hint: "http://192.168.0.10:8080", type: TextInputType.url),
            _field(_targetCtrl, "받는 기기 FCM 토큰",
                hint: "폰 앱이 표시한 토큰을 붙여넣기"),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("메시지 커스텀",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            _field(_titleCtrl, "Title"),
            _field(_bodyCtrl, "Body"),
            _field(_imageCtrl, "Image URL (선택)", type: TextInputType.url),
            _field(_soundCtrl, "Sound (선택)"),
            _field(_clickActionCtrl, "Click Action (선택)"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                const Text("Data 페이로드 (선택)"),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addData,
                  icon: const Icon(Icons.add),
                  label: const Text("추가"),
                ),
              ]),
            ),
            for (int i = 0; i < _data.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _data[i].key,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: "key",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _data[i].value,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: "value",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeData(i),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ]),
              ),
            const Divider(),
            if (!kIsWeb && Platform.isWindows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ElevatedButton(
                    onPressed: _showLocal,
                    child: const Text("Test Local Notifier")),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ElevatedButton(
                  onPressed: _send, child: const Text("Send")),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                const Text("프론트 로그",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_log.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _log.clear()),
                    icon: const Icon(Icons.clear_all),
                    label: const Text("지우기"),
                  ),
              ]),
            ),
            if (_log.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text("(아직 로그 없음 — Send 를 눌러보세요)",
                    style: TextStyle(color: Colors.grey)),
              ),
            ..._log.map((l) => Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: SelectableText(l,
                      style: const TextStyle(
                          fontFamily: "monospace", fontSize: 12)),
                )),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("수신 알림",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            ..._n.map((n) => ListTile(title: Text(n))),
          ]),
        ),
      ]),
    );
  }
}

/// data 페이로드의 key-value 한 쌍을 담는 컨트롤러 묶음.
class _DataEntry {
  final TextEditingController key = TextEditingController();
  final TextEditingController value = TextEditingController();

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

