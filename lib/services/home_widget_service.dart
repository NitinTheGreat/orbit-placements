import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../features/companies/presentation/widget_feed.dart';

const String orbitWidgetProvider = 'com.nitin.orbit.OrbitWidgetProvider';

class HomeWidgetService {
  const HomeWidgetService();

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> publish(WidgetFeed feed) async {
    if (!isSupported) {
      return;
    }

    await HomeWidget.saveWidgetData<String>('headline', feed.headline);
    await HomeWidget.saveWidgetData<bool>('empty', feed.isEmpty);

    for (var slot = 0; slot < widgetSlotCount; slot++) {
      final drive = slot < feed.drives.length ? feed.drives[slot] : null;
      await HomeWidget.saveWidgetData<String>('name$slot', drive?.name);
      await HomeWidget.saveWidgetData<String>('line$slot', drive?.line);
    }

    await HomeWidget.updateWidget(qualifiedAndroidName: orbitWidgetProvider);
  }
}
