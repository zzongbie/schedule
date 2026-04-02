import 'package:flutter/material.dart';
import '../service/api_service.dart';

enum ViewMode { monthly, weekly, daily }

class ScheduleProvider with ChangeNotifier {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  ViewMode currentViewMode = ViewMode.monthly;

  Map<String, Map<String, List<String>>> branchData = {};

  final Map<String, bool> employeeCheckboxState = {};
  final Map<String, Color> employeeColors = {};

  bool onlyPublicSchedules = false;

  int? _comId;
  int? _empId;
  Map<DateTime, List<Map<String, dynamic>>> _apiEvents = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  Map<DateTime, List<Map<String, dynamic>>> get events => _apiEvents.isEmpty ? _mockEvents : _apiEvents;

  final Map<DateTime, List<Map<String, dynamic>>> _mockEvents = {};
  
  ScheduleProvider() {
    // Initial checkboxes can be empty; populated dynamically.

    // Initialize mock events
    final today = DateTime.now();
    _mockEvents[DateTime.utc(today.year, today.month, today.day)] = [
      {'name': '정프로', 'title': '주간 회의', 'color': Colors.blue, 'startHour': 10.0, 'duration': 2.0},
      {'name': '이과장', 'title': '코드 리뷰', 'color': Colors.green, 'startHour': 10.5, 'duration': 1.5},
    ];
  }
  
  void setComId(int? id, {int? empId}) async {
    _comId = id;
    if (empId != null) _empId = empId;
    if (_comId != null) {
      await loadTreeData();
      await loadSchedules();
    }
  }

  Future<void> loadSchedules() async {
    if (_comId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final list = await ApiService.getSchedules(_comId!);
      final Map<DateTime, List<Map<String, dynamic>>> newEvents = {};
      
      for (var item in list) {
        // "start": "2026-03-17"
        final date = DateTime.parse(item['start']);
        final dayKey = DateTime.utc(date.year, date.month, date.day);
        
        // 시간 파싱 (HH:mm)
        double startHour = 9.0;
        if (item['start_time'] != null && item['start_time'].toString().contains(':')) {
          final parts = item['start_time'].toString().split(':');
          startHour = double.parse(parts[0]) + (double.parse(parts[1]) / 60.0);
        }

        newEvents.putIfAbsent(dayKey, () => []).add({
          'id': item['id'],
          'name': item['type_name'] ?? item['type'] ?? '미정', 
          'title': item['name'] ?? '제목 없음',
          'ins_name': item['ins_name'] ?? '작성자모름',
          'ins_id': item['ins_id'],
          'raw_type': item['type'],
          'start': item['start'],
          'end': item['end'],
          'start_time': item['start_time'],
          'end_time': item['end_time'],
          'detail': item['detail'],
          'highlight': item['highlight'],
          'view_type': item['view_type'],
          'executors': item['executors'] ?? [],
          'targets': item['targets'] ?? [],
          'color': employeeColors[item['ins_name'] ?? ''] ?? _getColorForType(item['type']),
          'startHour': startHour,
          'duration': 1.0, // 기본 1시간
          'is_api': true,
        });
      }
      _apiEvents = newEvents;
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTreeData() async {
    if (_comId == null) return;
    try {
      final subcoms = await ApiService.getGenericList('subcom', _comId!);
      final depts = await ApiService.getGenericList('dept', _comId!);
      final employees = await ApiService.getGenericList('employee', _comId!);

      final Map<String, Map<String, List<String>>> newTree = {};
      final scmNames = <int, String>{for (var s in subcoms) s['id'] as int: s['name']?.toString() ?? ''};
      final deptNames = <int, String>{for (var d in depts) d['id'] as int: d['name']?.toString() ?? ''};

      final List<Color> palette = [
        Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
        Colors.teal, Colors.indigo, Colors.amber, Colors.brown, Colors.cyan,
        Colors.pink, Colors.lime, Colors.deepOrange, Colors.lightBlue
      ];
      int colorIndex = 0;

      for (var emp in employees) {
        if (emp['name'] == 'admin' || emp['name'] == '관리자') continue;
        int scmId = emp['scm_id'] ?? 0;
        int deptId = emp['dept_id'] ?? 0;
        
        String scmName = scmId == 0 ? '미지정/본사' : scmNames[scmId] ?? '알 수 없는 지사';
        String deptName = deptId == 0 ? '직속' : deptNames[deptId] ?? '알 수 없는 부서';
        String empName = emp['name']?.toString() ?? '이름 없음';

        newTree.putIfAbsent(scmName, () => {});
        newTree[scmName]!.putIfAbsent(deptName, () => []);
        newTree[scmName]![deptName]!.add(empName);
        
        employeeCheckboxState.putIfAbsent(empName, () => false);
        if (!employeeColors.containsKey(empName)) {
           employeeColors[empName] = palette[colorIndex % palette.length];
           colorIndex++;
        }
      }
      
      branchData = newTree;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tree data: $e');
    }
  }

  Color _getColorForType(String? type) {
    if (type == null) return Colors.grey;
    if (type.startsWith('T001')) return Colors.blue;
    if (type.startsWith('T002')) return Colors.green;
    if (type.startsWith('T003')) return Colors.orange;
    return Colors.purple;
  }

  void toggleEmployee(String emp, bool? value) {
    employeeCheckboxState[emp] = value ?? false;
    notifyListeners();
  }

  void selectDay(DateTime selected, DateTime focused) {
    selectedDay = selected;
    focusedDay = focused;
    notifyListeners();
  }

  void setViewMode(ViewMode mode) {
    currentViewMode = mode;
    notifyListeners();
  }

  List<Map<String, dynamic>> getEventsForDay(DateTime day) {
    final dayEvents = events[DateTime.utc(day.year, day.month, day.day)] ?? [];
    
    // API 데이터인 경우 필터링 로직
    if (onlyPublicSchedules) {
      return dayEvents.where((event) => event['view_type'] == 1).toList();
    }

    bool hasSelection = employeeCheckboxState.values.any((isSelected) => isSelected);
    
    if (!hasSelection) return dayEvents;
    
    return dayEvents.where((event) {
      // 0. 작성자는 자기 글을 무조건 본다
      if (_empId != null && event['ins_id'] == _empId) {
        return true;
      }
      
      // 1. 작성자가 사이드바에서 선택되어 있거나
      if (employeeCheckboxState[event['ins_name']] == true) {
        return true;
      }
      // 2. 수행자 중 누군가가 사이드바에서 선택되어 있는 경우 표시
      if (event['executors'] != null && event['executors'] is List) {
        for (var exec in event['executors']) {
          if (employeeCheckboxState[exec['name']] == true) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }
}
