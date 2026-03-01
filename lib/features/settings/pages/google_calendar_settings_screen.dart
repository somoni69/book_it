import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_it/core/services/google_calendar_api_service.dart';

class GoogleCalendarSettingsScreen extends StatefulWidget {
  final String masterId;
  const GoogleCalendarSettingsScreen({super.key, required this.masterId});

  @override
  State<GoogleCalendarSettingsScreen> createState() =>
      _GoogleCalendarSettingsScreenState();
}

class _GoogleCalendarSettingsScreenState
    extends State<GoogleCalendarSettingsScreen> {
  GoogleSignInAccount? _googleAccount;
  Map<String, dynamic>? _savedInfo;
  bool _isLoading = true;

  // --- Единый стиль ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);

    _savedInfo = await GoogleCalendarApiService.getGoogleAccountFromSupabase(
        widget.masterId);
    _googleAccount = await GoogleCalendarApiService.getCurrentUser();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    final account = await GoogleCalendarApiService.signIn();
    
    if (account != null) {
      setState(() => _googleAccount = account);
      await GoogleCalendarApiService.saveGoogleAccountToSupabase(
          widget.masterId, account);
      await _loadStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Google аккаунт успешно подключён'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    await GoogleCalendarApiService.signOut();
    
    await Supabase.instance.client
        .from('master_integrations')
        .update({'google_email': null, 'google_display_name': null})
        .eq('master_id', widget.masterId);

    await _loadStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Google аккаунт отключён'),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _googleAccount != null || _savedInfo?['google_email'] != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Google Календарь', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: _borderRadius,
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sync_rounded, size: 32, color: Colors.blue.shade700),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Подключите Google Календарь, чтобы автоматически синхронизировать ваши записи и избежать накладок.',
                            style: TextStyle(fontSize: 14, color: Colors.blue.shade900, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Карточка статуса
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: _borderRadius,
                      boxShadow: _cardShadow,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: isConnected ? Colors.green.shade600 : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Статус синхронизации', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    isConnected ? 'Подключён' : 'Не подключён',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isConnected ? Colors.green.shade700 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        if (isConnected) ...[
                          const SizedBox(height: 20),
                          Divider(color: Colors.grey.shade200),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 20, color: Colors.grey.shade600),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _googleAccount?.email ?? _savedInfo?['google_email'] ?? '',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout, size: 20),
                              label: const Text('Отключить аккаунт', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(color: Colors.red.shade200),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _handleSignOut,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.login, size: 20),
                              label: const Text('Войти через Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _handleSignIn,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('Как это работает?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  _buildFeatureRow('При создании записи событие автоматически добавляется в ваш календарь'),
                  const SizedBox(height: 12),
                  _buildFeatureRow('При отмене записи событие удаляется из календаря'),
                  const SizedBox(height: 12),
                  _buildFeatureRow('Вы можете в любой момент отключить синхронизацию'),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
          child: Icon(Icons.check, size: 14, color: Colors.green.shade700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4)),
        ),
      ],
    );
  }
}