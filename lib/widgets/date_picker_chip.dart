import 'package:flutter/material.dart';

/// A compact "Today ▾" chip used on the logging forms so entries can be
/// backdated. Tapping opens a date picker bounded to the last [maxPastDays] days
/// (no future dates). The returned date is normalised to local noon so the
/// stored entry lands unambiguously on the chosen calendar day.
class DatePickerChip extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final int maxPastDays;
  const DatePickerChip({
    super.key,
    required this.date,
    required this.onChanged,
    this.maxPastDays = 60,
  });

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _label(date) == 'Today';
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date.isAfter(now) ? now : date,
          firstDate: now.subtract(Duration(days: maxPastDays)),
          lastDate: now,
        );
        if (picked != null) {
          onChanged(DateTime(picked.year, picked.month, picked.day, 12));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFF2C2C2E) : const Color(0xFF40C8E0).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isToday ? const Color(0xFF3A3A3C) : const Color(0xFF40C8E0),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: 13,
              color: isToday ? const Color(0xFF8E8E93) : const Color(0xFF40C8E0)),
          const SizedBox(width: 6),
          Text(_label(date),
              style: TextStyle(
                  color: isToday ? Colors.white : const Color(0xFF40C8E0),
                  fontSize: 13, fontWeight: FontWeight.w600)),
          Icon(Icons.arrow_drop_down, size: 18,
              color: isToday ? const Color(0xFF8E8E93) : const Color(0xFF40C8E0)),
        ]),
      ),
    );
  }
}
