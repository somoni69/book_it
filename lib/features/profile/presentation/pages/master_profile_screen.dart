import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart'; // Добавлен импорт
import '../../../auth/data/repositories/auth_repository_impl.dart';

class MasterProfileScreen extends StatefulWidget {
  final String? masterId; // Если null - текущий пользователь

  const MasterProfileScreen({super.key, this.masterId});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  late final AuthRepositoryImpl _authRepo;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUploadingAvatar = false; // Флаг для загрузки фото

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepositoryImpl(Supabase.instance.client);
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _descriptionController.dispose();
    _instagramController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoading = true);

      final profileId = widget.masterId ?? await _authRepo.getCurrentUserId();
      final profile = await _authRepo.getProfile(profileId);

      if (mounted) {
        setState(() {
          _profileData = profile;
          _fullNameController.text = profile['full_name'] ?? '';
          _descriptionController.text = profile['description'] ?? '';
          _instagramController.text = profile['instagram_url'] ?? '';
          _experienceController.text = profile['experience_years']?.toString() ?? '';
          _hourlyRateController.text = profile['hourly_rate']?.toString() ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки профиля: $e'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // --- НОВЫЙ МЕТОД: ВЫБОР И ЗАГРУЗКА ФОТО ---
  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      // Выбираем фото из галереи, сразу сжимаем, чтобы не грузить 10МБ файлы
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return; // Пользователь отменил выбор

      setState(() => _isUploadingAvatar = true);

      final file = File(pickedFile.path);
      final newAvatarUrl = await _authRepo.uploadAvatar(XFile(pickedFile.path));
  
      if (mounted) {
        setState(() {
          _profileData!['avatar_url'] = newAvatarUrl;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Фото успешно обновлено'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки фото: $e'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_isEditing) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранение...'), duration: Duration(seconds: 1)));

      final profileId = widget.masterId ?? await _authRepo.getCurrentUserId();

      final updates = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instagram_url': _instagramController.text.trim(),
      };

      updates['experience_years'] = _experienceController.text.trim().isNotEmpty 
          ? int.tryParse(_experienceController.text.trim()) 
          : null;
          
      updates['hourly_rate'] = _hourlyRateController.text.trim().isNotEmpty 
          ? double.tryParse(_hourlyRateController.text.trim()) 
          : null;

      await _authRepo.updateProfile(profileId: profileId, updates: updates);

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✅ Профиль успешно обновлён'), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating),
        );
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.masterId == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(isOwnProfile ? 'Мой профиль' : 'Профиль специалиста', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        actions: [
          if (isOwnProfile && !_isEditing && !_isLoading)
            IconButton(
              icon: Icon(Icons.edit_rounded, color: Colors.blue.shade600),
              tooltip: 'Редактировать',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _profileData == null
              ? _buildEmptyState()
              : _buildContent(),
      bottomNavigationBar: _isEditing ? _buildStickyActionBar() : null,
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: Colors.blue.shade600,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16).copyWith(bottom: _isEditing ? 100 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Базовая информация'),
            _buildInfoCard(icon: Icons.person_rounded, title: 'Полное имя', controller: _fullNameController, value: _profileData!['full_name']),
            const SizedBox(height: 12),
            _buildInfoCard(icon: Icons.email_rounded, title: 'Email', value: _profileData!['email'] ?? '', readOnly: true),
            
            if (_profileData!['role'] == 'master') ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Профессиональная информация'),
              _buildInfoCard(icon: Icons.info_outline_rounded, title: 'О себе', controller: _descriptionController, value: _profileData!['description'], maxLines: 4),
              const SizedBox(height: 12),
              _buildInfoCard(icon: Icons.camera_alt_rounded, title: 'Instagram', controller: _instagramController, value: _profileData!['instagram_url'], prefix: '@ '),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildInfoCard(icon: Icons.workspace_premium_rounded, title: 'Опыт (лет)', controller: _experienceController, value: _profileData!['experience_years']?.toString(), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfoCard(icon: Icons.payments_rounded, title: 'Ставка (в час)', controller: _hourlyRateController, value: _profileData!['hourly_rate']?.toString(), keyboardType: TextInputType.number, suffix: ' с.')),
                ],
              ),
              const SizedBox(height: 24),
              if (!_isEditing) _buildStatsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
    );
  }

  Widget _buildHeaderSection() {
    final avatarUrl = _profileData!['avatar_url'] as String?;
    final fullName = _profileData!['full_name'] ?? 'Пользователь';
    final isMaster = _profileData!['role'] == 'master';

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 24, left: 16, right: 16),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.blue.shade50,
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty) 
                                ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue.shade700)) 
                                : null,
                          ),
                          // Полупрозрачный слой загрузки поверх фото
                          if (_isUploadingAvatar)
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                    // Кнопка загрузки аватара в режиме редактирования
                    if (_isEditing && !_isUploadingAvatar)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.shade600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isMaster ? Colors.amber.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: isMaster ? Colors.amber.shade200 : Colors.grey.shade300)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isMaster ? Icons.star_rounded : Icons.person_rounded, size: 16, color: isMaster ? Colors.amber.shade700 : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(isMaster ? 'Топ-Мастер' : 'Клиент', style: TextStyle(color: isMaster ? Colors.amber.shade800 : Colors.grey.shade700, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    TextEditingController? controller,
    String? value,
    bool readOnly = false,
    int maxLines = 1,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
  }) {
    final showEditField = _isEditing && !readOnly;
    final displayValue = value == null || value.isEmpty ? 'Не указано' : value;

    return Container(
      decoration: BoxDecoration(
        color: showEditField ? Colors.blue.shade50.withOpacity(0.3) : Colors.white,
        borderRadius: _borderRadius,
        boxShadow: showEditField ? [] : _cardShadow,
        border: Border.all(color: showEditField ? Colors.blue.shade200 : Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: showEditField ? Colors.blue.shade600 : Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 13, color: showEditField ? Colors.blue.shade700 : Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          if (showEditField)
            TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: Colors.white,
                prefixText: prefix,
                suffixText: suffix,
                prefixStyle: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 16),
                suffixStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16),
                hintText: 'Введите данные',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade100)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
              ),
            )
          else
            Text(
              displayValue,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: displayValue == 'Не указано' ? Colors.grey.shade400 : Colors.black87),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Статистика мастера', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(icon: Icons.star_rounded, value: _profileData!['rating']?.toString() ?? '0.0', label: 'Рейтинг', color: Colors.amber.shade500),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildStatItem(icon: Icons.task_alt_rounded, value: _profileData!['completed_bookings']?.toString() ?? '0', label: 'Записей', color: Colors.green.shade500),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildStatItem(icon: Icons.account_balance_wallet_rounded, value: _profileData!['total_revenue']?.toString() ?? '0', label: 'Доход', color: Colors.blue.shade500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String value, required String label, required Color color}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStickyActionBar() {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _isEditing = false);
                    _loadProfile();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Отмена', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Сохранить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: Colors.blue.withOpacity(0.4),
                  ),
                  onPressed: _saveProfile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
            const SizedBox(height: 24),
            Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
            const SizedBox(height: 12),
            Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
            const SizedBox(height: 12),
            Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Профиль не найден', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}