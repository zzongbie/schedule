import 'dart:convert';
import 'package:http/http.dart' as http;

/// 백엔드(FastAPI)와의 통신을 전담하는 서비스 클래스 (백맨 연동)
class ApiService {
  // 실제 서버 환경에 맞춰 base URL을 변경할 수 있습니다.
  static const String _baseUrl = 'http://127.0.0.1:8000/api/v1';

  /// 사용자 로그인 API
  /// 
  /// [userId] 아이디 (name)
  /// [password] 비밀번호 (pw)
  /// 반환값: Map 형식의 JSON 응답 데이터 (user_id 등)
  static Future<Map<String, dynamic>> login(String userId, String password) async {
    final url = Uri.parse('$_baseUrl/users/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'password': password}),
    );

    final decodedBody = json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    
    if (response.statusCode == 200) {
      return decodedBody;
    } else {
      throw Exception(decodedBody['detail'] ?? '로그인에 실패했습니다.');
    }
  }

  /// 아이디 중복 확인 API
  static Future<bool> checkId(String userId) async {
    final url = Uri.parse('$_baseUrl/users/check_id');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );

    final decodedBody = json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    
    if (response.statusCode == 200) {
      return decodedBody['available'] ?? false;
    } else {
      throw Exception(decodedBody['detail'] ?? '중복 확인에 실패했습니다.');
    }
  }

  /// 회원가입 API
  static Future<void> signUp(String userId, String password, String otp) async {
    final url = Uri.parse('$_baseUrl/users/signup');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'password': password,
        'otp': otp,
      }),
    );

    if (response.statusCode != 200) {
      final decodedBody = json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
      throw Exception(decodedBody['detail'] ?? '회원가입에 실패했습니다.');
    }
  }

  /// 모든 회사(Company) 목록 조회
  static Future<List<dynamic>> getCompanies() async {
    final response = await http.get(Uri.parse('$_baseUrl/admin/company'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    throw Exception('회사 데이터를 불러오는데 실패했습니다.');
  }

  /// 회사(Company) 추가
  static Future<void> createCompany(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/company'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('회사 추가 실패');
    }
  }

  /// 회사(Company) 수정
  static Future<void> updateCompany(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/company/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('회사 수정 실패');
    }
  }

  /// 회사(Company) 삭제
  static Future<void> deleteCompany(int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/admin/company/$id'));
    if (response.statusCode != 200) {
      throw Exception('회사 삭제 실패');
    }
  }

  /// 모든 메타(Meta) 목록 조회
  static Future<List<dynamic>> getMetas() async {
    final response = await http.get(Uri.parse('$_baseUrl/admin/meta'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    throw Exception('메타 데이터를 불러오는데 실패했습니다.');
  }

  /// 메타(Meta) 추가
  static Future<void> createMeta(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/meta'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('메타 추가 실패');
    }
  }

  /// 메타(Meta) 수정
  static Future<void> updateMeta(int comId, String code, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/meta/$comId/$code'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('메타 수정 실패');
    }
  }

  /// 메타(Meta) 삭제
  static Future<void> deleteMeta(int comId, String code) async {
    final response = await http.delete(Uri.parse('$_baseUrl/admin/meta/$comId/$code'));
    if (response.statusCode != 200) {
      throw Exception('메타 삭제 실패');
    }
  }

  // ============== Company Admin Entities ==============
  
  static Future<List<dynamic>> getGenericList(String entity, int companyId) async {
    final response = await http.get(Uri.parse('$_baseUrl/company/$companyId/$entity'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    throw Exception('$entity 데이터를 불러오는데 실패했습니다.');
  }

  static Future<void> createGeneric(String entity, int companyId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/company/$companyId/$entity'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('$entity 추가 실패');
    }
  }

  static Future<void> updateGeneric(String entity, int companyId, int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/company/$companyId/$entity/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('$entity 수정 실패');
    }
  }

  static Future<void> deleteGeneric(String entity, int companyId, int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/company/$companyId/$entity/$id'));
    if (response.statusCode != 200) {
      throw Exception('$entity 삭제 실패');
    }
  }

  // ============== Admin User Entities ==============
  
  static Future<List<dynamic>> getUsers() async {
    final response = await http.get(Uri.parse('$_baseUrl/admin/user'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    throw Exception('관리자 계정 데이터를 불러오는데 실패했습니다.');
  }

  static Future<void> createUser(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/user'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('관리자 추가 실패');
    }
  }

  static Future<void> updateUser(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/user/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('관리자 수정 실패');
    }
  }

  static Future<void> deleteUser(int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/admin/user/$id'));
    if (response.statusCode != 200) {
      throw Exception('관리자 삭제 실패');
    }
  }

  // ============== Schedule API ==============

  static Future<List<dynamic>> getSchedules(int comId) async {
    final response = await http.get(Uri.parse('$_baseUrl/schedules/?com_id=$comId'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    }
    throw Exception('일정 목록을 불러오는데 실패했습니다.');
  }

  static Future<void> createSchedule(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/schedules/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decodedBody = json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
      throw Exception(decodedBody['detail'] ?? '일정 추가에 실패했습니다.');
    }
  }

  static Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/schedules/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final decodedBody = json.decode(utf8.decode(response.bodyBytes, allowMalformed: true));
      throw Exception(decodedBody['detail'] ?? '일정 수정에 실패했습니다.');
    }
  }
}
