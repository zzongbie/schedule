import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';
import '../service/api_service.dart';

class ScheduleAddDialog extends StatefulWidget {
  final DateTime initialDate;
  final Map<String, dynamic>? eventToEdit;

  const ScheduleAddDialog({super.key, required this.initialDate, this.eventToEdit});

  @override
  State<ScheduleAddDialog> createState() => _ScheduleAddDialogState();
}

class _ScheduleAddDialogState extends State<ScheduleAddDialog> {
  bool _isLoading = false;
  List<dynamic> _taskMetas = [];

  List<Map<String, dynamic>> _searchOptions = [];
  List<Map<String, dynamic>> _selectedIndividuals = [];

  List<Map<String, dynamic>> _executorOptions = [];
  List<Map<String, dynamic>> _selectedExecutors = [];
  int _executorType = 0; // 0: 직접, 1: 특정대상

  String? _selectedTaskType;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _detailCtrl = TextEditingController();
  TextEditingController? _executorTextCtrl;
  TextEditingController? _targetTextCtrl;

  late DateTime _startDate;
  late DateTime _endDate;
  
  String _startHour = '09';
  String _startMin = '00';
  String _endHour = '10';
  String _endMin = '00';

  bool _highlight = false;
  int _viewType = 1;

  @override
  void initState() {
    super.initState();
    if (widget.eventToEdit != null) {
      final e = widget.eventToEdit!;
      _startDate = DateTime.tryParse(e['start']?.toString() ?? '') ?? widget.initialDate;
      _endDate = DateTime.tryParse(e['end']?.toString() ?? '') ?? widget.initialDate;
      
      _nameCtrl.text = e['title']?.toString() ?? '';
      _detailCtrl.text = e['detail']?.toString() ?? '';
      _highlight = e['highlight'] == true || e['highlight'] == 1; // bool or tinyint
      _viewType = e['view_type'] ?? 1;
      if (_viewType == 0) _viewType = 1;
      
      if (e['start_time'] != null && e['start_time'].toString().contains(':')) {
        final parts = e['start_time'].toString().split(':');
        _startHour = parts[0].padLeft(2, '0');
        _startMin = parts[1].padLeft(2, '0');
      }
      if (e['end_time'] != null && e['end_time'].toString().contains(':')) {
        final parts = e['end_time'].toString().split(':');
        _endHour = parts[0].padLeft(2, '0');
        _endMin = parts[1].padLeft(2, '0');
      }

      if (e['executors'] != null && e['executors'] is List && (e['executors'] as List).isNotEmpty) {
        _executorType = 1;
        _selectedExecutors.clear();
        for (var exec in e['executors']) {
          _selectedExecutors.add({'name': exec['name'], 'id': exec['id'], 'type': '직원'});
        }
      } else {
        _executorType = 0;
      }
      
      if (e['targets'] != null && e['targets'] is List) {
        for (var t in e['targets']) {
          _selectedIndividuals.add({
            'id': t['target_id'],
            'scope_type': t['scope_type'],
            'type': t['type'] ?? '알수없음',
            'name': t['name'] ?? '이름없음',
          });
        }
      }
    } else {
      _startDate = widget.initialDate;
      _endDate = widget.initialDate;
      
      final now = DateTime.now();
      // MCalendar에서 클릭 시 보통 00:00, WCalendar에서 클릭 시 특정한 시간(0~23)
      if (widget.initialDate.year == now.year && 
          widget.initialDate.month == now.month && 
          widget.initialDate.day == now.day && 
          widget.initialDate.hour == 0) {
        // 오늘이면서 MCalendar에서 누른 경우 (시간이 0시)
        _startHour = now.hour.toString().padLeft(2, '0');
        _endHour = (now.hour + 1).clamp(0, 23).toString().padLeft(2, '0');
      } else if (widget.initialDate.hour == 0 && widget.initialDate.minute == 0) {
        // 오늘이 아니지만 MCalendar(0시 0분)에서 누른 경우 -> 기본 업무시간 09:00 ~ 10:00 등으로 하거나 현재시간
        _startHour = '09';
        _endHour = '10';
      } else {
        // WCalendar에서 특정 셀을 누른 경우 (시간 정보가 들어있음)
        _startHour = widget.initialDate.hour.toString().padLeft(2, '0');
        _endHour = (widget.initialDate.hour + 1).clamp(0, 23).toString().padLeft(2, '0');
      }
    }

    _loadMetas();
    _loadSearchData();
  }

  Future<void> _loadSearchData() async {
    final auth = context.read<AuthProvider>();
    if (auth.comId == null) return;
    
    try {
      final employees = await ApiService.getGenericList('employee', auth.comId!);
      final depts = await ApiService.getGenericList('dept', auth.comId!);
      final teams = await ApiService.getGenericList('team', auth.comId!);
      final subcoms = await ApiService.getGenericList('subcom', auth.comId!);
      
      final options = <Map<String, dynamic>>[];
      for (var e in employees) { options.add({'type': '직원', 'scope_type': 1, 'name': e['name'], 'id': e['id']}); }
      for (var d in depts) { options.add({'type': '부서', 'scope_type': 2, 'name': d['name'], 'id': d['id']}); }
      for (var t in teams) { options.add({'type': '팀', 'scope_type': 3, 'name': t['name'], 'id': t['id']}); }
      for (var s in subcoms) { options.add({'type': '협력사', 'scope_type': 4, 'name': s['name'], 'id': s['id']}); }
      
      if (mounted) {
        setState(() {
          _searchOptions = options;
          _executorOptions = options.where((o) => o['type'] == '직원').toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load search data: $e');
    }
  }

  Future<void> _loadMetas() async {
    final auth = context.read<AuthProvider>();
    if (auth.comId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final allMeta = await ApiService.getGenericList('meta', auth.comId!);
      // T로 시작하는 직무 코드 필터링
      final tasks = allMeta.where((m) => m['code']?.toString().startsWith('T') == true).toList();
      setState(() {
        _taskMetas = tasks;
        if (widget.eventToEdit != null) {
          _selectedTaskType = widget.eventToEdit!['raw_type']?.toString();
        } else if (_taskMetas.isNotEmpty) {
          _selectedTaskType = _taskMetas.first['code'].toString();
        }
      });
    } catch (e) {
      debugPrint('Failed to load metas: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('일정명을 입력해주세요.')));
      return;
    }
    if (_selectedTaskType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('직무를 선택해주세요.')));
      return;
    }

    final auth = context.read<AuthProvider>();
    
    final payload = <String, dynamic>{
      'com_id': auth.comId ?? 0,
      'ins_id': auth.empId ?? 0, // 로그인한 직원의 고유 번호
      'type': _selectedTaskType,
      'name': _nameCtrl.text.trim(),
      'start': DateFormat('yyyy-MM-dd').format(_startDate),
      'start_time': '$_startHour:$_startMin',
      'end': DateFormat('yyyy-MM-dd').format(_endDate),
      'end_time': '$_endHour:$_endMin',
      'detail': _detailCtrl.text.trim(),
      'highlight': _highlight,
      'view_type': _viewType,
      'targets': _viewType == 2 
          ? _selectedIndividuals.map((e) => {
              'target_id': e['id'],
              'scope_type': e['scope_type'],
              'type': e['type'],
              'name': e['name']
            }).toList() 
          : [],
      'executors': _executorType == 0 
          ? [] 
          : _selectedExecutors.map((e) => e['id']).toList(),
    };

    setState(() => _isLoading = true);
    try {
      if (widget.eventToEdit != null) {
        await ApiService.updateSchedule(widget.eventToEdit!['id'].toString(), payload);
      } else {
        await ApiService.createSchedule(payload);
      }
      if (mounted) {
        Navigator.pop(context, true); // true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('일정 저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTimeDropdowns(String hour, String min, Function(String, String) onChanged) {
    return Row(
      children: [
        DropdownButton<String>(
          value: hour,
          items: List.generate(24, (index) => index.toString().padLeft(2, '0')).map((h) {
            return DropdownMenuItem(value: h, child: Text(h));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val, min);
          },
        ),
        const Text(' : '),
        DropdownButton<String>(
          value: min,
          items: ['00', '10', '20', '30', '40', '50'].map((m) {
            return DropdownMenuItem(value: m, child: Text(m));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(hour, val);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.eventToEdit != null;
    return AlertDialog(
      title: Text(isEdit ? '일정 수정' : '일정 추가'),
      content: SizedBox(
        width: 500,
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 직무 (meta T)
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('직무', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedTaskType,
                        hint: const Text('직무 선택'),
                        items: _taskMetas.map((m) {
                          return DropdownMenuItem<String>(
                            value: m['code'].toString(),
                            child: Text(m['name'].toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedTaskType = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 2. 일정명
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('일정명', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. 시작일시
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('시작일시', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTimeDropdowns(_startHour, _startMin, (h, m) => setState(() { _startHour = h; _startMin = m; })),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. 종료일시
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('종료일시', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        child: InputDecorator(
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTimeDropdowns(_endHour, _endMin, (h, m) => setState(() { _endHour = h; _endMin = m; })),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. 일정내용
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 80, child: Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('일정내용', style: TextStyle(fontWeight: FontWeight.bold)),
                    )),
                    Expanded(
                      child: TextField(
                        controller: _detailCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. 중요도 표시
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('중요도', style: TextStyle(fontWeight: FontWeight.bold))),
                    Checkbox(
                      value: _highlight,
                      onChanged: (val) => setState(() => _highlight = val ?? false),
                    ),
                    const Text('중요 일정 표시'),
                  ],
                ),
                const SizedBox(height: 12),

                // 6-2. 일정 수행자
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 80, child: Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('일정 수행자', style: TextStyle(fontWeight: FontWeight.bold)),
                    )),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Radio<int>(
                                value: 0,
                                groupValue: _executorType,
                                onChanged: (val) => setState(() => _executorType = val!),
                              ),
                              const Text('직접'),
                              const SizedBox(width: 16),
                              Radio<int>(
                                value: 1,
                                groupValue: _executorType,
                                onChanged: (val) => setState(() => _executorType = val!),
                              ),
                              const Text('특정대상'),
                            ],
                          ),
                          if (_executorType == 1) ...[
                            if (_selectedExecutors.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: _selectedExecutors.map((item) {
                                    return Chip(
                                      label: Text('${item['name']}', style: const TextStyle(fontSize: 12)),
                                      onDeleted: () {
                                        setState(() {
                                          _selectedExecutors.remove(item);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Autocomplete<Map<String, dynamic>>(
                              displayStringForOption: (option) => '${option['name']} (${option['type']})',
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Map<String, dynamic>>.empty();
                                }
                                return _executorOptions.where((option) {
                                  return option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (Map<String, dynamic> selection) {
                                if (!_selectedExecutors.any((element) => element['id'] == selection['id'])) {
                                  setState(() {
                                    _selectedExecutors.add(selection);
                                  });
                                }
                                Future.delayed(Duration.zero, () => _executorTextCtrl?.clear());
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                _executorTextCtrl = textEditingController;
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    hintText: '수행 직원 검색',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: Icon(Icons.search),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 7. 공개범위
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('공개범위', style: TextStyle(fontWeight: FontWeight.bold))),
                    Radio<int>(
                      value: 1,
                      groupValue: _viewType,
                      onChanged: (val) => setState(() => _viewType = val!),
                    ),
                    const Text('전체공개'),
                    Radio<int>(
                      value: 2,
                      groupValue: _viewType,
                      onChanged: (val) => setState(() => _viewType = val!),
                    ),
                    const Text('특정대상'),
                  ],
                ),
                
                if (_viewType == 2) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 80, child: Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('공개대상 추가', style: TextStyle(fontWeight: FontWeight.bold)),
                      )),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 대상자 칩 영역
                            if (_selectedIndividuals.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: _selectedIndividuals.map((item) {
                                    return Chip(
                                      label: Text('${item['name']} (${item['type']})', style: const TextStyle(fontSize: 12)),
                                      onDeleted: () {
                                        setState(() {
                                          _selectedIndividuals.remove(item);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // 검색 자동완성 입력창
                            Autocomplete<Map<String, dynamic>>(
                              displayStringForOption: (option) => '${option['name']} (${option['type']})',
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Map<String, dynamic>>.empty();
                                }
                                return _searchOptions.where((option) {
                                  return option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (Map<String, dynamic> selection) {
                                if (!_selectedIndividuals.any((element) => element['type'] == selection['type'] && element['id'] == selection['id'])) {
                                  setState(() {
                                    _selectedIndividuals.add(selection);
                                  });
                                }
                                Future.delayed(Duration.zero, () => _targetTextCtrl?.clear());
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                _targetTextCtrl = textEditingController;
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    hintText: '이름, 부서 등 검색',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: Icon(Icons.search),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: Text(isEdit ? '수정' : '등록'),
        ),
      ],
    );
  }
}
