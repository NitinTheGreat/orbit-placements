import 'package:flutter/foundation.dart';

import '../../companies/presentation/drive_filter.dart';

final ValueNotifier<int> homeTabIndex = ValueNotifier<int>(0);

final ValueNotifier<DriveFilter> drivesFilter = ValueNotifier<DriveFilter>(
  DriveFilter.all,
);
