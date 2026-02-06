import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();

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
          _experienceController.text =
              profile['experience_years']?.toString() ?? '';
          _hourlyRateController.text = profile['hourly_rate']?.toString() ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки профиля: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_isEditing) return;

    try {
      final profileId = widget.masterId ?? await _authRepo.getCurrentUserId();

      final updates = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instagram_url': _instagramController.text.trim(),
      };

      if (_experienceController.text.isNotEmpty) {
        updates['experience_years'] = int.tryParse(_experienceController.text);
      }

      if (_hourlyRateController.text.isNotEmpty) {
        updates['hourly_rate'] = double.tryParse(_hourlyRateController.text);
      }

      await _authRepo.updateProfile(profileId: profileId, updates: updates);

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Профиль успешно обновлён'),
            backgroundColor: Colors.green,
          ),
        );
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.masterId == null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isOwnProfile ? 'Мой профиль' : 'Профиль мастера',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          if (isOwnProfile && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Редактировать',
            ),
          if (isOwnProfile && _isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: 'Сохранить',
            ),
          if (isOwnProfile && _isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadProfile();
              },
              tooltip: 'Отмена',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
          ? const Center(child: Text('Профиль не найден'))
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Аватар и основная информация
                    _buildAvatarSection(),

                    const SizedBox(height: 24),

                    // Полное имя
                    _buildInfoCard(
                      icon: Icons.person,
                      title: 'Полное имя',
                      controller: _fullNameController,
                      isEditing: _isEditing,
                    ),

                    const SizedBox(height: 12),

                    // Email
                    _buildInfoCard(
                      icon: Icons.email,
                      title: 'Email',
                      value: _profileData!['email'] ?? '',
                      isEditing: false,
                    ),

                    const SizedBox(height: 12),

                    // Роль
                    _buildInfoCard(
                      icon: Icons.work,
                      title: 'Роль',
                      value: _getRoleName(_profileData!['role']),
                      isEditing: false,
                    ),

                    const SizedBox(height: 24),

                    // Профессиональная информация
                    if (_profileData!['role'] == 'master') ...[
                      Text(
                        'Профессиональная информация',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Описание
                      _buildInfoCard(
                        icon: Icons.description,
                        title: 'О себе',
                        controller: _descriptionController,
                        isEditing: _isEditing,
                        maxLines: 4,
                      ),

                      const SizedBox(height: 12),

                      // Instagram
                      _buildInfoCard(
                        icon: Icons.camera_alt,
                        title: 'Instagram',
                        controller: _instagramController,
                        isEditing: _isEditing,
                        prefix: '@',
                      ),

                      const SizedBox(height: 12),

                      // Опыт работы
                      _buildInfoCard(
                        icon: Icons.access_time,
                        title: 'Опыт работы (лет)',
                        controller: _experienceController,
                        isEditing: _isEditing,
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 12),

                      // Стоимость часа
                      _buildInfoCard(
                        icon: Icons.attach_money,
                        title: 'Стоимость часа (₽)',
                        controller: _hourlyRateController,
                        isEditing: _isEditing,
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 24),

                      // Статистика
                      _buildStatsSection(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final avatarUrl = _profileData!['avatar_url'] as String?;
    final fullName = _profileData!['full_name'] ?? 'Пользователь';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Icon(Icons.person, size: 60, color: Colors.blue.shade700)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              fullName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_profileData!['role'] == 'master') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Мастер',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    TextEditingController? controller,
    String? value,
    required bool isEditing,
    int maxLines = 1,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isEditing && controller != null)
                    TextField(
                      controller: controller,
                      maxLines: maxLines,
                      keyboardType: keyboardType,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        prefixText: prefix,
                        hintText: 'Введите $title',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      value ?? controller?.text ?? 'Не указано',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статистика',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.star,
                    value: _profileData!['rating']?.toString() ?? '0.0',
                    label: 'Рейтинг',
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle,
                    value:
                        _profileData!['completed_bookings']?.toString() ?? '0',
                    label: 'Записей',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.attach_money,
                    value: _profileData!['total_revenue']?.toString() ?? '0',
                    label: 'Доход',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'master':
        return 'Мастер';
      case 'client':
        return 'Клиент';
      default:
        return 'Не указано';
    }
  }
}
