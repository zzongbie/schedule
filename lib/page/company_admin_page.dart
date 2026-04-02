import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widget/common_dialog.dart';
import '../provider/company_admin_provider.dart';
import '../provider/auth_provider.dart';
import '../service/api_service.dart';
import 'login_page.dart';

class CompanyAdminPage extends StatefulWidget {
  const CompanyAdminPage({super.key});

  @override
  State<CompanyAdminPage> createState() => _CompanyAdminPageState();
}

class _CompanyAdminPageState extends State<CompanyAdminPage> {
  final List<String> _entities = [
    'dept',
    'team',
    'subcom',
    'subcommap',
    'employee',
    'company_calendar'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.comId != null) {
        context.read<CompanyAdminProvider>().selectCompany(auth.comId);
      }
    });
  }

  // 엔티티별 필드 정의
  List<String> _getFieldsForEntity(String entity) {
    switch (entity) {
      case 'dept':
        return ['name', 'pid', 'emp_id'];
      case 'team':
        return ['name', 'dept_id', 'emp_id'];
      case 'subcom':
        return ['name', 'phone', 'email', 'gubun'];
      case 'subcommap':
        return ['subcom_id', 'addr', 'sido', 'sigungu', 'dong', 'mail'];
      case 'employee':
        return ['name', 'position', 'dept_id', 'team_id', 'scm_id', 'gubun', 'phone', 'email', 'status', 'auth', 'join_dt', 'quit_dt', 'status_s_dt'];
      case 'company_calendar':
        return ['title', 'start_date', 'end_date', 'memo'];
      default:
        return ['name'];
    }
  }

  String _getEntityNameKorean(String entity) {
    switch (entity) {
      case 'dept': return '부서 (Dept)';
      case 'team': return '팀 (Team)';
      case 'subcom': return '협력사 (SubCom)';
      case 'subcommap': return '협력사 구역 (SubComMap)';
      case 'employee': return '직원 (Employee)';
      case 'company_calendar': return '회사 일정 (Calendar)';
      default: return entity;
    }
  }

  String _getFieldNameKorean(String field) {
    switch (field) {
      case 'name': return '명칭';
      case 'memo': return '메모';
      case 'orderno': return '순서';
      case 'dept_id': return '소속 부서';
      case 'team_id': return '소속 팀';
      case 'gubun': return '구분';
      case 'pid': return '상위 조직';
      case 'emp_id': return '담당자/관리자';
      case 'ceo_name': return '대표자명';
      case 'phone': return '연락처';
      case 'address': return '주소';
      case 'addr': return '상세 주소';
      case 'sido': return '시/도';
      case 'sigungu': return '시/군/구';
      case 'dong': return '읍/면/동';
      case 'mail': return '우편번호';
      case 'subcom_id': return '협력사 ID';
      case 'target_type': return '대상 타입';
      case 'target_id': return '대상 ID';
      case 'position': return '직급';
      case 'email': return '이메일';
      case 'status': return '상태';
      case 'auth': return '권한';
      case 'scm_id': return '협력사';
      case 'join_dt': return '입사일';
      case 'quit_dt': return '퇴사일';
      case 'status_s_dt': return '상태시작일';
      case 'title': return '제목';
      case 'start_date': return '시작일';
      case 'end_date': return '종료일';
      default: return field;
    }
  }

  String _getMetaName(List<dynamic> metaData, String code) {
    if (code.isEmpty) return code;
    try {
      final mapping = metaData.firstWhere((m) => m['code'] == code);
      return mapping['name']?.toString() ?? code;
    } catch (_) {
      return code;
    }
  }

  void _showEntityDialog({Map<String, dynamic>? entityData}) async {
    final provider = context.read<CompanyAdminProvider>();
    final isEdit = entityData != null;
    final currentEntity = provider.currentEntity;
    final fields = _getFieldsForEntity(currentEntity);
    
    // employee 추가/수정인 경우 meta 로드
    List<dynamic> positionMeta = [];
    List<dynamic> statusMeta = [];
    List<dynamic> authMeta = [];
    List<dynamic> gubunMeta = [];
    List<dynamic> departmentList = [];
    List<dynamic> teamList = [];
    List<dynamic> employeeList = [];

    // 필요한 의존 데이터 로드
    try {
      if (currentEntity == 'employee') {
        final allMeta = provider.metaData;
        positionMeta = allMeta.where((m) => m['code']?.toString().startsWith('R') == true).toList();
        statusMeta = allMeta.where((m) => m['code']?.toString().startsWith('S') == true).toList();
        authMeta = allMeta.where((m) => m['code']?.toString().startsWith('A') == true).toList();
        gubunMeta = allMeta.where((m) => m['code']?.toString().startsWith('G') == true).toList();
      }
      
      if (currentEntity == 'dept' || currentEntity == 'team' || currentEntity == 'employee') {
        departmentList = await provider.fetchOtherEntityData('dept');
      }
      
      if (currentEntity == 'employee') {
        teamList = await provider.fetchOtherEntityData('team');
      }
      
      if (currentEntity == 'dept' || currentEntity == 'team' || currentEntity == 'subcom') {
        employeeList = await provider.fetchOtherEntityData('employee');
      }
    } catch (e) {
      // ignore
    }
    
    // Map of text controllers
    final controllers = <String, TextEditingController>{};
    for (var f in fields) {
      controllers[f] = TextEditingController(text: entityData?[f]?.toString() ?? '');
    }

    if (!context.mounted) return;

    CommonDialog.showFormDialog(
      context: context,
      title: isEdit ? '${_getEntityNameKorean(currentEntity)} 수정' : '${_getEntityNameKorean(currentEntity)} 추가',
      fields: fields.map((f) {
        if (f == 'position' && positionMeta.isNotEmpty) {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: positionMeta.map((m) => m['name']?.toString() ?? '').toList(),
            dropdownValues: positionMeta.map((m) => m['code']?.toString() ?? '').toList(),
          );
        }
        if (f == 'status' && statusMeta.isNotEmpty) {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: statusMeta.map((m) => m['name']?.toString() ?? '').toList(),
            dropdownValues: statusMeta.map((m) => m['code']?.toString() ?? '').toList(),
          );
        }
        if (f == 'auth' && authMeta.isNotEmpty) {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: authMeta.map((m) => m['name']?.toString() ?? '').toList(),
            dropdownValues: authMeta.map((m) => m['code']?.toString() ?? '').toList(),
          );
        }
        if (f == 'gubun' && gubunMeta.isNotEmpty) {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: gubunMeta.map((m) => m['name']?.toString() ?? '').toList(),
            dropdownValues: gubunMeta.map((m) => m['code']?.toString() ?? '').toList(),
          );
        }
        if (f == 'gubun' && currentEntity == 'subcom') {
          // 기본값 처리
          if (controllers[f]!.text.isEmpty) {
            controllers[f]!.text = 'false';
          }
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isRadio: true,
            dropdownItems: const ['본사', '지사'],
            dropdownValues: const ['true', 'false'],
          );
        }
        if (f == 'pid') {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: ['없음(최상위)', ...departmentList.map((d) => d['name']?.toString() ?? '')],
            dropdownValues: ['0', ...departmentList.map((d) => d['id']?.toString() ?? '0')],
          );
        }
        if (f == 'dept_id') {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: ['미지정', ...departmentList.map((d) => d['name']?.toString() ?? '')],
            dropdownValues: ['0', ...departmentList.map((d) => d['id']?.toString() ?? '0')],
          );
        }
        if (f == 'team_id') {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: ['미지정', ...teamList.map((t) => t['name']?.toString() ?? '')],
            dropdownValues: ['0', ...teamList.map((t) => t['id']?.toString() ?? '0')],
          );
        }
        if (f == 'emp_id') {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: ['미지정', ...employeeList.map((e) => '${e['name']} (${e['position'] ?? ''})')],
            dropdownValues: ['0', ...employeeList.map((e) => e['id']?.toString() ?? '0')],
          );
        }
        if (f == 'scm_id' || f == 'subcom_id') {
          return DialogField(
            controller: controllers[f]!,
            labelText: '${_getFieldNameKorean(f)} ($f)',
            isDropdown: true,
            dropdownItems: ['미지정', ...provider.allSubcoms.map((s) => s['name']?.toString() ?? '')],
            dropdownValues: ['0', ...provider.allSubcoms.map((s) => s['id']?.toString() ?? '0')],
          );
        }

        return DialogField(
          controller: controllers[f]!, 
          labelText: '${_getFieldNameKorean(f)} ($f)',
        );
      }).toList(),
      onSave: () async {
        final data = <String, dynamic>{};
        for (var f in fields) {
          // 간이 형변환 (id, orderno, _id, pid, emp_id 등을 int로 처리)
          if (f.endsWith('_id') || f == 'orderno' || f == 'id' || f == 'pid' || f == 'emp_id') {
            final val = int.tryParse(controllers[f]!.text) ?? 0;
            // 0인 경우 외래키 제약조건 등을 고려해 null로 처리 (선택 사항인 경우)
            if ((f.endsWith('_id') || f == 'pid' || f == 'emp_id') && val == 0) {
              data[f] = null;
            } else {
              data[f] = val;
            }
          } else {
            data[f] = controllers[f]!.text.isEmpty ? null : controllers[f]!.text;
          }
        }
        
        try {
          if (isEdit) {
            await provider.updateData(entityData['id'], data);
          } else {
            await provider.createData(data);
          }
        } catch(e) {
          final err = e.toString().replaceFirst('Exception: ', '');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $err')));
        }
      },
    );
  }

  void _deleteData(int id) async {
    try {
      await context.read<CompanyAdminProvider>().deleteData(id);
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 실패')));
    }
  }

  Widget _buildContent() {
    final provider = context.watch<CompanyAdminProvider>();
    
    if (provider.selectedCompanyId == null) {
      return const Center(child: Text('소속 회사를 찾을 수 없습니다.', style: TextStyle(fontSize: 18)));
    }

    final fields = _getFieldsForEntity(provider.currentEntity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_getEntityNameKorean(provider.currentEntity)} 관리', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showEntityDialog(),
                icon: const Icon(Icons.add),
                label: const Text('추가'),
              )
            ],
          ),
        ),
        if (provider.isLoading) const Center(child: CircularProgressIndicator()),
        if (!provider.isLoading) Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: [
                  ...fields.map((f) => DataColumn(label: Text(_getFieldNameKorean(f)))).toList(),
                  const DataColumn(label: Text('수정/삭제')),
                ],
                rows: provider.entityData.map((item) => DataRow(
                  cells: [
                    ...fields.map((f) {
                      String valueText = item[f]?.toString() ?? '';
                      // 메타 데이터 변환 (공통)
                      if (provider.currentEntity == 'employee' && (f == 'position' || f == 'status' || f == 'auth' || f == 'gubun')) {
                        valueText = _getMetaName(provider.metaData, valueText);
                      }
                      if (provider.currentEntity == 'subcom' && f == 'gubun') {
                        valueText = (valueText == 'true' || valueText == '1') ? '본사' : '지사';
                      }
                      // 하위 회사 이름 조인 후 보여주기 (subcommap)
                      if (provider.currentEntity == 'subcommap' && f == 'subcom_id') {
                        valueText = item['subcom_name']?.toString() ?? provider.getSubcomName(item[f]);
                      } else if (f == 'dept_id' || f == 'pid') {
                        valueText = provider.getDeptName(item[f]);
                      } else if (f == 'team_id') {
                        valueText = provider.getTeamName(item[f]);
                      } else if (f == 'scm_id') {
                        valueText = provider.getSubcomName(item[f]);
                      } else if (f == 'emp_id') {
                        valueText = provider.getEmployeeName(item[f]);
                      }
                      
                      return DataCell(Text(valueText));
                    }).toList(),
                    DataCell(SizedBox(
                      width: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEntityDialog(entityData: item)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteData(item['id'])),
                        ],
                      ),
                    )),
                  ]
                )).toList(),
              ),
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyAdminProvider>();
    final selectedIndex = _entities.indexOf(provider.currentEntity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('백맨 - 회사별 관리자 페이지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
          )
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex == -1 ? 0 : selectedIndex,
            onDestinationSelected: (int index) {
              provider.setEntity(_entities[index]);
            },
            labelType: MediaQuery.of(context).size.width > 800 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            extended: MediaQuery.of(context).size.width > 800,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: Text('부서')),
              NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: Text('팀')),
              NavigationRailDestination(icon: Icon(Icons.business_center_outlined), selectedIcon: Icon(Icons.business_center), label: Text('협력사')),
              NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: Text('협력사 구역')),
              NavigationRailDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: Text('직원')),
              NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('회사 일정')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
}
