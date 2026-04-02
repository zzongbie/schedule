import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // 사용자가 제공한 클라이언트 ID
  static const String _clientId = '781592166147-bc9ak0mks9ikgem01rgvi19mknh8nr1a.apps.googleusercontent.com';

  // 구글 캘린더 읽기 권한 Scope
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/calendar.readonly', // 일정 읽기 권한
    'https://www.googleapis.com/auth/calendar.events',    // 일정 쓰기 권한이 필요할 경우 추가
  ];

  static bool _initialized = false;

  /// 웹에서 renderButton을 화면에 그리기 전, 혹은 앱 구동 초기에 미리 API를 초기화하는 함수
  static Future<void> initOnly() async {
    if (!_initialized) {
      await GoogleSignIn.instance.initialize(
        clientId: _clientId,
      );
      _initialized = true;
    }
  }

  /// 구글에 로그인하고, API 통신에 사용할 accessToken을 반환합니다.
  static Future<String?> signInAndGetToken() async {
    try {
      await initOnly();

      // 인터랙티브 로그인 진행 (최신 7.x 버전에서는 authenticate() 사용)
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );

      // 캘린더 권한(Scope)에 대한 토큰 받아오기
      final authz = await GoogleSignIn.instance.authorizationClient.authorizeScopes(_scopes);

      return authz.accessToken; // API 요청에 넣을 Access Token 반환
    } catch (error) {
      print('Google sign in error: $error');
      return null;
    }
  }

  /// 로그아웃 처리
  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }
}
