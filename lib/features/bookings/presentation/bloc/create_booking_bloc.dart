import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:equatable/equatable.dart';

part 'create_booking_event.dart';
part 'create_booking_state.dart';

class CreateBookingBloc extends Bloc<CreateBookingEvent, CreateBookingState> {
  final SupabaseClient supabase;
  final String masterId;

  CreateBookingBloc({
    required this.supabase,
    required this.masterId,
  }) : super(CreateBookingInitial()) {
    on<LoadInitialData>(_onLoadInitialData);
    on<ClientSelected>(_onClientSelected);
    on<ServiceSelected>(_onServiceSelected);
    on<DateTimeSelected>(_onDateTimeSelected);
    on<CommentChanged>(_onCommentChanged);
    on<SubmitBooking>(_onSubmitBooking);
    on<ResetForm>(_onResetForm);
  }

  Future<void> _onLoadInitialData(
    LoadInitialData event,
    Emitter<CreateBookingState> emit,
  ) async {
    emit(CreateBookingLoading());

    try {
      // Загружаем клиентов (профили с ролью 'client')
      final clientsResponse = await supabase
          .from('profiles')
          .select('id, full_name, phone_number')
          .eq('role', 'client')
          .order('full_name');

      // Загружаем услуги текущего мастера
      final servicesResponse = await supabase
          .from('services')
          .select('id, name, duration_minutes, price_som')
          .eq('master_id', masterId)
          .eq('is_active', true)
          .order('name');

      // Преобразуем в удобный формат
      final clients = (clientsResponse as List)
          .map((c) => {
                'id': c['id'] as String,
                'name': c['full_name'] as String? ?? 'Без имени',
                'phone': c['phone_number'] as String?,
              })
          .toList();

      final services = (servicesResponse as List)
          .map((s) => {
                'id': s['id'] as String,
                'name': s['name'] as String,
                'duration': s['duration_minutes'] as int,
                'price': s['price_som'] as int,
              })
          .toList();

      emit(CreateBookingDataLoaded(
        clients: clients,
        services: services,
      ));
    } catch (e) {
      emit(CreateBookingError('Ошибка загрузки данных: $e'));
    }
  }

  void _onClientSelected(
    ClientSelected event,
    Emitter<CreateBookingState> emit,
  ) {
    if (state is CreateBookingDataLoaded) {
      final currentState = state as CreateBookingDataLoaded;
      emit(currentState.copyWith(
        selectedClientId: event.clientId,
        selectedClientName: event.clientName,
      ));
    }
  }

  void _onServiceSelected(
    ServiceSelected event,
    Emitter<CreateBookingState> emit,
  ) {
    if (state is CreateBookingDataLoaded) {
      final currentState = state as CreateBookingDataLoaded;
      emit(currentState.copyWith(
        selectedServiceId: event.serviceId,
        selectedServiceName: event.serviceName,
        selectedServiceDuration: event.duration,
        selectedServicePrice: event.price,
      ));
    }
  }

  void _onDateTimeSelected(
    DateTimeSelected event,
    Emitter<CreateBookingState> emit,
  ) async {
    if (state is CreateBookingDataLoaded) {
      final currentState = state as CreateBookingDataLoaded;

      // Загружаем занятые слоты для выбранной даты
      List<DateTime> busySlots = [];
      try {
        final startOfDay = DateTime(event.selectedDate.year,
            event.selectedDate.month, event.selectedDate.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final bookings = await supabase
            .from('bookings')
            .select('start_time, end_time')
            .eq('master_id', masterId)
            .gte('start_time', startOfDay.toIso8601String())
            .lt('start_time', endOfDay.toIso8601String())
            .neq('status', 'cancelled');

        for (final booking in bookings as List) {
          busySlots.add(DateTime.parse(booking['start_time'] as String));
        }
      } catch (e) {
        // Игнорируем ошибку загрузки занятых слотов
      }

      emit(currentState.copyWith(
        selectedDate: event.selectedDate,
        selectedTime: event.selectedTime,
        busySlots: busySlots,
      ));
    }
  }

  void _onCommentChanged(
    CommentChanged event,
    Emitter<CreateBookingState> emit,
  ) {
    if (state is CreateBookingDataLoaded) {
      final currentState = state as CreateBookingDataLoaded;
      emit(currentState.copyWith(comment: event.comment));
    }
  }

  Future<void> _onSubmitBooking(
    SubmitBooking event,
    Emitter<CreateBookingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CreateBookingDataLoaded || !currentState.canSubmit) {
      emit(CreateBookingError('Заполните все обязательные поля'));
      return;
    }

    emit(CreateBookingLoading());

    try {
      // Рассчитываем время окончания
      final startDateTime = DateTime(
        currentState.selectedDate!.year,
        currentState.selectedDate!.month,
        currentState.selectedDate!.day,
        currentState.selectedTime!.hour,
        currentState.selectedTime!.minute,
      );

      final endDateTime = startDateTime.add(
        Duration(minutes: currentState.selectedServiceDuration!),
      );

      // Создаем запись в Supabase
      final response = await supabase.from('bookings').insert({
        'master_id': masterId,
        'client_id': currentState.selectedClientId,
        'service_id': currentState.selectedServiceId,
        'start_time': startDateTime.toIso8601String(),
        'end_time': endDateTime.toIso8601String(),
        'status': 'confirmed',
        'comment': currentState.comment?.isNotEmpty == true
            ? currentState.comment
            : null,
        'price_som': currentState.selectedServicePrice,
      }).select('id');

      final newBookingId = (response as List).first['id'] as String;

      // TODO: Здесь можно отправить уведомление клиенту через FCM

      emit(CreateBookingSuccess(newBookingId));
    } catch (e) {
      emit(CreateBookingError('Ошибка создания записи: $e'));
    }
  }

  void _onResetForm(
    ResetForm event,
    Emitter<CreateBookingState> emit,
  ) {
    if (state is CreateBookingDataLoaded) {
      final currentState = state as CreateBookingDataLoaded;
      emit(currentState.copyWith(
        selectedClientId: null,
        selectedClientName: null,
        selectedServiceId: null,
        selectedServiceName: null,
        selectedServiceDuration: null,
        selectedServicePrice: null,
        selectedDate: null,
        selectedTime: null,
        comment: '',
        busySlots: [],
      ));
    }
  }
}
