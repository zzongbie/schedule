import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/schedule_provider.dart';
import '../provider/auth_provider.dart';
import '../service/api_service.dart';
import 'login_page.dart';
import '../widget/m_calendar.dart';
import '../widget/w_calendar.dart';
import '../widget/t_calendar.dart';

class TouchScreenPage extends StatefulWidget {
  const TouchScreenPage({super.key});

  @override
  State<TouchScreenPage> createState() => _TouchScreenPageState();
}

class _TouchScreenPageState extends State<TouchScreenPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _tabTimer;
  
  Map<int, String> _branchNames = {};
  Map<int, int> _branchEmployeeCounts = {};
  List<Map<String, dynamic>> _subcoms = [];
  List<Map<String, dynamic>> _subcommaps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.comId != null) {
        final provider = context.read<ScheduleProvider>();
        provider.onlyPublicSchedules = true; // 터치스크린 전용: 공개 일정만
        provider.setComId(auth.comId, empId: auth.empId);
        _loadBranchData(auth.comId!);
      }
    });

    _tabController.addListener(() {
      if(!_tabController.indexIsChanging) {
        final provider = context.read<ScheduleProvider>();
        if(_tabController.index == 0) provider.setViewMode(ViewMode.monthly);
        if(_tabController.index == 1) provider.setViewMode(ViewMode.weekly);
        if(_tabController.index == 2) provider.setViewMode(ViewMode.daily);
      }
    });

    _tabTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        int nextIndex = (_tabController.index + 1) % _tabController.length;
        _tabController.animateTo(nextIndex);
      }
    });
  }

  Future<void> _loadBranchData(int comId) async {
    try {
      final subcoms = await ApiService.getGenericList('subcom', comId);
      final employees = await ApiService.getGenericList('employee', comId);
      final subcommaps = await ApiService.getGenericList('subcommap', comId);
      
      final Map<int, String> names = {};
      for (var s in subcoms) {
        names[s['id'] as int] = s['name']?.toString() ?? '';
      }

      final Map<int, int> counts = {};
      for (var emp in employees) {
        if (emp['name'] == 'admin' || emp['name'] == '관리자') continue;
        
        // T로 시작하는 메타코드 확인
        String position = emp['position']?.toString() ?? '';
        String authCode = emp['auth']?.toString() ?? '';
        String metaCode = position.isNotEmpty ? position : authCode;
        
        if (metaCode.startsWith('T')) {
          int scmId = emp['scm_id'] ?? 0;
          counts[scmId] = (counts[scmId] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _subcoms = List<Map<String, dynamic>>.from(subcoms);
          _subcommaps = List<Map<String, dynamic>>.from(subcommaps);
          _branchNames = names;
          _branchEmployeeCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('지점 데이터 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 300,
        leading: const Padding(
          padding: EdgeInsets.only(left: 32.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('TOUCH KIOSK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 36, color: Colors.indigo)),
          ),
        ),
        title: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          labelStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 28),
          tabs: const [
            Tab(text: '월간', icon: Icon(Icons.calendar_month, size: 40)),
            Tab(text: '주간', icon: Icon(Icons.view_week, size: 40)),
            Tab(text: '일간', icon: Icon(Icons.today, size: 40)),
            Tab(text: '지점보기', icon: Icon(Icons.map_outlined, size: 40)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 40),
            tooltip: '로그아웃',
            onPressed: () {
              context.read<AuthProvider>().logout();
              context.read<ScheduleProvider>().onlyPublicSchedules = false; // 리셋
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
          ),
          const SizedBox(width: 16),
        ],
        elevation: 1,
        backgroundColor: Colors.white,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 메인 뷰어
          Expanded(
            child: Consumer<ScheduleProvider>(
              builder: (context, provider, child) {
                return TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // 탭 스와이프 방지
                  children: [
                    const IgnorePointer(child: MCalendar()),
                    const IgnorePointer(child: WCalendar()),
                    const IgnorePointer(child: TCalendar()),
                    _buildBranchMapWidget(),
                  ],
                );
              },
            ),
          ),
          
          // 우측 지점 현황 바
          _buildRightSidebar(),
        ],
      ),
    );
  }

  Widget _buildRightSidebar() {
    return Container(
      width: 560,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(40.0),
            color: Colors.indigo.shade50,
            width: double.infinity,
            child: const Text(
              '지점별 직원 현황',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.indigo),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _branchNames.keys.length + 1, // 미지정 포함
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        int count = _branchEmployeeCounts[0] ?? 0;
                        if (count == 0) return const SizedBox();
                        return _buildBranchRow('본사/미배정', count);
                      }
                      int scmId = _branchNames.keys.elementAt(index - 1);
                      String name = _branchNames[scmId] ?? '알 수 없음';
                      int count = _branchEmployeeCounts[scmId] ?? 0;
                      return _buildBranchRow(name, count);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(32.0),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 40),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '외부에 공개된 일정만 반영되며 일정 추가는 하실 수 없습니다.',
                    style: TextStyle(fontSize: 24, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchRow(String name, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.indigo : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '$count명',
              style: TextStyle(
                fontSize: 28,
                color: count > 0 ? Colors.white : Colors.black54, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 지점보기 지도 위젯 (대한민국)
  Widget _buildBranchMapWidget() {
    // subcommap 데이터 파싱해서 표시, sido(시도)별로 클러스터링
    Map<String, List<Map<String, dynamic>>> byRegion = {};
    for (var sm in _subcommaps) {
      String region = sm['sido']?.toString() ?? '기타';
      if (region.isEmpty) region = '기타';
      
      // 약식 매핑 처리 (필요시 추가)
      if (region.contains('서울')) region = '서울';
      else if (region.contains('경기')) region = '경기';
      else if (region.contains('인천')) region = '인천';
      else if (region.contains('강원')) region = '강원';
      else if (region.contains('충남') || region.contains('충청남도')) region = '충남';
      else if (region.contains('충북') || region.contains('충청북도')) region = '충북';
      else if (region.contains('대전')) region = '대전';
      else if (region.contains('경북') || region.contains('경상북도')) region = '경북';
      else if (region.contains('경남') || region.contains('경상남도')) region = '경남';
      else if (region.contains('전북') || region.contains('전라북도')) region = '전북';
      else if (region.contains('전남') || region.contains('전라남도')) region = '전남';
      else if (region.contains('대구')) region = '대구';
      else if (region.contains('광주')) region = '광주';
      else if (region.contains('울산')) region = '울산';
      else if (region.contains('부산')) region = '부산';
      else if (region.contains('제주')) region = '제주';
      else if (region.contains('세종')) region = '세종';

      byRegion.putIfAbsent(region, () => []).add(sm);
    }
    
    // 서울(0.41, 0.27)과 부산(0.77, 0.63)을 기준으로 1차 보간(Linear Interpolation)된 비율
    final Map<String, Offset> regionCoordinates = {
      '서울': const Offset(0.41, 0.27),
      '인천': const Offset(0.31, 0.28),
      '경기': const Offset(0.43, 0.31),
      '강원': const Offset(0.64, 0.25),
      '충남': const Offset(0.36, 0.43),
      '세종': const Offset(0.43, 0.43),
      '대전': const Offset(0.46, 0.46),
      '충북': const Offset(0.56, 0.39),
      '전북': const Offset(0.41, 0.53),
      '광주': const Offset(0.37, 0.61),
      '전남': const Offset(0.33, 0.67),
      '대구': const Offset(0.69, 0.53),
      '경북': const Offset(0.72, 0.41),
      '울산': const Offset(0.79, 0.57),
      '부산': const Offset(0.77, 0.63),
      '경남': const Offset(0.64, 0.61),
      '제주': const Offset(0.33, 0.73),
      '기타': const Offset(0.79, 0.70),
    };

    final List<String> presentRegions = byRegion.keys.toList();
    
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
           final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          
          // 지도의 실제 표시 비율 계산 (이미지 AspectRatio 가 대략 0.75 비율)
          final double mapHeight = height * 0.95; 
          final double mapWidth = mapHeight * 0.75;
          final double mapLeft = (width - mapWidth) / 2;
          final double mapTop = (height - mapHeight) / 2;

          Offset getPinPosition(String region) {
            final pos = regionCoordinates[region] ?? const Offset(0.5, 0.5);
            return Offset(mapLeft + (mapWidth * pos.dx), mapTop + (mapHeight * pos.dy));
          }
          
          return CustomPaint(
            painter: MapConnectorPainter(
              regions: presentRegions,
              getPinPosition: getPinPosition, // 좌표 계산 함수 전달
            ),
            child: Stack(
              children: [
                // 한반도(남한) 지도 배경 이미지 삽입
                Positioned(
                  left: mapLeft,
                  top: mapTop,
                  width: mapWidth,
                  height: mapHeight,
                  child: Opacity(
                    opacity: 0.7, // 진하게 변경 (0.15 -> 0.7)
                    child: Image.network(
                      'img/korea_location.png',
                      fit: BoxFit.fill, // 정확한 매핑을 위해 fill 고정
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.map, size: 400, color: Colors.indigo),
                    ),
                  ),
                ),
                
                // 각 지역별 핀
                ...presentRegions.map((region) {
                  final pinPos = getPinPosition(region);
                  return Positioned(
                    left: pinPos.dx - 24,
                    top: pinPos.dy - 24,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Center(
                        child: Text(
                          '${byRegion[region]?.length ?? 0}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }).toList(),

                // 각 지역별 정보 카드
                ...presentRegions.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String region = entry.value;
                  bool isLeftSide = idx % 2 == 0;
                  
                  // 카드를 좌/우로 나누어 균등하게 배치
                  double topOffset = (idx ~/ 2) * 280.0 + 80.0;
                  double leftOffset = isLeftSide ? 80.0 : width - 560.0;
                  
                  // 너무 내려가면 컬럼을 더 나눔
                  if (topOffset > height - 300) {
                    topOffset = ((idx ~/ 2) - 4) * 280.0 + 80.0;
                    leftOffset = isLeftSide ? 600.0 : width - 1080.0;
                  }

                  return Positioned(
                    left: leftOffset,
                    top: topOffset,
                    child: SizedBox(
                      width: 480,
                      height: 240,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: Colors.indigo.withOpacity(0.3), width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.redAccent, size: 36),
                                  const SizedBox(width: 8),
                                  Text(
                                    region, 
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo)
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                                    child: Text('${byRegion[region]?.length ?? 0}개 지점', style: const TextStyle(fontSize: 24)),
                                  )
                                ],
                              ),
                              const Divider(height: 32),
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const ClampingScrollPhysics(), // 터치 스크롤 지원
                                  itemCount: byRegion[region]?.length ?? 0,
                                  itemBuilder: (context, mapIndex) {
                                    var m = byRegion[region]![mapIndex];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.storefront, size: 28, color: Colors.black54),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${m['subcom_name'] ?? '알 수 없는 지점'}', 
                                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }
      ),
    );
  }
}

class MapConnectorPainter extends CustomPainter {
  final List<String> regions;
  final Offset Function(String region) getPinPosition;

  MapConnectorPainter({
    required this.regions,
    required this.getPinPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo.withOpacity(0.4)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;

    for (int idx = 0; idx < regions.length; idx++) {
      String region = regions[idx];
      bool isLeftSide = idx % 2 == 0;
      
      double topOffset = (idx ~/ 2) * 280.0 + 80.0;
      double leftOffset = isLeftSide ? 80.0 : width - 560.0;
      
      if (topOffset > height - 300) {
        topOffset = ((idx ~/ 2) - 4) * 280.0 + 80.0;
        leftOffset = isLeftSide ? 600.0 : width - 1080.0;
      }

      // 카드의 연결점 (카드 테두리)
      Offset cardPoint;
      if (isLeftSide) {
        cardPoint = Offset(leftOffset + 480, topOffset + 120); // 카드 우측 중앙
      } else {
        cardPoint = Offset(leftOffset, topOffset + 120); // 카드 좌측 중앙
      }

      // 맵의 핀 위치
      Offset mapPoint = getPinPosition(region);

      // 곡선(베지어) 그리기
      final path = Path();
      path.moveTo(mapPoint.dx, mapPoint.dy);
      
      // 제어점 설정 (완만한 S자 커브)
      Offset controlPoint1 = Offset(mapPoint.dx + (cardPoint.dx - mapPoint.dx) / 2, mapPoint.dy);
      Offset controlPoint2 = Offset(mapPoint.dx + (cardPoint.dx - mapPoint.dx) / 2, cardPoint.dy);
      
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, cardPoint.dx, cardPoint.dy);
      
      canvas.drawPath(path, paint);

      // 카드 연결 부위에 작은 점
      canvas.drawCircle(cardPoint, 8, Paint()..color = Colors.indigo..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
