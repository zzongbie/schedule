import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'provider/schedule_provider.dart';
import 'provider/admin_provider.dart';
import 'provider/auth_provider.dart';
import 'provider/company_admin_provider.dart';
import 'widget/home_widget.dart';
import 'page/login_page.dart';
import 'page/google_test_page.dart'; // 구글 서비스 테스트용 페이지 임포트

void main() {
  runApp(const ScheduleApp());
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>(
          create: (context) => ScheduleProvider(),
        ),
        ChangeNotifierProvider<AdminProvider>(
          create: (context) => AdminProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(),
        ),
        ChangeNotifierProvider<CompanyAdminProvider>(
          create: (context) => CompanyAdminProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Schedule Assistant',
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        ),
        // home: const LoginPage(),
        home: const GoogleTestPage(), // 로그인 대신 구글 서비스 테스트 화면으로 바로 진입
      ),
    );
  }
}
