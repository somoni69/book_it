import 'package:flutter/material.dart';
import '../entities/booking_entity.dart';
import '../entities/working_hour_entity.dart';
import '../entities/daily_schedule.dart';
import '../entities/time_slot.dart';
import '../repositories/booking_repository.dart';
import '../repositories/service_repository.dart';

class GenerateSlotsParams {
  final String masterId;
  final String serviceId;
  final DateTime selectedDate;

  GenerateSlotsParams({
    required this.masterId,
    required this.serviceId,
    required this.selectedDate,
  });
}

class GenerateSlotsUseCase {
  final BookingRepository _bookingRepo;
  final ServiceRepository _serviceRepo;

  GenerateSlotsUseCase({
    required BookingRepository bookingRepo,
    required ServiceRepository serviceRepo,
  })  : _bookingRepo = bookingRepo,
        _serviceRepo = serviceRepo;

  Future<List<TimeSlot>> call(GenerateSlotsParams params) async {
    // 1. Получаем график мастера на выбранный день
    final schedule = await _getScheduleForDate(
      params.masterId,
      params.selectedDate,
    );

    if (schedule.isDayOff) {
      return [];
    }

    // 2. Получаем существующие брони
    final bookings = await _bookingRepo.getBookingsForMaster(
      params.masterId,
      params.selectedDate,
    );

    // 3. Получаем длительность услуги
    final services = await _serviceRepo.getServicesByMaster(params.masterId);
    final service = services.firstWhere(
      (s) => s.id == params.serviceId,
      orElse: () => services.first,
    );

    // 4. Генерируем слоты с учетом нескольких рабочих окон
    return _generateSlotsFromWindows(
      schedule: schedule,
      bookings: bookings,
      serviceDuration: service.durationMin,
      selectedDate: params.selectedDate,
    );
  }

  Future<DailySchedule> _getScheduleForDate(
    String masterId,
    DateTime date,
  ) async {
    final dayOfWeek = date.weekday;
    final schedules = await _bookingRepo.getSchedule(masterId);

    final daySchedule = schedules.firstWhere(
      (s) => s.dayOfWeek == dayOfWeek,
      orElse: () => const WorkingHourEntity(
        id: '',
        masterId: '',
        dayOfWeek: 0,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 18, minute: 0),
        isDayOff: false,
      ),
    );

    return DailySchedule(
      dayOfWeek: dayOfWeek,
      isDayOff: daySchedule.isDayOff,
      workingWindows: daySchedule.isDayOff
          ? []
          : [
              WorkingWindow(
                startTime: daySchedule.startTime,
                endTime: daySchedule.endTime,
              ),
            ],
    );
  }

  List<TimeSlot> _generateSlotsFromWindows({
    required DailySchedule schedule,
    required List<BookingEntity> bookings,
    required int serviceDuration,
    required DateTime selectedDate,
  }) {
    final slots = <TimeSlot>[];

    for (final window in schedule.workingWindows) {
      final windowSlots = _generateSlotsForWindow(
        window: window,
        bookings: bookings,
        serviceDuration: serviceDuration,
        selectedDate: selectedDate,
      );
      slots.addAll(windowSlots);
    }

    return slots;
  }

  List<TimeSlot> _generateSlotsForWindow({
    required WorkingWindow window,
    required List<BookingEntity> bookings,
    required int serviceDuration,
    required DateTime selectedDate,
  }) {
    final slots = <TimeSlot>[];

    final startMinutes = window.startTime.hour * 60 + window.startTime.minute;
    final endMinutes = window.endTime.hour * 60 + window.endTime.minute;

    for (var minute = startMinutes;
        minute <= endMinutes - serviceDuration;
        minute += 15) {
      final slotStartMinutes = minute;
      final slotEndMinutes = minute + serviceDuration;

      final slotStart = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        slotStartMinutes ~/ 60,
        slotStartMinutes % 60,
      );

      final slotEnd = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        slotEndMinutes ~/ 60,
        slotEndMinutes % 60,
      );

      if (!_isSlotBooked(slotStart, slotEnd, bookings)) {
        final isPast = slotStart.isBefore(DateTime.now());
        slots.add(
          TimeSlot(
            startTime: slotStart,
            endTime: slotEnd,
            isAvailable: !isPast,
          ),
        );
      }
    }

    return slots;
  }

  bool _isSlotBooked(
    DateTime slotStart,
    DateTime slotEnd,
    List<BookingEntity> bookings,
  ) {
    return bookings.any((booking) {
      if (booking.status == BookingStatus.cancelled) return false;
      return booking.startTime.isBefore(slotEnd) &&
          booking.endTime.isAfter(slotStart);
    });
  }
}
