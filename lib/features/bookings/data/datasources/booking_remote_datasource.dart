import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

abstract class BookingRemoteDataSource {
  Future<List<BookingModel>> getBookings(String masterId, DateTime date);
  Future<List<BookingModel>> getClientBookings(String clientId);
  Future<BookingModel> createBooking(Map<String, dynamic> bookingData);
  Future<void> deleteBooking(String id);
  Future<void> updateBookingStatus(String id, String status);

  SupabaseClient get supabase;
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  @override
  final SupabaseClient supabase;

  BookingRemoteDataSourceImpl(this.supabase);

  @override
  Future<List<BookingModel>> getBookings(String masterId, DateTime date) async {
    final startOfDate = DateTime(date.year, date.month, date.day);
    final endOfDate = startOfDate.add(const Duration(days: 1));

    final response = await supabase
        .from('bookings')
        .select('''
          *,
          client_profile:profiles!bookings_client_id_fkey(full_name),
          service_details:services!bookings_service_id_fkey(title)
        ''')
        .eq('master_id', masterId)
        .gte('start_time', startOfDate.toIso8601String())
        .lt('start_time', endOfDate.toIso8601String())
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => BookingModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<BookingModel>> getClientBookings(String clientId) async {
    final response = await supabase.from('bookings').select('''
          *,
          master_profile:profiles!bookings_master_id_fkey(full_name),
          service_details:services!bookings_service_id_fkey(title)
        ''').eq('client_id', clientId).order('start_time', ascending: false);

    return (response as List)
        .map((json) => BookingModel.fromJson(json))
        .toList();
  }

  @override
  Future<BookingModel> createBooking(Map<String, dynamic> bookingData) async {
    final response =
        await supabase.from('bookings').insert(bookingData).select().single();

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
