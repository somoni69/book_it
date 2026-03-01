import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../role_based_home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final authRepo = AuthRepositoryImpl(Supabase.instance.client);

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  bool _codeSent = false;
  bool _isRegistering = true;
  String _selectedRole = 'client';
  bool _isLoading = false;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Введите email');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();

      if (_isRegistering) {
        if (name.isEmpty) {
          _showError('Введите ваше имя');
          setState(() => _isLoading = false);
          return;
        }
        await authRepo.signUpWithOtp(email, name, _selectedRole);
      } else {
        await authRepo.sendOtp(email);
      }

      if (!mounted) return;
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text("Код отправлен на почту!"),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      _showError("Ошибка: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length < 6) {
      _showError('Введите 6-значный код');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await authRepo.verifyOtp(_emailController.text.trim(), code);

      if (!mounted) return;

      // ИСПРАВЛЕНИЕ: Явно сбрасываем стек и отправляем в Хаб!
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleBasedHome()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError("Неверный код: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип / Иконка
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 64, color: Colors.blue.shade600),
                ),
                const SizedBox(height: 32),

                Text(
                  _codeSent
                      ? "Проверьте почту"
                      : (_isRegistering ? "Создать аккаунт" : "С возвращением"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? "Мы отправили 6-значный код на\n${_emailController.text}"
                      : "Войдите или зарегистрируйтесь,\nчтобы продолжить",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 40),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _codeSent ? _buildCodeStep() : _buildInputStep(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputStep() {
    return Column(
      key: const ValueKey('input_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isRegistering) ...[
          // Кастомный выбор роли
          Row(
            children: [
              Expanded(
                  child:
                      _buildRoleCard('client', 'Клиент', Icons.person_rounded)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildRoleCard(
                      'master', 'Специалист', Icons.work_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField(
              controller: _nameController,
              label: "Ваше имя",
              icon: Icons.badge_rounded,
              keyboardType: TextInputType.name),
          const SizedBox(height: 16),
        ],
        _buildTextField(
            controller: _emailController,
            label: "Email адрес",
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 32),
        _buildPrimaryButton(text: "Получить код", onPressed: _sendCode),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _isRegistering = !_isRegistering;
            _nameController.clear();
          }),
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          child: Text(
              _isRegistering
                  ? "Уже есть аккаунт? Войти"
                  : "Нет аккаунта? Зарегистрироваться",
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      key: const ValueKey('code_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _codeController,
          label: "6-значный код",
          icon: Icons.password_rounded,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          letterSpacing: 8.0,
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(text: "Подтвердить", onPressed: _verify),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _codeSent = false;
            _codeController.clear();
          }),
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
          child: const Text("Изменить email"),
        ),
      ],
    );
  }

  Widget _buildRoleCard(String value, String title, IconData icon) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: _borderRadius,
          border: Border.all(
              color: isSelected ? Colors.blue.shade400 : Colors.grey.shade200,
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                size: 28),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.blue.shade700
                        : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextAlign textAlign = TextAlign.start,
    double letterSpacing = 0.0,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: textAlign,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: letterSpacing),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, letterSpacing: 0),
        prefixIcon: textAlign == TextAlign.start
            ? Icon(icon, color: Colors.blue.shade400)
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: _borderRadius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: _borderRadius,
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: _borderRadius,
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
      ),
    );
  }

  Widget _buildPrimaryButton(
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.blue.shade300,
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(text,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
