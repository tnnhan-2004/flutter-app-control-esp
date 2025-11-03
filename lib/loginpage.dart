// lib/loginpage.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart'; // Để điều hướng về RegistrationPage
import 'mainmenu.dart'; // Để điều hướng đến Mainmenu

// --- PHẦN 1: MODEL DỮ LIỆU (KHÔNG ĐỔI) ---
class UserAccount {
  String name;
  String email;
  String password;
  UserAccount({required this.name, required this.email, required this.password});

  static UserAccount fromJson(Map<String, dynamic> json) => UserAccount(
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    password: json['password'] ?? '',
  );
}

// --- PHẦN 2: LỚP GIAO DIỆN TĨNH ---
// Lớp này là điểm khởi đầu, nó sẽ gọi lớp logic để hiển thị
class LoginPageWithLogic extends StatelessWidget {
  const LoginPageWithLogic({super.key});

  @override
  Widget build(BuildContext context) {
    return _EditableLoginPage();
  }
}

// --- PHẦN 3: LỚP LOGIC VÀ STATE (STATEFUL WIDGET) ---
class _EditableLoginPage extends StatefulWidget {
  @override
  _EditableLoginPageState createState() => _EditableLoginPageState();
}

class _EditableLoginPageState extends State<_EditableLoginPage> {
  // --- TOÀN BỘ LOGIC NẰM Ở ĐÂY ---
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final prefs = await SharedPreferences.getInstance();
    final accountsData = prefs.getStringList('accounts') ?? [];
    UserAccount? foundUser;

    for (final accountString in accountsData) {
      try {
        final accountJson = jsonDecode(accountString) as Map<String, dynamic>;
        final account = UserAccount.fromJson(accountJson);
        if (account.email == email && account.password == pass) {
          foundUser = account;
          break;
        }
      } catch (e) { /* Lỗi */ }
    }

    if (!mounted) return;

    if (foundUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Mainmenu(currentUser: foundUser!)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email hoặc mật khẩu không chính xác!')),
      );
    }
  }

  void _goToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RegistrationPage()),
    );
  }
  // --- HẾT PHẦN LOGIC ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Center(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Container(
              width: 375,
              height: 812,
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                gradient: const LinearGradient(
                  begin: Alignment(0.50, -0.00),
                  end: Alignment(0.50, 1.00),
                  colors: [Color(0xFF3EBCFD), Color(0xFF4845D9)],
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Stack(
                children: [
                  // Các thành phần nền tĩnh
                  Positioned(
                      left: -96, top: -101,
                      child: Container(width: 347, height: 347, decoration: const ShapeDecoration(gradient: LinearGradient(colors: [Color(0xFF58E0AA), Color(0xFF49C8F2)], begin: Alignment(0.50, -0.00), end: Alignment(0.50, 1.00)), shape: OvalBorder()))),
                  Positioned(
                      left: 25, top: 164,
                      child: Text('Welcome Back!', style: TextStyle(color: Colors.black.withOpacity(0.75), fontSize: 40, fontFamily: 'Poppins', fontWeight: FontWeight.w600))),
                  Positioned(
                      left: 90, top: 240,
                      child: Container(width: 195, height: 195, decoration: ShapeDecoration(image: const DecorationImage(image: NetworkImage("https://placehold.co/195x195"), fit: BoxFit.cover), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))))),

                  // Các trường nhập liệu được gắn logic
                  Positioned(
                    left: 25, top: 468,
                    child: buildTextField(controller: _emailCtrl, hintText: 'Enter your email', keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Vui lòng nhập email hợp lệ' : null),
                  ),
                  Positioned(
                    left: 25, top: 540,
                    child: buildTextField(controller: _passCtrl, hintText: 'Enter password', obscureText: true, validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null),
                  ),

                  // Các nút được gắn logic
                  const Positioned(
                      left: 124, right: 124, top: 616,
                      child: Text('Forgot Password', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF50C2C9), fontSize: 14, fontFamily: 'Poppins', fontWeight: FontWeight.w400))),
                  Positioned(
                    left: 25, top: 656,
                    child: GestureDetector(
                        onTap: _signIn,
                        child: Container(width: 325, height: 62, decoration: const BoxDecoration(color: Color(0xFF50C2C9), borderRadius: BorderRadius.all(Radius.circular(30))),
                            child: const Center(child: Text('Sign In', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Poppins', fontWeight: FontWeight.w600))))
                    ),
                  ),
                  Positioned(
                    top: 747, left: 0, right: 0,
                    child: GestureDetector(
                      onTap: _goToRegister,
                      child: const Text.rich(TextSpan(children: [
                        TextSpan(text: 'Don’t have an account ? ', style: TextStyle(color: Colors.black, fontSize: 14, fontFamily: 'Poppins')),
                        TextSpan(text: 'Sign Up', style: TextStyle(color: Color(0xFF50C2C9), fontSize: 14, fontFamily: 'Poppins', fontWeight: FontWeight.w700))
                      ]), textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Hàm helper
  Widget buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      width: 325,
      height: 70,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black, fontSize: 13, fontFamily: 'Poppins'),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.70), fontSize: 13, fontFamily: 'Poppins'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          errorStyle: const TextStyle(height: 0.8),
        ),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }
}
