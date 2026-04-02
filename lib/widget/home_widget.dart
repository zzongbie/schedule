import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/schedule_provider.dart';
import '../provider/auth_provider.dart';
import '../page/company_admin_page.dart';
import '../page/login_page.dart';
import 'm_calendar.dart';
import 'w_calendar.dart';
import 't_calendar.dart';
import '../service/google_auth_service.dart';
import '../service/google_calendar_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in_web/web_only.dart' as web;

class HomeWidget extends StatefulWidget {
  const HomeWidget({Key? key}) : super(key: key);

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  bool _googleInitDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.comId != null) {
        context.read<ScheduleProvider>().setComId(auth.comId, empId: auth.empId);
      }
    });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 좌측 상단에 뷰 변경 버튼(Dropdown / Toggle)
        leadingWidth: 500,
        leading: Padding(
          padding: const EdgeInsets.only(left: 24.0),
          child: Row(
            children: [
              const Text('팀 스케줄', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
              const SizedBox(width: 24),
              Consumer<ScheduleProvider>(
                builder: (context, provider, child) {
                  return ToggleButtons(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 80),
                    borderRadius: BorderRadius.circular(8.0),
                    isSelected: [
                      provider.currentViewMode == ViewMode.monthly,
                      provider.currentViewMode == ViewMode.weekly,
                      provider.currentViewMode == ViewMode.daily,
                    ],
                    onPressed: (index) {
                      if (index == 0) provider.setViewMode(ViewMode.monthly);
                      else if (index == 1) provider.setViewMode(ViewMode.weekly);
                      else if (index == 2) provider.setViewMode(ViewMode.daily);
                    },
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('월간', style: TextStyle(fontSize: 24))),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('주간', style: TextStyle(fontSize: 24))),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('일간', style: TextStyle(fontSize: 24))),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return IconButton(
                icon: const Icon(Icons.settings_applications, size: 40),
                tooltip: '회사별 관리',
                onPressed: auth.gubun == 'G001' 
                    ? () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyAdminPage()));
                      }
                    : () {
                        // A002 등 다른 사용자는 모양만 있고 기능 안함 (또는 안내 메시지)
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('권한이 없습니다.')));
                      }, 
              );
            },
          ),
          kIsWeb
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: SizedBox(
                    width: 120, // 웹 로그인을 위한 공식 구글 버튼 규격
                    child: _googleInitDone 
                        ? web.renderButton() 
                        : const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync_rounded, size: 40),
                  tooltip: '구글 캘린더 연동',
                  onPressed: () async {
                    final token = await GoogleAuthService.signInAndGetToken();
                    if (token != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('구글 로그인 성공! 토큰 발급 완료.')));
                      }
                      // TODO: 단일 일정 불러오기 테스트 시 아래 주석 풀기
                      // final calendarService = GoogleCalendarService(accessToken: token);
                      // final event = await calendarService.getSingleEvent(calendarId: 'primary', eventId: '...');
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('구글 로그인이 취소되었거나 실패했습니다.')));
                      }
                    }
                  },
                ),
          IconButton(
            icon: const Icon(Icons.logout, size: 40),
            tooltip: '로그아웃',
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
          ),
          const SizedBox(width: 16),
        ],
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(context),
          Expanded(
            child: Consumer<ScheduleProvider>(
              builder: (context, provider, child) {
                switch (provider.currentViewMode) {
                  case ViewMode.monthly:
                    return const MCalendar();
                  case ViewMode.weekly:
                    return const WCalendar();
                  case ViewMode.daily:
                    return const TCalendar();
                  default:
                    return const MCalendar();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    
    return Container(
      width: 480,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              '직원 목록 / Employees',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: provider.branchData.entries.map((branchEntry) {
                return ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    branchEntry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 24),
                  ),
                  children: branchEntry.value.entries.map((deptEntry) {
                    return ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(
                        deptEntry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
                      ),
                      children: deptEntry.value.map((emp) {
                        return CheckboxListTile(
                          dense: true,
                          activeColor: provider.employeeColors[emp] ?? Colors.indigo,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: provider.employeeColors[emp] ?? Colors.indigo,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(emp, style: const TextStyle(fontSize: 20)),
                            ]
                          ),
                          value: provider.employeeCheckboxState[emp] ?? false,
                          onChanged: (bool? value) {
                            provider.toggleEmployee(emp, value);
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
          // A friendly message from Frontman (Persona!)
          Container(
            padding: const EdgeInsets.all(24.0),
            color: Colors.indigo.shade50,
            child: const Row(
              children: [
                Icon(Icons.face, color: Colors.indigo, size: 40),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '"정프로님, 조회하실 직원들을 선택해 주십시오! 충성!"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
