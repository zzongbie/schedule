import 'dart:convert';
import 'package:http/http.dart' as http;

/// 구글 캘린더 단일 이벤트 모델 (Data Parsing)
class GoogleCalendarEvent {
  final String id;
  final String? summary;
  final String? description;
  final String? location;
  final DateTime? start;
  final DateTime? end;
  final String status;

  GoogleCalendarEvent({
    required this.id,
    this.summary,
    this.description,
    this.location,
    this.start,
    this.end,
    required this.status,
  });

  /// API 응답(Map)을 Dart 객체로 파싱 (Parsing)
  factory GoogleCalendarEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Map<String, dynamic>? dateData) {
      if (dateData == null) return null;
      if (dateData.containsKey('dateTime')) {
        return DateTime.parse(dateData['dateTime']);
      } else if (dateData.containsKey('date')) {
        return DateTime.parse(dateData['date']);
      }
      return null;
    }

    return GoogleCalendarEvent(
      id: json['id'] ?? '',
      summary: json['summary'],
      description: json['description'],
      location: json['location'],
      start: parseDate(json['start']),
      end: parseDate(json['end']),
      status: json['status'] ?? 'unknown',
    );
  }

  @override
  String toString() {
    return 'GoogleCalendarEvent(summary: $summary, start: $start, end: $end)';
  }
}

/// 구글 캘린더 단일 이벤트 가져오는 서비스 (API Connection)
class GoogleCalendarService {
  // 구글 클라우드 콘솔이나 구글 로그인 연동을 통해 획득한 올바른 Access Token이 필요합니다.
  final String accessToken;

  GoogleCalendarService({required this.accessToken});

  /// 단일 일정 가져오기
  Future<GoogleCalendarEvent?> getSingleEvent({
    required String calendarId,
    required String eventId,
  }) async {
    // URL 인코딩 고려 (기본 캘린더는 보통 'primary' 문자열을 사용)
    final encodedCalendarId = Uri.encodeComponent(calendarId);
    final encodedEventId = Uri.encodeComponent(eventId);

    final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/$encodedCalendarId/events/$encodedEventId',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // 성공적으로 데이터를 받아옴 -> JSON 파싱
        final Map<String, dynamic> data = json.decode(response.body);
        return GoogleCalendarEvent.fromJson(data);
      } else {
        // 에러 발생 (권한 없음, 존재하지 않는 일정 등)
        print('Error fetching event: \${response.statusCode} \n \${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception occurred while fetching Google Calendar event: $e');
      return null;
    }
  }
}
