import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/booking_entity.dart';
import '../../data/repositories/booking_repository_impl.dart';

// --- ИВЕНТЫ (EVENTS) ---
abstract class DailyBookingEvent {}

class UpdateDateRange extends DailyBookingEvent {
  final DateTimeRange dates;
  UpdateDateRange(this.dates);
}

class UpdateGuests extends DailyBookingEvent {
  final int guests;
  UpdateGuests(this.guests);
}

class CreateDailyBooking extends DailyBookingEvent {}


// --- СОСТОЯНИЯ (STATES) ---
class DailyBookingState {
  final DateTimeRange? selectedDates;
  final int guests;
  final bool isLoading;
  final String? error;
  final bool? isAvailable;

  DailyBookingState({
    this.selectedDates,
    this.guests = 1,
    this.isLoading = false,
    this.error,
    this.isAvailable,
  });

  DailyBookingState copyWith({
    DateTimeRange? selectedDates,
    int? guests,
    bool? isLoading,
    String? error,
    bool? isAvailable,
  }) {
    return DailyBookingState(
      selectedDates: selectedDates ?? this.selectedDates,
      guests: guests ?? this.guests,
      isLoading: isLoading ?? this.isLoading,
      error: error, 
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

// Успешная бронь
class DailyBookingSuccess extends DailyBookingState {
  final BookingEntity booking;
  
  DailyBookingSuccess(this.booking, DailyBookingState currentState) 
    : super(
        selectedDates: currentState.selectedDates,
        guests: currentState.guests,
        isLoading: false,
        isAvailable: true,
      );
}

// Ошибка (с флагом критичности для SnackBar)
class DailyBookingError extends DailyBookingState {
  final bool isCritical;
  final String message;

  DailyBookingError(this.message, DailyBookingState currentState, {this.isCritical = false})
      : super(
          selectedDates: currentState.selectedDates,
          guests: currentState.guests,
          isLoading: false,
          error: message,
        );
}


// --- САМ BLOC ---
class DailyBookingBloc extends Bloc<DailyBookingEvent, DailyBookingState> {
  final BookingRepositoryImpl repository;
  final ServiceEntity service;
  final String masterId;
  final _supabase = Supabase.instance.client;

  DailyBookingBloc({
    required this.repository,
    required this.service,
    required this.masterId,
  }) : super(DailyBookingState()) {
    on<UpdateDateRange>(_onUpdateDateRange);
    on<UpdateGuests>(_onUpdateGuests);
    on<CreateDailyBooking>(_onCreateBooking);
  }

  Future<void> _onUpdateDateRange(UpdateDateRange event, Emitter<DailyBookingState> emit) async {
    emit(state.copyWith(selectedDates: event.dates, error: null));
    await _checkAvailability(emit);
  }

  Future<void> _onUpdateGuests(UpdateGuests event, Emitter<DailyBookingState> emit) async {
    emit(state.copyWith(guests: event.guests, error: null));
    if (state.selectedDates != null) {
      await _checkAvailability(emit);
    }
  }

  Future<void> _checkAvailability(Emitter<DailyBookingState> emit) async {
    if (state.selectedDates == null) return;
    
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final checkIn = state.selectedDates!.start;
      final checkOut = state.selectedDates!.end;

      // ИСПРАВЛЕНО: запрашиваем capacity вместо quantity
      final response = await _supabase
          .from('bookings')
          .select('start_time, end_time, capacity')
          .eq('service_id', service.id)
          .neq('status', 'cancelled');

      final existingBookings = List<Map<String, dynamic>>.from(response);
      bool isAvail = true;

      for (var i = 0; i < checkOut.difference(checkIn).inDays; i++) {
        final currentNight = checkIn.add(Duration(days: i));
        int occupiedBedsThisNight = 0;

        for (var booking in existingBookings) {
          final bStart = DateTime.parse(booking['start_time']).toLocal();
          final bEnd = DateTime.parse(booking['end_time']).toLocal();
          final bCheckIn = DateTime(bStart.year, bStart.month, bStart.day);
          final bCheckOut = DateTime(bEnd.year, bEnd.month, bEnd.day);

          if ((currentNight.isAtSameMomentAs(bCheckIn) || currentNight.isAfter(bCheckIn)) &&
              currentNight.isBefore(bCheckOut)) {
            // ИСПРАВЛЕНО: используем capacity
            occupiedBedsThisNight += (booking['capacity'] as int?) ?? 1;
          }
        }

        if (occupiedBedsThisNight + state.guests > service.capacity) {
          isAvail = false;
          break;
        }
      }

      emit(state.copyWith(isLoading: false, isAvailable: isAvail));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Ошибка проверки мест: $e', isAvailable: false));
    }
  }

  Future<void> _onCreateBooking(CreateDailyBooking event, Emitter<DailyBookingState> emit) async {
    if (state.selectedDates == null || state.isAvailable != true) return;

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final checkIn = state.selectedDates!.start;
      final checkOut = state.selectedDates!.end;
      final clientId = _supabase.auth.currentUser!.id;

      // Заезд в 14:00, выезд в 12:00
      final startWithTime = DateTime(checkIn.year, checkIn.month, checkIn.day, 14, 0).toUtc().toIso8601String();
      final endWithTime = DateTime(checkOut.year, checkOut.month, checkOut.day, 12, 0).toUtc().toIso8601String();

      // ИСПРАВЛЕНО: передаем booking_type и capacity
      final data = await _supabase.from('bookings').insert({
        'client_id': clientId,
        'master_id': masterId,
        'service_id': service.id,
        'start_time': startWithTime,
        'end_time': endWithTime,
        'status': 'pending',
        'booking_type': 'daily', 
        'capacity': state.guests, 
      }).select().single();

      final booking = BookingEntity(
        id: data['id'],
        masterId: masterId,
        clientId: clientId,
        clientName: '', // В рамках этого BLoC нам имя не нужно, пустая строка ок
        serviceId: service.id,
        startTime: DateTime.parse(data['start_time']).toLocal(),
        endTime: DateTime.parse(data['end_time']).toLocal(),
        status: BookingStatus.pending,
        bookingType: 'daily',
        capacity: state.guests,
      );

      emit(DailyBookingSuccess(booking, state));
    } catch (e) {
      emit(DailyBookingError('Ошибка бронирования: $e', state, isCritical: true));
    }
  }
}