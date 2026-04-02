import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../provider/schedule_provider.dart';
import '../provider/auth_provider.dart';
import 'schedule_add_dialog.dart';

class MCalendar extends StatelessWidget {
  const MCalendar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final headerHeight = 100.0;
          final daysOfWeekHeight = 60.0;
          final availableHeight = constraints.maxHeight - headerHeight - daysOfWeekHeight - 32;
          final calculatedRowHeight = (availableHeight / 6).clamp(120.0, 300.0);
          
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: provider.focusedDay,
              rowHeight: calculatedRowHeight,
              daysOfWeekHeight: daysOfWeekHeight,
              eventLoader: provider.getEventsForDay,
              selectedDayPredicate: (day) {
                return isSameDay(provider.selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                provider.selectDay(selectedDay, focusedDay);
                
                final dateFormatted = DateFormat('yyyy-MM-dd').format(selectedDay);
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📅 [$dateFormatted] 선택 완료! 프론트맨이 일정을 확인 중입니다!'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.red),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, isToday: false, isSelected: false),
                todayBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, isToday: true, isSelected: false),
                selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, isToday: false, isSelected: true),
                outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, isToday: false, isSelected: false, isOutside: true),
                markerBuilder: (context, day, events) => const SizedBox(),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildCalendarCell(BuildContext context, DateTime day, {required bool isToday, required bool isSelected, bool isOutside = false}) {
    final provider = context.read<ScheduleProvider>();
    final events = provider.getEventsForDay(day);
    
    return InkWell(
      onTap: () async {
        final result = await showDialog(
          context: context,
          builder: (context) => ScheduleAddDialog(initialDate: day),
        );
        if (result == true) {
          provider.loadSchedules();
        }
      },
      child: Container(
        margin: const EdgeInsets.all(1.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.indigo.withOpacity(0.1) : Colors.transparent,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: isToday ? Colors.indigo : Colors.transparent,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 24,
                color: isOutside ? Colors.grey.shade400 : (isToday ? Colors.white : Colors.black87),
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: events.map((event) {
                  return GestureDetector(
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
                      margin: const EdgeInsets.only(bottom: 4.0, top: 2.0),
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: event['color'].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: event['color'].withOpacity(0.5)),
                      ),
                      child: Text(
                        '${event['ins_name'] ?? ''} : ${event['name']}',
                        style: TextStyle(
                          fontSize: 18,
                          color: event['color'].withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
