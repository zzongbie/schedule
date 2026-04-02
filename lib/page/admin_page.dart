import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widget/common_dialog.dart';
import '../provider/admin_provider.dart';
import 'login_page.dart';
import 'company_admin_page.dart';
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0; // 0: Company, 1: Meta, 2: User
  int? _selectedCompanyIdForMeta;
  int? _selectedCompanyIdForUser;

  @override
  void initState() {
    super.initState();
    // 초기 로딩 시 데이터 패치
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDataForIndex(_selectedIndex);
    });
  }

  void _fetchDataForIndex(int index) async {
    final provider = context.read<AdminProvider>();
    try {
      if (index == 0) {
        await provider.fetchCompanies();
      } else if (index == 1) {
        await provider.fetchCompanies();
        await provider.fetchMetas();
      } else if (index == 2) {
        await provider.fetchCompanies();
        await provider.fetchUsers();
      }
    } catch (e) {
      final err = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('데이터 패치 에러: $err')));
      }
    }
  }

  void _showCompanyDialog({Map<String, dynamic>? company}) {
    final isEdit = company != null;
    final nameCtrl = TextEditingController(text: company?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: company?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: company?['email'] ?? '');

    CommonDialog.showFormDialog(
      context: context,
      title: isEdit ? '회사 수정' : '회사 추가',
      fields: [
        DialogField(controller: nameCtrl, labelText: '이름(name)'),
        DialogField(controller: phoneCtrl, labelText: '연락처(phone)'),
        DialogField(controller: emailCtrl, labelText: '이메일(email)'),
      ],
      onSave: () async {
        final data = {
          'name': nameCtrl.text,
          'phone': phoneCtrl.text,
          'email': emailCtrl.text,
        };
        
        try {
          final provider = context.read<AdminProvider>();
          if (isEdit) {
            await provider.updateCompany(company['id'], data);
          } else {
            await provider.createCompany(data);
          }
        } catch(e) {
          final err = e.toString().replaceFirst('Exception: ', '');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $err')));
        }
      },
    );
  }

  void _deleteCompany(int id) async {
    try {
      await context.read<AdminProvider>().deleteCompany(id);
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 실패')));
    }
  }

  void _showMetaDialog({Map<String, dynamic>? metaData}) {
    final isEdit = metaData != null;
    final defaultComId = isEdit ? metaData['com_id']?.toString() : (_selectedCompanyIdForMeta?.toString() ?? '');
    final comIdCtrl = TextEditingController(text: defaultComId);
    final codeCtrl = TextEditingController(text: metaData?['code'] ?? '');
    final nameCtrl = TextEditingController(text: metaData?['name'] ?? '');
    final orderCtrl = TextEditingController(text: metaData?['orderno']?.toString() ?? '');
    final memoCtrl = TextEditingController(text: metaData?['memo'] ?? '');
    final gcodeCtrl = TextEditingController(text: metaData?['gcode'] ?? '');

    CommonDialog.showFormDialog(
      context: context,
      title: isEdit ? '메타 수정' : '메타 추가',
      fields: [
        DialogField(controller: comIdCtrl, labelText: '회사 ID (com_id)', readOnly: isEdit),
        DialogField(controller: codeCtrl, labelText: '코드 (code)', readOnly: isEdit),
        DialogField(controller: nameCtrl, labelText: '코드명 (name)'),
        DialogField(controller: orderCtrl, labelText: '순서 (orderno)', keyboardType: TextInputType.number),
        DialogField(controller: gcodeCtrl, labelText: '상위코드 (gcode)'),
        DialogField(controller: memoCtrl, labelText: '메모 (memo)'),
      ],
      onSave: () async {
        final data = {
          'com_id': int.tryParse(comIdCtrl.text) ?? 0,
          'code': codeCtrl.text,
          'name': nameCtrl.text,
          'orderno': int.tryParse(orderCtrl.text) ?? 0,
          'gcode': gcodeCtrl.text,
          'memo': memoCtrl.text,
        };
        
        try {
          final provider = context.read<AdminProvider>();
          if (isEdit) {
            await provider.updateMeta(metaData['com_id'], metaData['code'], data);
          } else {
            await provider.createMeta(data);
          }
        } catch(e) {
          final err = e.toString().replaceFirst('Exception: ', '');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $err')));
        }
      },
    );
  }

  String _getCompanyName(List<dynamic> companies, int comId) {
    try {
      final co = companies.firstWhere((c) => c['id'] == comId);
      return co['name']?.toString() ?? comId.toString();
    } catch (_) {
      return comId.toString();
    }
  }

  void _deleteMeta(int comId, String code) async {
    try {
      await context.read<AdminProvider>().deleteMeta(comId, code);
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 실패')));
    }
  }

  Widget _buildCompanyContent() {
    final provider = context.watch<AdminProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Company (회사) 테이블 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showCompanyDialog(),
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
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('회사명')),
                  DataColumn(label: Text('연락처')),
                  DataColumn(label: Text('이메일')),
                  DataColumn(label: Text('수정/삭제')),
                ],
                rows: provider.companyData.map((co) => DataRow(
                  cells: [
                    DataCell(Text(co['id'].toString())),
                    DataCell(Text(co['name'] ?? '')),
                    DataCell(Text(co['phone'] ?? '')),
                    DataCell(Text(co['email'] ?? '')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showCompanyDialog(company: co)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCompany(co['id'])),
                      ],
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

  Widget _buildMetaContent() {
    final provider = context.watch<AdminProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Meta (메타) 테이블 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  DropdownButton<int>(
                    hint: const Text('회사 선택'),
                    value: _selectedCompanyIdForMeta,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('전체 회사 보기'),
                      ),
                      ...provider.companyData.map((co) {
                        return DropdownMenuItem<int>(
                          value: co['id'] as int,
                          child: Text(co['name']?.toString() ?? 'Select Company'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCompanyIdForMeta = val;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showMetaDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('추가'),
                  ),
                ],
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
                columns: const [
                  DataColumn(label: Text('회사명')),
                  DataColumn(label: Text('코드')),
                  DataColumn(label: Text('코드명')),
                  DataColumn(label: Text('상위코드')),
                  DataColumn(label: Text('메모')),
                  DataColumn(label: Text('수정/삭제')),
                ],
                rows: provider.metaData
                  .where((meta) => _selectedCompanyIdForMeta == null || meta['com_id'] == _selectedCompanyIdForMeta)
                  .map((meta) => DataRow(
                  cells: [
                    DataCell(Text(_getCompanyName(provider.companyData, meta['com_id'] as int))),
                    DataCell(Text(meta['code'] ?? '')),
                    DataCell(Text(meta['name'] ?? '')),
                    DataCell(Text(meta['gcode'] ?? '')),
                    DataCell(Text(meta['memo'] ?? '')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showMetaDialog(metaData: meta)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteMeta(meta['com_id'], meta['code'])),
                      ],
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

  // ============== User Management ==============
  void _showUserDialog({Map<String, dynamic>? userData}) {
    final isEdit = userData != null;
    final defaultComId = isEdit ? userData['com_id']?.toString() : (_selectedCompanyIdForUser?.toString() ?? '');
    final comIdCtrl = TextEditingController(text: defaultComId);
    final nameCtrl = TextEditingController(text: userData?['name'] ?? '');
    final pwCtrl = TextEditingController(text: userData?['pw'] ?? '');
    final lockCntCtrl = TextEditingController(text: userData?['lock_cnt']?.toString() ?? '0');

    CommonDialog.showFormDialog(
      context: context,
      title: isEdit ? '관리자(User) 계정 수정' : '관리자(User) 계정 추가',
      fields: [
        DialogField(controller: comIdCtrl, labelText: '회사 ID (com_id)'),
        DialogField(controller: nameCtrl, labelText: '아이디 (name)', readOnly: isEdit),
        DialogField(controller: pwCtrl, labelText: '비밀번호 (pw)'),
        DialogField(controller: lockCntCtrl, labelText: '잠금 횟수 (Lock Cnt)', keyboardType: TextInputType.number),
      ],
      onSave: () async {
        final comId = int.tryParse(comIdCtrl.text) ?? 0;
        if (comId <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('유효한 회사 ID (com_id)를 입력해주세요.')));
          return; // Prevents saving
        }
        if (nameCtrl.text.isEmpty || pwCtrl.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID와 비밀번호를 모두 입력해주세요.')));
          return; // Prevents saving
        }

        final data = {
          'com_id': comId,
          'name': nameCtrl.text,
          'pw': pwCtrl.text,
          'lock_cnt': int.tryParse(lockCntCtrl.text) ?? 0,
          'rest_chk': userData?['rest_chk'] ?? false,
        };

        
        try {
          final provider = context.read<AdminProvider>();
          if (isEdit) {
            await provider.updateUser(userData['id'], data);
          } else {
            await provider.createUser(data);
          }
        } catch(e) {
          final err = e.toString().replaceFirst('Exception: ', '');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $err')));
        }
      },
    );
  }

  void _deleteUser(int id) async {
    try {
      await context.read<AdminProvider>().deleteUser(id);
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 실패')));
    }
  }

  Widget _buildUserContent() {
    final provider = context.watch<AdminProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('관리자 (User) 계정 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  DropdownButton<int>(
                    hint: const Text('회사 선택'),
                    value: _selectedCompanyIdForUser,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('전체 보기'),
                      ),
                      ...provider.companyData.map((co) {
                        return DropdownMenuItem<int>(
                          value: co['id'] as int,
                          child: Text(co['name']?.toString() ?? 'Select Company'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCompanyIdForUser = val;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showUserDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('추가'),
                  ),
                ],
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
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('소속회사')),
                  DataColumn(label: Text('아이디')),
                  DataColumn(label: Text('비밀번호')),
                  DataColumn(label: Text('잠금 횟수')),
                  DataColumn(label: Text('수정/삭제')),
                ],
                rows: provider.userData
                  .where((user) => _selectedCompanyIdForUser == null || user['com_id'] == _selectedCompanyIdForUser)
                  .map((user) => DataRow(
                  cells: [
                    DataCell(Text(user['id'].toString())),
                    DataCell(Text(_getCompanyName(provider.companyData, user['com_id'] as int))),
                    DataCell(Text(user['name'] ?? '')),
                    DataCell(Text(user['pw'] ?? '')),
                    DataCell(Text(user['lock_cnt']?.toString() ?? '0')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showUserDialog(userData: user)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteUser(user['id'])),
                      ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('백맨 (Backman) - Admin Panel'),
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
          // 왼쪽 사이드바 메뉴
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
              _fetchDataForIndex(index);
            },
            labelType: MediaQuery.of(context).size.width > 800 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            extended: MediaQuery.of(context).size.width > 800, // 화면이 크면 라벨 확장
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.business_outlined),
                selectedIcon: Icon(Icons.business),
                label: Text('회사 (Company)'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('표준코드 (Meta)'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt),
                label: Text('관리자 (User)'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 우측 컨텐츠
          Expanded(
            child: _selectedIndex == 0 
                ? _buildCompanyContent() 
                : _selectedIndex == 1 
                  ? _buildMetaContent() 
                  : _buildUserContent(),
          ),
        ],
      ),
    );
  }
}
