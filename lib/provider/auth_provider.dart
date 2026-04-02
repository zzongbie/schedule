import 'package:flutter/material.dart';
import '../service/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _loggedInUserId;
  int? _id;
  int? _empId;
  String? _gubun;
  int? _comId;

  bool get isLoading => _isLoading;
  String? get loggedInUserId => _loggedInUserId;
  int? get id => _id;
  int? get empId => _empId;
  String? get gubun => _gubun;
  int? get comId => _comId;

  /// 사용자 로그인 수행
  /// 성공 시 반환값(Map)을 통해 관리자여부 등을 체크할 수 있도록 리턴합니다.
  Future<Map<String, dynamic>> login(String userId, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.login(userId, password);
      _loggedInUserId = result['user_id'];
      _id = result['id'];
      _empId = result['emp_id'];
      _gubun = result['gubun'];
      _comId = result['com_id'];
      return result;
    } catch (e) {
      // 에러는 UI에서 스낵바로 보여줄 수 있도록 던집니다.
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 로그아웃 수행
  void logout() {
    _loggedInUserId = null;
    _id = null;
    _empId = null;
    _gubun = null;
    _comId = null;
    notifyListeners();
  }
}
