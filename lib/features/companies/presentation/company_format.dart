class CompanyFormat {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String date(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  static String dateTime(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${date(value)}, $hour:$minute';
  }

  static String deadlineLabel(DateTime? deadline) {
    if (deadline == null) {
      return 'No deadline';
    }

    final now = DateTime.now();
    final local = deadline.toLocal();
    final days = DateTime(
      local.year,
      local.month,
      local.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    if (days < 0) {
      return 'Closed ${date(deadline)}';
    }
    if (days == 0) {
      return 'Closes today';
    }
    if (days == 1) {
      return 'Closes tomorrow';
    }
    if (days <= 7) {
      return 'Closes in $days days';
    }
    return 'Closes ${date(deadline)}';
  }
}

enum DeadlineUrgency { unknown, passed, today, imminent, thisWeek, distant }

extension DeadlineUrgencyInfo on DeadlineUrgency {
  bool get isPressing =>
      this == DeadlineUrgency.today || this == DeadlineUrgency.imminent;
}

DeadlineUrgency deadlineUrgency(DateTime? deadline, {DateTime? now}) {
  if (deadline == null) {
    return DeadlineUrgency.unknown;
  }

  final reference = now ?? DateTime.now();
  final local = deadline.toLocal();
  final days = DateTime(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime(reference.year, reference.month, reference.day)).inDays;

  if (days < 0) {
    return DeadlineUrgency.passed;
  }
  if (days == 0) {
    return DeadlineUrgency.today;
  }
  if (days <= 2) {
    return DeadlineUrgency.imminent;
  }
  if (days <= 7) {
    return DeadlineUrgency.thisWeek;
  }
  return DeadlineUrgency.distant;
}

String relativeSince(DateTime? moment, {DateTime? now}) {
  if (moment == null) {
    return 'never';
  }
  final reference = now ?? DateTime.now();
  final elapsed = reference.difference(moment.toLocal());

  if (elapsed.isNegative || elapsed.inSeconds < 60) {
    return 'just now';
  }
  if (elapsed.inMinutes < 60) {
    final minutes = elapsed.inMinutes;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (elapsed.inHours < 24) {
    final hours = elapsed.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  final days = elapsed.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}
