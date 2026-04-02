import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // 사용자가 제공한 클라이언트 ID
  static const String _clientId = '781592166147-bc9ak0mks9ikgem01rgvi19mknh8nr1a.apps.googleusercontent.com';

  // 구글 캘린더 읽기 권한 Scope
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/calendar.readonly', // 일정 읽기 권한
    'https://www.googleapis.com/auth/calendar.events',    // 일정 쓰기 권한이 필요할 경우 추가
  ];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _clientId,
    scopes: _scopes,
  );

  /// 구글에 로그인하고, API 통신에 사용할 accessToken을 반환합니다.
  static Future<String?> signInAndGetToken() async {
    try {
      // 구글 로그인 진행 (웹/앱 공통)
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        // 사용자가 로그인을 취소한 경우
        return null;
      }

      // 인증 정보(토큰) 요청
      final GoogleSignInAuthentication auth = await account.authentication;
      
      return auth.accessToken; // API 요청에 사용할 Access Token 반환
    } catch (error) {
      print('Google sign in error: $error');
      return null;
    }
  }

  /// 로그아웃 처리
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
