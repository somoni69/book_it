import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_it/core/services/calendar_service.dart';
import '../../domain/entities/booking_entity.dart';
import '../bloc/create_booking_bloc.dart';

class CreateBookingScreen extends StatefulWidget {
  final String? preSelectedClientId;
  final String? preSelectedServiceId;

  const CreateBookingScreen({
    super.key,
    this.preSelectedClientId,
    this.preSelectedServiceId,
  });

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _commentController = TextEditingController();
  DateTime? _tempSelectedDate;
  TimeOfDay? _tempSelectedTime;
  bool _addToGoogleCalendar = true;
  bool _hasGoogleAccount = false;

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
    _commentController.addListener(_onCommentChanged);
    _loadGoogleSyncPreference();
  }

  Future<void> _loadGoogleSyncPreference() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final integration = await Supabase.instance.client
        .from('master_integrations')
        .select('google_email')
        .eq('master_id', userId)
        .maybeSingle();
    setState(() {
      _hasGoogleAccount =
          integration != null && integration['google_email'] != null;
      _addToGoogleCalendar = _hasGoogleAccount;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    final text = _commentController.text;
    context.read<CreateBookingBloc>().add(CommentChanged(text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateBookingBloc, CreateBookingState>(
      listener: (context, state) {
        if (state is CreateBookingSuccess) {
          _showSuccessDialog(context, state.bookingId);
        }
        if (state is CreateBookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final canSubmit = state is CreateBookingDataLoaded && state.canSubmit;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: const Text('Новая запись', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.05),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.blue),
                onPressed: () => context.read<CreateBookingBloc>().add(ResetForm()),
                tooltip: 'Очистить форму',
              ),
            ],
          ),
          body: _buildBody(state),
          bottomNavigationBar: (state is CreateBookingDataLoaded) 
              ? _buildStickySubmitButton(state, canSubmit) 
              : null,
        );
      },
    );
  }

  Widget _buildBody(CreateBookingState state) {
    if (state is CreateBookingInitial || state is CreateBookingLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    if (state is CreateBookingDataLoaded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildClientSection(state),
            const SizedBox(height: 16),
            _buildServiceSection(state),
            const SizedBox(height: 16),
            _buildDateTimeSection(state),
            const SizedBox(height: 16),
            _buildCommentSection(state),
            const SizedBox(height: 16),
            if (state.canSubmit) _buildPreviewSection(state),
            const SizedBox(height: 24), // Отступ для липкой кнопки
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Ошибка загрузки данных', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // --- УНИВЕРСАЛЬНАЯ КАРТОЧКА ---
  Widget _buildPremiumCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
      ),
      child: child,
    );
  }

  // --- ЗАГОЛОВОК СЕКЦИИ ---
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildClientSection(CreateBookingDataLoaded state) {
    return _buildPremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Клиент', Icons.person_rounded, Colors.blue.shade600),
          Divider(height: 1, color: Colors.grey.shade100),
          
          if (state.selectedClientId != null)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(state.selectedClientName!, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('ID: ${state.selectedClientId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              trailing: IconButton(
                icon: Icon(Icons.cancel_rounded, color: Colors.grey.shade400),
                onPressed: () => context.read<CreateBookingBloc>().add(ClientSelected('', '')),
              ),
            )
          else ...[
            if (state.clients.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Нет доступных клиентов', style: TextStyle(color: Colors.grey.shade500)),
              )
            else
              ...state.clients.map((client) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.read<CreateBookingBloc>().add(
                        ClientSelected(client['id'] as String, client['name'] as String),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blue.shade50,
                          child: Text((client['name'] as String)[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(client['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (client['phone'] != null)
                                Text(client['phone'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              )),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceSection(CreateBookingDataLoaded state) {
    return _buildPremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Услуга', Icons.content_cut_rounded, Colors.purple.shade500),
          Divider(height: 1, color: Colors.grey.shade100),
          
          if (state.selectedServiceId != null)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(state.selectedServiceName!, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${state.selectedServiceDuration} мин • ${state.selectedServicePrice} с.',
                style: TextStyle(color: Colors.purple.shade600, fontWeight: FontWeight.w500),
              ),
              trailing: IconButton(
                icon: Icon(Icons.cancel_rounded, color: Colors.grey.shade400),
                onPressed: () => context.read<CreateBookingBloc>().add(ServiceSelected('', '', 0, 0)),
              ),
            )
          else ...[
            if (state.services.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Нет доступных услуг', style: TextStyle(color: Colors.grey.shade500)),
              )
            else
              ...state.services.map((service) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.read<CreateBookingBloc>().add(
                        ServiceSelected(
                          service['id'] as String,
                          service['name'] as String,
                          service['duration'] as int,
                          service['price'] as int,
                        ),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(service['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text('${service['duration']} мин • ${service['price']} с.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              )),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimeSection(CreateBookingDataLoaded state) {
    return _buildPremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Дата и время', Icons.calendar_month_rounded, Colors.orange.shade500),
          Divider(height: 1, color: Colors.grey.shade100),
          
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectDate(context, state),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Дата', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            state.selectedDate != null
                                ? DateFormat('EEEE, d MMMM y', 'ru_RU').format(state.selectedDate!)
                                : 'Выберите дату',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: state.selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                              color: state.selectedDate != null ? Colors.black87 : Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_calendar_rounded, color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ),
            ),
          ),
          
          if (state.selectedDate != null) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _selectTime(context, state),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Время', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              state.selectedTime != null
                                  ? '${state.selectedTime!.hour.toString().padLeft(2, '0')}:${state.selectedTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Выберите время',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: state.selectedTime != null ? FontWeight.w600 : FontWeight.normal,
                                color: state.selectedTime != null ? Colors.black87 : Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.access_time_rounded, color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
          
          if (state.busySlots.isNotEmpty && state.selectedDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Занято: ${state.busySlots.map((t) => DateFormat.Hm().format(t)).join(', ')}',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, CreateBookingDataLoaded state) async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 30));
    final lastDate = now.add(const Duration(days: 365));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: state.selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      _tempSelectedDate = pickedDate;
      if (state.selectedTime != null) {
        context.read<CreateBookingBloc>().add(DateTimeSelected(pickedDate, state.selectedTime!));
      } else if (mounted) {
        _selectTime(context, state);
      }
    }
  }

  Future<void> _selectTime(BuildContext context, CreateBookingDataLoaded state) async {
    final initialTime = state.selectedTime ?? const TimeOfDay(hour: 9, minute: 0);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade600),
          ),
          child: Localizations.override(
            context: context,
            locale: const Locale('ru', 'RU'),
            child: child,
          ),
        );
      },
    );

    if (pickedTime != null) {
      _tempSelectedTime = pickedTime;
      final dateToUse = state.selectedDate ?? _tempSelectedDate ?? DateTime.now();
      context.read<CreateBookingBloc>().add(DateTimeSelected(dateToUse, pickedTime));
    }
  }

  Widget _buildCommentSection(CreateBookingDataLoaded state) {
    return _buildPremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Дополнительно', Icons.comment_rounded, Colors.teal.shade500),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Оставьте комментарий к записи...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade400),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Theme(
            data: ThemeData(unselectedWidgetColor: Colors.grey.shade400),
            child: CheckboxListTile(
              title: const Text('Синхронизация', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(
                _hasGoogleAccount ? 'Добавить в Google Календарь' : 'Google аккаунт не подключен',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              value: _addToGoogleCalendar,
              activeColor: Colors.blue.shade600,
              onChanged: _hasGoogleAccount ? (value) => setState(() => _addToGoogleCalendar = value!) : null,
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.sync_rounded, color: Colors.blue.shade600, size: 20),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(CreateBookingDataLoaded state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.5)]),
        borderRadius: _borderRadius,
        border: Border.all(color: Colors.blue.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text('Готово к созданию', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900)),
            ],
          ),
          const SizedBox(height: 16),
          _buildPreviewRow(Icons.person_outline_rounded, state.selectedClientName!),
          const SizedBox(height: 12),
          _buildPreviewRow(Icons.content_cut_rounded, state.selectedServiceName!),
          const SizedBox(height: 12),
          _buildPreviewRow(
            Icons.access_time_rounded,
            '${DateFormat('dd.MM.yyyy').format(state.selectedDate!)} • '
            '${state.selectedTime!.hour.toString().padLeft(2, '0')}:${state.selectedTime!.minute.toString().padLeft(2, '0')} - '
            '${state.calculatedEndTime != null ? DateFormat.Hm().format(state.calculatedEndTime!) : ''}',
          ),
          const SizedBox(height: 12),
          _buildPreviewRow(Icons.monetization_on_outlined, '${state.selectedServicePrice} сомони', isBold: true),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, String text, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.blue.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickySubmitButton(CreateBookingDataLoaded state, bool canSubmit) {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 22),
            label: const Text('Создать запись', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              disabledBackgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey.shade500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: canSubmit ? 4 : 0,
              shadowColor: Colors.green.withOpacity(0.4),
            ),
            onPressed: canSubmit
                ? () => context.read<CreateBookingBloc>().add(SubmitBooking(addToGoogleCalendar: _addToGoogleCalendar))
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog(BuildContext context, String bookingId) async {
    final shouldAddToCalendar = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.check_circle, size: 48, color: Colors.green.shade600),
                ),
                const SizedBox(height: 16),
                const Text('Запись создана!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Хотите добавить это событие в локальный календарь устройства?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Позже', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldAddToCalendar && context.mounted) {
      final fakeBooking = BookingEntity(
        id: bookingId,
        masterId: 'master_id',
        clientId: 'client_id',
        startTime: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
        status: BookingStatus.confirmed,
        clientName: 'Клиент',
        masterName: 'Мастер',
      );

      final description = CalendarService.instance.buildBookingDescription(
        serviceName: 'Услуга',
        masterName: 'Мастер',
        clientName: 'Клиент',
      );

      final success = await CalendarService.instance.addBookingToCalendar(
        title: 'Запись: Услуга',
        description: description,
        startDate: fakeBooking.startTime,
        endDate: fakeBooking.endTime,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Успешно добавлено в календарь! 📅'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}