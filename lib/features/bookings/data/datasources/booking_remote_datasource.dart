import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

abstract class BookingRemoteDataSource {
  Future<List<BookingModel>> getBookings(String masterId, DateTime date);
  Future<BookingModel> createBooking(Map<String, dynamic> bookingData);
  Future<void> deleteBooking(String id);
  Future<void> updateBookingStatus(String id, String status);

  // Expose supabase client for direct access (as requested)
  SupabaseClient get supabase;
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final SupabaseClient supabase;

  BookingRemoteDataSourceImpl(this.supabase);

  // Временно хардкодим ID организации
  final String _hardcodedOrganizationId =
      'd5d6cd49-d1d4-4372-971f-1d497bdb6c0e'; // Replace with real UUID

  @override
  Future<List<BookingModel>> getBookings(String masterId, DateTime date) async {
    final startOfDate = DateTime(date.year, date.month, date.day);
    final endOfDate = startOfDate.add(const Duration(days: 1));

    final response = await supabase
        .from('bookings')
        .select(
          '*, client_profile:profiles!bookings_client_id_fkey(full_name)',
        ) // <--- Явный FK и alias
        .eq('master_id', masterId)
        .eq('organization_id', _hardcodedOrganizationId) // Filter by org
        .gte('start_time', startOfDate.toIso8601String())
        .lt('end_time', endOfDate.toIso8601String())
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => BookingModel.fromJson(json))
        .toList();
  }

  @override
  Future<BookingModel> createBooking(Map<String, dynamic> bookingData) async {
    // УДАЛИЛИ ХАРДКОД ОТСЮДА. Теперь мы доверяем тому, что пришло в bookingData

    final response = await supabase
        .from('bookings')
        .insert(bookingData)
        .select()
        .single();

    return BookingModel.fromJson(response);
  }

  @override
  Future<void> deleteBooking(String id) async {
    await supabase.from('bookings').delete().eq('id', id);
  }

  @override
  Future<void> updateBookingStatus(String id, String status) async {
    await supabase.from('bookings').update({'status': status}).eq('id', id);
  }
}
