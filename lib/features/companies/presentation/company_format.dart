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
