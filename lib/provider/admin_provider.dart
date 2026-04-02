import 'package:flutter/material.dart';
import '../service/api_service.dart';

/// 어드민 페이지 상태 관리를 위한 프로바이더
class AdminProvider with ChangeNotifier {
  List<dynamic> _companyData = [];
  List<dynamic> _metaData = [];
  List<dynamic> _userData = [];
  bool _isLoading = false;

  List<dynamic> get companyData => _companyData;
  List<dynamic> get metaData => _metaData;
  List<dynamic> get userData => _userData;
  bool get isLoading => _isLoading;

  /// 회사(Company) 데이터 패치
  Future<void> fetchCompanies() async {
    _isLoading = true;
    notifyListeners();
    try {
      _companyData = await ApiService.getCompanies();
    } catch (e) {
      // 에러 발생 시 처리 (UI에서 캐치할 수 있도록 rethrow)
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 메타(Meta) 데이터 패치
  Future<void> fetchMetas() async {
    _isLoading = true;
    notifyListeners();
    try {
      _metaData = await ApiService.getMetas();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 회사 추가
  Future<void> createCompany(Map<String, dynamic> data) async {
    await ApiService.createCompany(data);
    await fetchCompanies();
  }

  /// 회사 수정
  Future<void> updateCompany(int id, Map<String, dynamic> data) async {
    await ApiService.updateCompany(id, data);
    await fetchCompanies();
  }

  /// 회사 삭제
  Future<void> deleteCompany(int id) async {
    await ApiService.deleteCompany(id);
    await fetchCompanies();
  }

  /// 메타 추가
  Future<void> createMeta(Map<String, dynamic> data) async {
    await ApiService.createMeta(data);
    await fetchMetas();
  }

  /// 메타 수정
  Future<void> updateMeta(int comId, String code, Map<String, dynamic> data) async {
    await ApiService.updateMeta(comId, code, data);
    await fetchMetas();
  }

  /// 메타 삭제
  Future<void> deleteMeta(int comId, String code) async {
    await ApiService.deleteMeta(comId, code);
    await fetchMetas();
  }

  /// 유저(User) 데이터 패치
  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _userData = await ApiService.getUsers();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 유저 추가
  Future<void> createUser(Map<String, dynamic> data) async {
    await ApiService.createUser(data);
    await fetchUsers();
  }

  /// 유저 수정
  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    await ApiService.updateUser(id, data);
    await fetchUsers();
  }

  /// 유저 삭제
  Future<void> deleteUser(int id) async {
    await ApiService.deleteUser(id);
    await fetchUsers();
  }
}
