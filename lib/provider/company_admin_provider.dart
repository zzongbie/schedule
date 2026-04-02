import 'package:flutter/material.dart';
import '../service/api_service.dart';

/// 회사별 관리자 페이지 상태 관리를 위한 프로바이더
class CompanyAdminProvider with ChangeNotifier {
  int? _selectedCompanyId;
  String _currentEntity = 'dept'; // 'dept', 'team', 'subcom', 'subcommap', 'employee', 'company_calendar'
  
  List<dynamic> _companyData = [];
  List<dynamic> _entityData = [];
  List<dynamic> _metaData = [];
  List<dynamic> _allDepts = [];
  List<dynamic> _allTeams = [];
  List<dynamic> _allEmployees = [];
  List<dynamic> _allSubcoms = [];
  bool _isLoading = false;

  int? get selectedCompanyId => _selectedCompanyId;
  String get currentEntity => _currentEntity;
  List<dynamic> get companyData => _companyData;
  List<dynamic> get entityData => _entityData;
  List<dynamic> get metaData => _metaData;
  List<dynamic> get allDepts => _allDepts;
  List<dynamic> get allTeams => _allTeams;
  List<dynamic> get allEmployees => _allEmployees;
  List<dynamic> get allSubcoms => _allSubcoms;
  bool get isLoading => _isLoading;
  
  /// 특정 엔티티의 데이터를 가져오는 헬퍼 (예: 부서 목록, 직원 목록 등)
  List<dynamic> getEntityDataList(String entity) {
    // 만약 현재 엔티티가 요청한 엔티티면 _entityData 반환
    if (_currentEntity == entity) return _entityData;
    // 그 외엔 아직 구현되지 않음 (필요 시 별도 캐싱 로직 추가 가능)
    return [];
  }

  String getDeptName(dynamic id) {
    if (id == null || id == 0 || id == '0') return '없음';
    try {
      final deptId = int.tryParse(id.toString()) ?? 0;
      final dept = _allDepts.firstWhere((d) => d['id'] == deptId);
      return dept['name'] ?? id.toString();
    } catch (_) {
      return id.toString();
    }
  }

  String getTeamName(dynamic id) {
    if (id == null || id == 0 || id == '0') return '없음';
    try {
      final teamId = int.tryParse(id.toString()) ?? 0;
      final team = _allTeams.firstWhere((t) => t['id'] == teamId);
      return team['name'] ?? id.toString();
    } catch (_) {
      return id.toString();
    }
  }

  String getEmployeeName(dynamic id) {
    if (id == null || id == 0 || id == '0') return '없음';
    try {
      final empId = int.tryParse(id.toString()) ?? 0;
      final emp = _allEmployees.firstWhere((e) => e['id'] == empId);
      return emp['name'] ?? id.toString();
    } catch (_) {
      return id.toString();
    }
  }

  String getSubcomName(dynamic id) {
    if (id == null || id == 0 || id == '0') return '없음';
    try {
      final subcomId = int.tryParse(id.toString()) ?? 0;
      final sc = _allSubcoms.firstWhere((s) => s['id'] == subcomId);
      return sc['name'] ?? id.toString();
    } catch (_) {
      return id.toString();
    }
  }

  /// 회사 목록 한 번 가져오기
  Future<void> fetchCompanies() async {
    _isLoading = true;
    notifyListeners();
    try {
      _companyData = await ApiService.getCompanies();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 특정 회사 선택
  void selectCompany(int? companyId) async {
    _selectedCompanyId = companyId;
    if (_selectedCompanyId != null) {
      await fetchEntityData();
    } else {
      _entityData = [];
      notifyListeners();
    }
  }

  /// 엔티티 탭 변경
  void setEntity(String entity) {
    _currentEntity = entity;
    if (_selectedCompanyId != null) {
      fetchEntityData();
    } else {
      notifyListeners();
    }
  }

  /// 현재 선택된 회사와 엔티티에 대한 데이터 가져오기
  Future<void> fetchEntityData() async {
    if (_selectedCompanyId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _entityData = await ApiService.getGenericList(_currentEntity, _selectedCompanyId!);
      
      // 메타 데이터 로드
      if (_currentEntity == 'employee') {
        _metaData = await ApiService.getGenericList('meta', _selectedCompanyId!);
      } else {
        _metaData = [];
      }

      // 의존성 데이터 로드
      if (_currentEntity == 'employee' || _currentEntity == 'dept' || _currentEntity == 'team' || _currentEntity == 'subcom' || _currentEntity == 'subcommap') {
        _allDepts = await ApiService.getGenericList('dept', _selectedCompanyId!);
        _allTeams = await ApiService.getGenericList('team', _selectedCompanyId!);
        _allEmployees = await ApiService.getGenericList('employee', _selectedCompanyId!);
        _allSubcoms = await ApiService.getGenericList('subcom', _selectedCompanyId!);
      } else {
        _allDepts = [];
        _allTeams = [];
        _allEmployees = [];
        _allSubcoms = [];
      }
      
    } catch (e) {
      _entityData = [];
      _metaData = [];
      _allDepts = [];
      _allTeams = [];
      _allEmployees = [];
      _allSubcoms = [];
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 특정 엔티티 데이터 직접 가져오기 (의존성용)
  Future<List<dynamic>> fetchOtherEntityData(String entity) async {
    if (_selectedCompanyId == null) return [];
    try {
      return await ApiService.getGenericList(entity, _selectedCompanyId!);
    } catch (_) {
      return [];
    }
  }

  /// 데이터 추가
  Future<void> createData(Map<String, dynamic> data) async {
    if (_selectedCompanyId == null) return;
    await ApiService.createGeneric(_currentEntity, _selectedCompanyId!, data);
    await fetchEntityData();
  }

  /// 데이터 수정
  Future<void> updateData(int id, Map<String, dynamic> data) async {
    if (_selectedCompanyId == null) return;
    await ApiService.updateGeneric(_currentEntity, _selectedCompanyId!, id, data);
    await fetchEntityData();
  }

  /// 데이터 삭제
  Future<void> deleteData(int id) async {
    if (_selectedCompanyId == null) return;
    await ApiService.deleteGeneric(_currentEntity, _selectedCompanyId!, id);
    await fetchEntityData();
  }
}
