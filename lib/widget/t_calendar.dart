import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../provider/schedule_provider.dart';
import '../provider/auth_provider.dart';
import 'schedule_add_dialog.dart';

class TCalendar extends StatelessWidget {
  const TCalendar({Key? key}) : super(key: key);

  String _getKoWeekday(int weekday) {
    switch (weekday) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      case 6: return '토';
      case 7: return '일';
      default: return '';
    }
  }

  String _formatTime(double hourDecimal) {
    int h = hourDecimal.toInt();
    int m = ((hourDecimal - h) * 60).toInt();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final day = provider.selectedDay ?? provider.focusedDay;
    
    final int hourHeight = 240;
    final double tenMinHeight = 240 / 6;

    final now = DateTime.now();
    final bool isTodaySelected = day.year == now.year && day.month == now.month && day.day == now.day;

    return Container(
      margin: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Day navigation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 48),
                  onPressed: () {
                    provider.selectDay(day.subtract(const Duration(days: 1)), day.subtract(const Duration(days: 1)));
                  },
                ),
                Text(
                  '${DateFormat('yyyy년 MM월 dd일').format(day)} (${_getKoWeekday(day.weekday)})',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 48),
                  onPressed: () {
                    provider.selectDay(day.add(const Duration(days: 1)), day.add(const Duration(days: 1)));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Timetable body
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time labels column (30-minute intervals)
                  SizedBox(
                    width: 140,
                    child: Column(
                      children: List.generate(48, (index) {
                        final hour = index ~/ 2;
                        final minute = (index % 2) * 30;
                        final timeString = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                        return Container(
                          height: hourHeight / 2, // 60px
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.0)),
                          ),
                          child: Text(timeString, style: const TextStyle(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.w600)),
                        );
                      }),
                    ),
                  ),
                  // Grid & Events
                  Expanded(
                    child: Stack(
                      children: [
                        // Background grid lines (10-minute intervals)
                        Column(
                          children: List.generate(24 * 6, (index) {
                            // index: 0 ~ 143 (144 blocks total for 24 hours, each block = 10 mins)
                            // Every 3 blocks = 30 mins
                            final bool isHalfHour = index % 3 == 0;
                            return InkWell(
                              onTap: () async {
                                final hour = index ~/ 6;
                                final min = (index % 6) * 10;
                                final tapDate = DateTime(day.year, day.month, day.day, hour, min);
                                final result = await showDialog(
                                  context: context,
                                  builder: (_) => ScheduleAddDialog(initialDate: tapDate),
                                );
                                if (result == true) {
                                  provider.loadSchedules();
                                }
                              },
                              child: Container(
                                height: tenMinHeight, // 20px
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isHalfHour ? Colors.grey.shade300 : Colors.grey.shade100,
                                      width: isHalfHour ? 1.0 : 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        
                        // Current time highlight block (If viewing today)
                        if (isTodaySelected)
                          Positioned(
                            top: (now.hour * 60 + now.minute) / 10.0 * tenMinHeight,
                            left: 0,
                            right: 0,
                            height: tenMinHeight,
                            child: Container(
                              color: Colors.redAccent.withOpacity(0.15),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text('지금 진행중...', style: TextStyle(color: Colors.red.shade800, fontSize: 20, fontWeight: FontWeight.bold)),
                            ),
                          ),

                        // Current time red line
                        if (isTodaySelected)
                          Positioned(
                            top: (now.hour + (now.minute / 60.0)) * hourHeight,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              color: Colors.redAccent,
                            ),
                          ),

                        // Events Lines (칸 대신 라인으로 표현 및 겹침 방지 - 옆으로 쌓기)
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final events = List<Map<String, dynamic>>.from(provider.getEventsForDay(day));
                              events.sort((a, b) => ((a['startHour'] as num?) ?? 0).compareTo((b['startHour'] as num?) ?? 0));

                              List<List<Map<String, dynamic>>> columns = [];

                              for (var event in events) {
                                double startHour = (event['startHour'] as num?)?.toDouble() ?? 9.0;
                                double duration = (event['duration'] as num?)?.toDouble() ?? 1.0;
                                
                                double topPos = startHour * hourHeight;
                                double height = duration * hourHeight;
                                
                                bool placed = false;
                                for (var col in columns) {
                                  if (col.last['bottomPos'] <= topPos + 0.1) {
                                    event['topPos'] = topPos;
                                    event['bottomPos'] = topPos + height;
                                    event['height'] = height;
                                    col.add(event);
                                    placed = true;
                                    break;
                                  }
                                }
                                if (!placed) {
                                  event['topPos'] = topPos;
                                  event['bottomPos'] = topPos + height;
                                  event['height'] = height;
                                  columns.add([event]);
                                }
                              }

                              if (columns.isEmpty) return const SizedBox();

                              final double availableWidth = constraints.maxWidth - 16.0; // left/right 8px
                              final double colWidth = availableWidth / columns.length;
                              
                              List<Widget> eventWidgets = [];
                              for (int i = 0; i < columns.length; i++) {
                                for (var event in columns[i]) {
                                  final Color color = event['color'] as Color;
                                  
                                  eventWidgets.add(
                                    Positioned(
                                      top: event['topPos'],
                                      left: 8.0 + (i * colWidth),
                                      width: colWidth - 2.0, // column gap
                                      height: event['height'],
                                      child: GestureDetector(
                                        onTap: () async {
                                          final auth = context.read<AuthProvider>();
                                          if (auth.empId == event['ins_id']) {
                                            final result = await showDialog(
                                              context: context,
                                              builder: (ctx) => ScheduleAddDialog(
                                                initialDate: DateTime.tryParse(event['start']?.toString() ?? '') ?? day,
                                                eventToEdit: event,
                                              ),
                                            );
                                            if (result == true) {
                                              provider.loadSchedules();
                                            }
                                          } else {
                                            final executors = (event['executors'] as List?) ?? [];
                                            final targets = (event['targets'] as List?) ?? [];
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text(event['title'] ?? '일정 상세'),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('작성자: ${event['ins_name'] ?? ''}'),
                                                    Text('직무: ${event['name']}'),
                                                    if (executors.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Text('수행자: ${executors.map((e) => e['name']).join(', ')}'),
                                                    ],
                                                    if (event['view_type'] == 2 && targets.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Text('공개대상: ${targets.map((t) => '${t['name']}(${t['type']})').join(', ')}'),
                                                    ],
                                                    const SizedBox(height: 8),
                                                    Text('일정: ${event['title']}'),
                                                    if (event['detail'] != null && event['detail'].toString().isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Text('내용:\n${event['detail']}'),
                                                    ],
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('닫기'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            border: Border(left: BorderSide(color: color, width: 4)),
                                            color: color.withOpacity(0.08),
                                          ),
                                          alignment: Alignment.topLeft,
                                          child: Text(
                                            // 일간은 시간과 이름, 제목을 표시
                                            '[${_formatTime((event['startHour'] as num).toDouble())}]\n${event['name']} - ${event['title']}',
                                            style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                                            maxLines: (event['height'] / 32).floor() > 0 ? (event['height'] / 32).floor() : 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                              return Stack(children: eventWidgets);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
