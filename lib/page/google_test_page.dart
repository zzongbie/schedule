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
  String? _fetchResult;
  String? _createResult;
  final TextEditingController _summaryController = TextEditingController();
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
      _fetchResult = null;
      _createResult = null;
    });
  }

  void _createEvent() async {
    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 로그인 후 토큰을 발급받아주세요.')),
      );
      return;
    }
    
    final summary = _summaryController.text.trim();
    if (summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 제목을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final service = GoogleCalendarService(accessToken: _accessToken!);
    
    final now = DateTime.now();
    final start = now.add(const Duration(hours: 1)); // 1시간 뒤
    final end = now.add(const Duration(hours: 2)); // 2시간 뒤
    
    final result = await service.createEvent(
      calendarId: 'primary',
      summary: summary,
      start: start,
      end: end,
      description: 'Flutter 앱에서 추가됨',
    );

    setState(() {
      _isLoading = false;
      if (result != null) {
        _createResult = '일정 추가 성공!\n'
            '제목: ${result.summary}\n'
            '시작: ${result.start}';
            
        // 입력 필드 초기화    
        _summaryController.clear();
      } else {
        _createResult = '오류: 일정을 추가하지 못했습니다.';
      }
    });
  }

  void _fetchEvent() async {
    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 로그인 후 토큰을 발급받아주세요.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final service = GoogleCalendarService(accessToken: _accessToken!);
    final result = await service.getEventsList(
      calendarId: 'primary',
    );

    setState(() {
      _isLoading = false;
      if (result != null) {
        if (result.isEmpty) {
          _fetchResult = '일정이 없습니다.';
        } else {
          final count = result.length;
          final preview = result.take(5).map((e) => '- ${e.summary} (${e.start})').join('\n');
          _fetchResult = '총 $count개의 일정\n\n$preview' + (count > 5 ? '\n... 외 ${count - 5}개' : '');
        }
      } else {
        _fetchResult = '오류: 일정을 가져오지 못했습니다.';
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
            
            const Text('2. 전체 일정 가져오기 테스트 (Fetch Events)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchEvent,
              child: const Text('전체 일정 가져오기 (Fetch Events)'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(_fetchResult ?? '아직 전체 일정을 가져오지 않았습니다.'),
            ),
            const Divider(height: 32),
            
            const Text('3. 일정 추가하기 테스트 (Create Event)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: '일정 제목 (Summary)',
                hintText: '추가할 일정의 제목 입력',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _createEvent,
              child: const Text('일정 추가하기 (Create Event)'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(_createResult ?? '아직 일정을 추가하지 않았습니다.'),
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
