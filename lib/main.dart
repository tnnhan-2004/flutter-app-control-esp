// lib/main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'loginpage.dart';
import 'notification_service.dart';

// =================================================================
// PHẦN 1: KHỞI TẠO ỨNG DỤNG
// =================================================================
// Hàm main là điểm bắt đầu của ứng dụng.
Future<void> main() async {
  // Đảm bảo các thành phần của Flutter đã sẵn sàng trước khi thực hiện các tác vụ khác.
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo dịch vụ thông báo để có thể nhận thông báo đẩy.
  await NotificationService().init();

  // Chạy widget gốc của ứng dụng.
  runApp(const SmarthomeApp());
}

// Lớp App gốc, nơi chứa cấu hình chung của ứng dụng như Theme.
class SmarthomeApp extends StatelessWidget {
  const SmarthomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Cấu hình giao diện chung cho toàn bộ ứng dụng.
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 18, 32, 47),
      ),
      // Màn hình đầu tiên khi mở ứng dụng.
      // SỬA ĐỔI: Bỏ Scaffold thừa ở đây. Trang RegistrationPage sẽ tự quản lý Scaffold của nó.
      home: const RegistrationPage(),
    );
  }
}


// =================================================================
// PHẦN 2: TÁCH BIỆT UI VÀ LOGIC CHO TRANG ĐĂNG KÝ
// =================================================================

// -----------------------------------------------------------------
// Lớp Widget UI (StatelessWidget)
// -----------------------------------------------------------------
// Lớp này chỉ có một nhiệm vụ: trả về widget chứa logic.
// Việc tách biệt này giúp phần giao diện (ở file khác sau này) không bị lẫn lộn với code xử lý.
class RegistrationPage extends StatelessWidget {
  const RegistrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Trả về widget có trạng thái (StatefulWidget), nơi chứa toàn bộ logic.
    return const _EditableRegistrationPage();
  }
}

// -----------------------------------------------------------------
// Lớp Widget Logic và State (StatefulWidget)
// -----------------------------------------------------------------
// Lớp StatefulWidget chỉ làm một việc là tạo ra đối tượng State.
class _EditableRegistrationPage extends StatefulWidget {
  const _EditableRegistrationPage();

  @override
  _EditableRegistrationPageState createState() => _EditableRegistrationPageState();
}

// Lớp State là nơi chứa "linh hồn" của trang:
// - Tất cả các biến trạng thái (giá trị trong các ô input).
// - Các hàm xử lý sự kiện (nhấn nút đăng ký, chuyển trang).
// - Hàm build() để dựng giao diện từ state hiện tại.
class _EditableRegistrationPageState extends State<_EditableRegistrationPage> {
  // --- A. PHẦN LOGIC VÀ STATE ---

  // Key để quản lý trạng thái của Form (validate, save, reset).
  final _formKey = GlobalKey<FormState>();

  // Controller để đọc và điều khiển giá trị của các ô TextField.
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  // Hàm dọn dẹp controller khi widget bị xóa khỏi cây giao diện.
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // Hàm xử lý logic khi người dùng nhấn nút "Register".
  void _register() async {
    // 1. Kiểm tra xem form có hợp lệ không.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // Nếu không hợp lệ thì dừng lại.
    }

    // 2. Tạo đối tượng người dùng mới từ dữ liệu trong controller.
    final newUser = {
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
    };

    // 3. Lưu tài khoản vào SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    accounts.add(jsonEncode(newUser));
    await prefs.setStringList('accounts', accounts);

    // 4. Hiển thị thông báo và chuyển hướng đến trang đăng nhập.
    if (!mounted) return; // Kiểm tra xem widget còn tồn tại không.

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đăng ký thành công! Vui lòng đăng nhập.')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPageWithLogic()),
    );
  }

  // Hàm xử lý logic khi người dùng nhấn vào link "Sign in".
  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPageWithLogic()),
    );
  }

  // --- B. PHẦN DỰNG GIAO DIỆN (BUILD METHOD) ---
  // Hàm build sử dụng các state và logic ở trên để dựng UI.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 375,
            height: 812,
            clipBehavior: Clip.antiAlias,
            decoration: _buildScreenDecoration(),
            child: Form(
              key: _formKey,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Các thành phần trang trí nền.
                  _buildBackgroundGraphics(),

                  // Lời chào.
                  Positioned(
                    top: 164,
                    child: Text('Welcome !', style: TextStyle(color: Colors.black.withOpacity(0.75), fontSize: 40, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ),
                  Positioned(
                    top: 231,
                    child: Text('Have a nice day!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(0.74), fontSize: 13, fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                  ),

                  // Các ô nhập liệu.
                  Positioned(
                    top: 339,
                    child: _buildTextField(controller: nameController, hintText: 'Enter your full name', validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập họ tên' : null),
                  ),
                  Positioned(
                    top: 411,
                    child: _buildTextField(controller: emailController, hintText: 'Enter your email', keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Vui lòng nhập email hợp lệ' : null),
                  ),
                  Positioned(
                    top: 483,
                    child: _buildTextField(controller: passwordController, hintText: 'Enter password', obscureText: true, validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải có ít nhất 6 ký tự' : null),
                  ),
                  Positioned(
                    top: 555,
                    child: _buildTextField(controller: confirmController, hintText: 'Confirm password', obscureText: true, validator: (v) => (v != passwordController.text) ? 'Mật khẩu xác nhận không khớp' : null),
                  ),

                  // Các nút bấm.
                  Positioned(
                    top: 647,
                    child: _buildRegisterButton(),
                  ),
                  Positioned(
                    top: 720,
                    child: _buildLoginRedirectLink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- C. CÁC HÀM HELPER DỰNG CÁC PHẦN NHỎ CỦA UI ---
  // Tách các widget phức tạp ra thành các hàm riêng để hàm build() gọn gàng hơn.

  ShapeDecoration _buildScreenDecoration() {
    return ShapeDecoration(
      gradient: const LinearGradient(
        begin: Alignment(0.50, -0.00),
        end: Alignment(0.50, 1.00),
        colors: [Color(0xFF3EBCFD), Color(0xFF4845D9)],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  Positioned _buildBackgroundGraphics() {
    return Positioned(
      left: -96,
      top: -101,
      child: Container(
        width: 347, height: 347,
        decoration: const ShapeDecoration(
          gradient: LinearGradient(colors: [Color(0xFF58E0AA), Color(0xFF49C8F2)], begin: Alignment(0.50, -0.00), end: Alignment(0.50, 1.00)),
          shape: OvalBorder(),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      width: 325,
      height: 70, // Tăng chiều cao để có không gian cho thông báo lỗi
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.70), fontSize: 13, fontFamily: 'Poppins'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          errorStyle: const TextStyle(height: 0.8), // Giảm khoảng cách của text lỗi
        ),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _register, // Gắn hàm logic
      child: Container(
        width: 325, height: 62,
        decoration: BoxDecoration(color: const Color(0xFF50C2C9), borderRadius: BorderRadius.circular(30)),
        child: const Center(child: Text('Register', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Poppins', fontWeight: FontWeight.w600))),
      ),
    );
  }

  Widget _buildLoginRedirectLink() {
    return TextButton(
      onPressed: _goToLogin, // Gắn hàm logic
      child: RichText(
        text: const TextSpan(
          text: 'Already have an account? ', style: TextStyle(color: Colors.white, fontSize: 14),
          children: <TextSpan>[
            TextSpan(text: 'Sign in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }
}
