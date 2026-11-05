enum RevenuePeriod {
  day('Ngày'),
  week('Tuần'),
  month('Tháng');

  const RevenuePeriod(this.label);
  final String label;

  /// Calendar fields represent Vietnam dates. Query bounds are UTC instants.
  ({DateTime start, DateTime end}) range(DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final start = switch (this) {
      RevenuePeriod.day => dayStart,
      RevenuePeriod.week =>
        dayStart.subtract(Duration(days: dayStart.weekday - 1)),
      RevenuePeriod.month => DateTime.utc(date.year, date.month),
    };
    final end = switch (this) {
      RevenuePeriod.day => start.add(const Duration(days: 1)),
      RevenuePeriod.week => start.add(const Duration(days: 7)),
      RevenuePeriod.month => DateTime.utc(date.year, date.month + 1),
    };
    const offset = Duration(hours: 7);
    return (start: start.subtract(offset), end: end.subtract(offset));
  }
}
