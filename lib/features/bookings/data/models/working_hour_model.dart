class WorkingHour {
  final String id;
  final int dayOfWeek; // 1 = Пн, 7 = Вс
  final String startTime; // "09:00"
  final String endTime; // "18:00"
  final bool isDayOff;

  WorkingHour({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isDayOff,
  });

  factory WorkingHour.fromJson(Map<String, dynamic> json) {
    return WorkingHour(
      id:
          json['id'] ??
          '', // Handle potential null id during initial load if necessary, though DB should provide it
      dayOfWeek: json['day_of_week'],
      startTime: json['start_time'].toString().substring(
        0,
        5,
      ), // Обрезаем секунды
      endTime: json['end_time'].toString().substring(0, 5),
      isDayOff: json['is_day_off'],
    );
  }
}
