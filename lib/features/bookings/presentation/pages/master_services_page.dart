import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../domain/entities/service_entity.dart';

class MasterServicesPage extends StatefulWidget {
  const MasterServicesPage({super.key});

  @override
  State<MasterServicesPage> createState() => _MasterServicesPageState();
}

class _MasterServicesPageState extends State<MasterServicesPage> {
  final _supabase = Supabase.instance.client;
  late final ServiceRepositoryImpl _repository;

  bool _isLoading = true;
  List<ServiceEntity> _services = [];
  String? _masterOrganizationId; // КРИТИЧНО для сохранения в БД

  // Контроллеры для формы
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _capacityController = TextEditingController();

  // Тип услуги в шторке
  String _selectedBookingType = 'time_slot';

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _repository = ServiceRepositoryImpl(_supabase);
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser!.id;

      // 1. Получаем Organization ID мастера
      final profileResponse = await _supabase
          .from('profiles')
          .select('organization_id')
          .eq('id', userId)
          .single();
      _masterOrganizationId = profileResponse['organization_id'] as String?;

      // 2. Грузим услуги
      await _fetchServices();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ошибка загрузки данных: $e');
      }
    }
  }

  Future<void> _fetchServices() async {
    final userId = _supabase.auth.currentUser!.id;
    final services = await _repository.getServicesByMaster(userId);
    if (mounted) {
      setState(() {
        _services = services;
        _isLoading = false;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating),
    );
  }

  // --- ШТОРКА СОЗДАНИЯ/РЕДАКТИРОВАНИЯ ---
  Future<void> _showServiceBottomSheet({ServiceEntity? service}) async {
    // Предзаполняем поля
    _titleController.text = service?.title ?? '';
    _priceController.text = service?.price.toStringAsFixed(0) ?? '';
    _durationController.text = service?.durationMin.toString() ?? '60';
    _capacityController.text = service?.capacity.toString() ?? '1';
    _selectedBookingType = service?.bookingType ?? 'time_slot';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(
                    service == null ? "Новая услуга" : "Редактирование",
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 24),

                  // ПЕРЕКЛЮЧАТЕЛЬ ТИПА УСЛУГИ
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(
                                () => _selectedBookingType = 'time_slot'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedBookingType == 'time_slot'
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedBookingType == 'time_slot'
                                    ? [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4)
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.content_cut_rounded,
                                      size: 18,
                                      color: _selectedBookingType == 'time_slot'
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Услуга',
                                    style: TextStyle(
                                        fontWeight:
                                            _selectedBookingType == 'time_slot'
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                        color:
                                            _selectedBookingType == 'time_slot'
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(
                                () => _selectedBookingType = 'daily'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedBookingType == 'daily'
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _selectedBookingType == 'daily'
                                    ? [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4)
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bed_rounded,
                                      size: 18,
                                      color: _selectedBookingType == 'daily'
                                          ? Colors.indigo.shade700
                                          : Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Жильё',
                                    style: TextStyle(
                                        fontWeight:
                                            _selectedBookingType == 'daily'
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                        color: _selectedBookingType == 'daily'
                                            ? Colors.indigo.shade700
                                            : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildInputField(
                      controller: _titleController,
                      label: _selectedBookingType == 'daily'
                          ? "Название (напр. Койка в хостеле)"
                          : "Название (напр. Стрижка)",
                      icon: Icons.title_rounded),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                            controller: _priceController,
                            label: _selectedBookingType == 'daily'
                                ? "Цена за ночь"
                                : "Цена",
                            icon: Icons.payments_outlined,
                            keyboardType: TextInputType.number,
                            suffixText: "с."),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        // ДИНАМИЧЕСКОЕ ПОЛЕ: Время или Вместимость
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _selectedBookingType == 'daily'
                              ? _buildInputField(
                                  key: const ValueKey('capacity'),
                                  controller: _capacityController,
                                  label: "Мест",
                                  icon: Icons.group_rounded,
                                  keyboardType: TextInputType.number,
                                  suffixText: "чел.")
                              : _buildInputField(
                                  key: const ValueKey('duration'),
                                  controller: _durationController,
                                  label: "Время",
                                  icon: Icons.schedule_rounded,
                                  keyboardType: TextInputType.number,
                                  suffixText: "мин."),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedBookingType == 'daily'
                            ? Colors.indigo.shade600
                            : Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => _saveService(service),
                      child: const Text("Сохранить",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveService(ServiceEntity? existingService) async {
    final title = _titleController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    final duration = int.tryParse(_durationController.text) ?? 60;
    final capacity = int.tryParse(_capacityController.text) ?? 1;

    final isDaily = _selectedBookingType == 'daily';

    if (title.isEmpty) {
      _showError('Введите название услуги');
      return;
    }
    if (price <= 0) {
      _showError('Цена должна быть больше нуля');
      return;
    }
    // Для обычных услуг проверяем время, для посуточных - вместимость
    if (!isDaily && duration <= 0) {
      _showError('Укажите длительность услуги');
      return;
    }
    if (isDaily && capacity <= 0) {
      _showError('Укажите количество мест');
      return;
    }

    Navigator.pop(context); // Закрываем шторку
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      if (existingService == null) {
        // ДОБАВЛЕНИЕ
        await _supabase.from('services').insert({
          'master_id': userId,
          'organization_id': _masterOrganizationId,
          'title': title,
          'duration_min':
              isDaily ? 1440 : duration, // 1440 мин = 24 часа для daily
          'price': price,
          'currency': 'TJS',
          'is_active': true,
          'booking_type': _selectedBookingType,
          'capacity': capacity,
        });
      } else {
        // ОБНОВЛЕНИЕ
        await _supabase.from('services').update({
          'title': title,
          'duration_min': isDaily ? 1440 : duration,
          'price': price,
          'booking_type': _selectedBookingType,
          'capacity': capacity,
        }).eq('id', existingService.id);
      }

      await _fetchServices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(existingService == null
                  ? 'Услуга добавлена'
                  : 'Услуга обновлена'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ошибка сохранения: $e');
      }
    }
  }

  Future<void> _deleteService(ServiceEntity service) async {
    setState(() => _isLoading = true);
    try {
      await _repository.deleteService(service.id);
      await _fetchServices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Услуга удалена'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ошибка удаления: $e');
      }
    }
  }

  Widget _buildInputField(
      {Key? key,
      required TextEditingController controller,
      required String label,
      required IconData icon,
      TextInputType? keyboardType,
      String? suffixText}) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.blue.shade400, size: 20),
        suffixText: suffixText,
        suffixStyle:
            TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Мой прайс-лист',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: _isLoading ? _buildSkeleton() : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showServiceBottomSheet(),
        label: const Text("Добавить услугу",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildContent() {
    if (_services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 56, color: Colors.blue.shade300),
            ),
            const SizedBox(height: 24),
            const Text("Нет добавленных услуг",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text(
                "Добавьте свои услуги и цены,\nчтобы клиенты могли записаться.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.grey.shade600, height: 1.4)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchServices,
      color: Colors.blue.shade600,
      child: ListView.separated(
        padding: const EdgeInsets.all(16).copyWith(bottom: 100),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final service = _services[index];
          return _buildDismissibleCard(service);
        },
      ),
    );
  }

  Widget _buildDismissibleCard(ServiceEntity service) {
    return Dismissible(
      key: Key(service.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
            color: Colors.red.shade400, borderRadius: _borderRadius),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('Удалить',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Удалить услугу?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
                'Вы уверены, что хотите удалить "${service.title}"? Это действие нельзя отменить.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Отмена',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteService(service),
      child: _buildServiceCard(service),
    );
  }

  Widget _buildServiceCard(ServiceEntity s) {
    final isDaily = s.bookingType == 'daily';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showServiceBottomSheet(service: s),
          borderRadius: _borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color:
                          isDaily ? Colors.indigo.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                      isDaily ? Icons.bed_rounded : Icons.content_cut_rounded,
                      color: isDaily
                          ? Colors.indigo.shade500
                          : Colors.blue.shade500,
                      size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                              isDaily
                                  ? Icons.group_rounded
                                  : Icons.schedule_rounded,
                              size: 14,
                              color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                              isDaily
                                  ? "${s.capacity} мест"
                                  : "${s.durationMin} мин",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: isDaily
                                    ? Colors.indigo.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(isDaily ? 'Посуточно' : 'Почасовая',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isDaily
                                        ? Colors.indigo.shade600
                                        : Colors.blue.shade600,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        "${s.price.toStringAsFixed(0)} с.",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.edit_rounded,
                        size: 16, color: Colors.grey.shade300),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
              height: 86,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: _borderRadius));
        },
      ),
    );
  }
}
