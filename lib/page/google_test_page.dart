import 'package:flutter/material.dart';
import '../service/google_auth_service.dart';
import '../service/google_calendar_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in_web/web_only.dart' as web;


class GoogleTestPage extends StatefulWidget {
  const GoogleTestPage({Key? key}) : super(key: key);

  @override
  State<GoogleTestPage> createState() => _GoogleTestPageState();
}

class _GoogleTestPageState extends State<GoogleTestPage> {
  String? _accessToken;
  String? _eventResult;
  final TextEditingController _eventIdController = TextEditingController();
  bool _isLoading = false;
  bool _googleInitDone = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      GoogleAuthService.initOnly().then((_) {
        if (mounted) {
          setState(() {
            _googleInitDone = true;
          });
        }
      });
    }
  }

  void _login() async {
    setState(() => _isLoading = true);
    final token = await GoogleAuthService.signInAndGetToken();
    setState(() {
      _accessToken = token;
      _isLoading = false;
    });
  }

  void _logout() async {
    await GoogleAuthService.signOut();
    setState(() {
      _accessToken = null;
      _eventResult = null;
    });
  }

  void _fetchEvent() async {
    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 로그인 후 토큰을 발급받아주세요.')),
      );
      return;
    }
    
    final eventId = _eventIdController.text.trim();
    if (eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이벤트 ID를 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final service = GoogleCalendarService(accessToken: _accessToken!);
    final result = await service.getSingleEvent(
      calendarId: 'primary',
      eventId: eventId,
    );

    setState(() {
      _isLoading = false;
      if (result != null) {
        _eventResult = 'Summary: \${result.summary}\n'
            'Start: \${result.start}\n'
            'End: \${result.end}\n'
            'Status: \${result.status}';
      } else {
        _eventResult = '오류: 이벤트를 가져오지 못했거나 존재하지 않습니다.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('구글 서비스 테스트 (Google Service Test)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('1. 구글 인증 (Authentication)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (kIsWeb)
                  SizedBox(
                    width: 120, // 공식 웹 버튼 해상도
                    height: 48,
                    child: _googleInitDone
                        ? web.renderButton()
                        : const Center(child: CircularProgressIndicator()),
                  )
                else
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: const Text('앱 기기 로그인 (App Login)'),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: const Text('토큰 가져오기 (Get Token)'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _logout,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                  child: const Text('로그아웃'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Access Token:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(_accessToken ?? '로그인하지 않음 (Not logged in)'),
            
            const Divider(height: 32),
            
            const Text('2. 단일 일정 가져오기 테스트 (Fetch Event)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _eventIdController,
              decoration: const InputDecoration(
                labelText: 'Event ID',
                hintText: '구글 캘린더의 일정 ID 입력',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchEvent,
              child: const Text('일정 가져오기 (Fetch Event)'),
            ),
            const SizedBox(height: 16),
            const Text('결과 (Result):', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(_eventResult ?? '데이터 없음 (No data yet)'),
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
