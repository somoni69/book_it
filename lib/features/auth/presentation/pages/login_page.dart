import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository_impl.dart';

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

  bool _codeSent = false; // Отправлен ли код?
  bool _isRegistering = true; // По умолчанию регистрация
  String _selectedRole = 'client'; // Роль
  bool _isLoading = false;

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final name = _nameController.text.trim();

      if (_isRegistering) {
        // РЕГИСТРАЦИЯ: Шлем Имя и Роль
        await authRepo.signUpWithOtp(email, name, _selectedRole);
      } else {
        // ВХОД: Просто шлем код
        await authRepo.sendOtp(email);
      }

      setState(() => _codeSent = true); // Показываем поле для кода
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Код отправлен на почту!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _isLoading = true);
    try {
      await authRepo.verifyOtp(
        _emailController.text.trim(),
        _codeController.text.trim(),
      );
      // Успех -> Main сам перекинет
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Неверный код: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_read, size: 80),
              const SizedBox(height: 24),
              const Text(
                "Вход по почте",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // ШАГ 1: Ввод данных
              if (!_codeSent) ...[
                if (_isRegistering) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Ваше имя",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Выбор Роли
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: "Кто вы?",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'client',
                        child: Text("Я Клиент"),
                      ),
                      DropdownMenuItem(
                        value: 'master',
                        child: Text("Я Мастер (Бизнес)"),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Получить код"),
                ),

                TextButton(
                  onPressed: () =>
                      setState(() => _isRegistering = !_isRegistering),
                  child: Text(
                    _isRegistering
                        ? "Уже есть аккаунт? Войти"
                        : "Нет аккаунта? Регистрация",
                  ),
                ),
              ]
              // ШАГ 2: Ввод Кода
              else ...[
                Text(
                  "Введите код из письма для ${_emailController.text}",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "6-значный код",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Подтвердить"),
                ),
                TextButton(
                  onPressed: () => setState(() => _codeSent = false),
                  child: const Text("Назад"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
