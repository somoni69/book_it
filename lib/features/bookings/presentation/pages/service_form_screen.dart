import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/service_entity.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../../../core/widgets/responsive_layout.dart';

class ServiceFormScreen extends StatefulWidget {
  final ServiceEntity? service;

  const ServiceFormScreen({super.key, this.service});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ServiceRepositoryImpl(Supabase.instance.client);

  bool _isLoading = false;
  String? _error;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _capacityController;

  String _bookingType = 'time_slot';

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.service?.title ?? '');
    _descriptionController = TextEditingController(text: '');
    _priceController =
        TextEditingController(text: widget.service?.price.toString() ?? '');
    _durationController = TextEditingController(
        text: widget.service?.durationMin.toString() ?? '60');
    _bookingType = widget.service?.bookingType ?? 'time_slot';
    _capacityController =
        TextEditingController(text: widget.service?.capacity.toString() ?? '1');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final masterId = Supabase.instance.client.auth.currentUser!.id;

      // Create ServiceEntity with all fields
      final service = ServiceEntity(
        id: widget.service?.id ?? '',
        masterId: masterId,
        title: _nameController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        durationMin: _bookingType == 'time_slot'
            ? (int.tryParse(_durationController.text.trim()) ?? 60)
            : 1440, // 24 hours for daily bookings
        bookingType: _bookingType,
        capacity: _bookingType == 'daily'
            ? (int.tryParse(_capacityController.text.trim()) ?? 1)
            : 1,
      );

      if (widget.service == null) {
        await _repository.createService(service);
      } else {
        await _repository.updateService(service);
      }

      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackbar();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Успешно сохранено!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.service == null ? 'Новая позиция' : 'Редактирование',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: ResponsiveLayout(
        mobile: _buildFormContainer(maxWidth: double.infinity),
        tablet: _buildFormContainer(maxWidth: 600),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildFormContainer({required double maxWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          // Добавил скролл для мобилок
          padding: const EdgeInsets.all(16),
          child: _buildFormContent(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Card(
          margin: const EdgeInsets.all(24),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildFormContent(isDesktop: true),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent({bool isDesktop = false}) {
    final isDaily = _bookingType == 'daily';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                    child: _buildTypeButton(
                        'Услуга', 'time_slot', Icons.content_cut_rounded)),
                Expanded(
                    child:
                        _buildTypeButton('Жильё', 'daily', Icons.bed_rounded)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                      controller: _nameController,
                      label: 'Название',
                      icon: Icons.title_rounded,
                      validator: (v) => v!.isEmpty ? 'Введите название' : null),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildTextField(
                      controller: _priceController,
                      label: isDaily ? 'Цена за ночь' : 'Цена услуги',
                      icon: Icons.payments_rounded,
                      keyboardType: TextInputType.number,
                      suffix: ' с.',
                      validator: (v) => v!.isEmpty ? 'Укажите цену' : null),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                      controller: _descriptionController,
                      label: 'Описание',
                      icon: Icons.description_rounded,
                      maxLines: 3),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isDaily
                        ? _buildTextField(
                            key: const ValueKey('capacity'),
                            controller: _capacityController,
                            label: 'Кол-во мест (коек)',
                            icon: Icons.group_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v!.isEmpty ? 'Укажите кол-во' : null)
                        : _buildTextField(
                            key: const ValueKey('duration'),
                            controller: _durationController,
                            label: 'Длительность',
                            icon: Icons.access_time_rounded,
                            keyboardType: TextInputType.number,
                            suffix: ' мин',
                            validator: (v) =>
                                v!.isEmpty ? 'Укажите время' : null),
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildTextField(
                controller: _nameController,
                label: 'Название',
                icon: Icons.title_rounded,
                validator: (v) => v!.isEmpty ? 'Введите название' : null),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _descriptionController,
                label: 'Описание',
                icon: Icons.description_rounded,
                maxLines: 3),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment
                  .start, // Добавил выравнивание по верху для мобилок
              children: [
                Expanded(
                  child: _buildTextField(
                      controller: _priceController,
                      label: isDaily ? 'Цена за ночь' : 'Цена услуги',
                      icon: Icons.payments_rounded,
                      keyboardType: TextInputType.number,
                      suffix: ' с.',
                      validator: (v) => v!.isEmpty ? 'Укажите цену' : null),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isDaily
                        ? _buildTextField(
                            key: const ValueKey('capacity'),
                            controller: _capacityController,
                            label: 'Мест',
                            icon: Icons.group_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v!.isEmpty ? 'Укажите кол-во' : null)
                        : _buildTextField(
                            key: const ValueKey('duration'),
                            controller: _durationController,
                            label: 'Время',
                            icon: Icons.access_time_rounded,
                            keyboardType: TextInputType.number,
                            suffix: ' мин',
                            validator: (v) =>
                                v!.isEmpty ? 'Укажите время' : null),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200)),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: TextStyle(color: Colors.red.shade700))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveService,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Сохранить',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String title, String type, IconData icon) {
    final isSelected = _bookingType == type;
    return GestureDetector(
      onTap: () => setState(() => _bookingType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color:
                    isSelected ? Colors.blue.shade700 : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color:
                      isSelected ? Colors.blue.shade700 : Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade300)),
      ),
    );
  }
}
