import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../provider/schedule_provider.dart';
import '../provider/auth_provider.dart';
import 'schedule_add_dialog.dart';

class WCalendar extends StatelessWidget {
  const WCalendar({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    
    final today = provider.focusedDay;
    // Monday as start of week:
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final daysOfWeek = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));

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
          // Header with Week navigation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 48),
                  onPressed: () {
                    provider.selectDay(provider.selectedDay ?? today, provider.focusedDay.subtract(const Duration(days: 7)));
                  },
                ),
                Text(
                  '${DateFormat('yyyy년 MM월').format(startOfWeek)} ${startOfWeek.day}일 ~ ${daysOfWeek.last.day}일',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 48),
                  onPressed: () {
                    provider.selectDay(provider.selectedDay ?? today, provider.focusedDay.add(const Duration(days: 7)));
                  },
                ),
              ],
            ),
          ),
          // Days header
          Row(
            children: [
              const SizedBox(width: 120), // Space for time column
              ...daysOfWeek.map((day) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: isSameDay(day, DateTime.now()) ? Colors.indigo.withOpacity(0.1) : null,
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Text(_getKoWeekday(day.weekday), 
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold, 
                          color: day.weekday == 7 ? Colors.red : (day.weekday == 6 ? Colors.blue : Colors.black87)
                        )
                      ),
                      const SizedBox(height: 8),
                      Text('${day.day}', style: const TextStyle(fontSize: 28)),
                    ],
                  ),
                ),
              )),
            ],
          ),
          // Timetable body
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time column
                  SizedBox(
                    width: 120,
                    child: Column(
                      children: List.generate(24, (index) {
                        return Container(
                          height: 120,
                          alignment: Alignment.topCenter,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('${index.toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.grey, fontSize: 24)),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Days columns
                  ...daysOfWeek.map((day) => Expanded(
                    child: _buildDayColumn(context, day),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(BuildContext context, DateTime day) {
    final provider = context.read<ScheduleProvider>();
    
    return Stack(
      children: [
        // Background grid cells
        Column(
          children: List.generate(24, (index) {
            return InkWell(
              onTap: () async {
                final tapDate = DateTime(day.year, day.month, day.day, index);
                final result = await showDialog(
                  context: context,
                  builder: (_) => ScheduleAddDialog(initialDate: tapDate),
                );
                if (result == true) {
                  provider.loadSchedules();
                }
              },
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200, width: 0.5),
                  color: isSameDay(day, DateTime.now()) ? Colors.indigo.withOpacity(0.02) : Colors.transparent,
                ),
              ),
            );
          }),
        ),
        // Event lines (옆으로 쌓기)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final events = List<Map<String, dynamic>>.from(provider.getEventsForDay(day));
              events.sort((a, b) => ((a['startHour'] as num?) ?? 0).compareTo((b['startHour'] as num?) ?? 0));

              List<List<Map<String, dynamic>>> columns = [];

              for (var event in events) {
                double startHour = (event['startHour'] as num?)?.toDouble() ?? 9.0;
                double duration = (event['duration'] as num?)?.toDouble() ?? 1.0;
                double topPos = startHour * 120.0;
                double height = duration * 120.0;
                
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

              final double availableWidth = constraints.maxWidth - 4.0; // left/right padding
              final double colWidth = availableWidth / columns.length;
              
              List<Widget> eventWidgets = [];
              for (int i = 0; i < columns.length; i++) {
                for (var event in columns[i]) {
                  final Color color = event['color'] as Color;
                  eventWidgets.add(
                    Positioned(
                      top: event['topPos'],
                      left: 2.0 + (i * colWidth),
                      width: colWidth - 1.0, 
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
                          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: color, width: 2)),
                            color: color.withOpacity(0.1),
                          ),
                          alignment: Alignment.topLeft,
                          child: Text(
                            '${event['ins_name'] ?? ''} : ${event['name']}', 
                            style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: (event['height'] / 24).floor() > 0 ? (event['height'] / 24).floor() : 1,
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
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
