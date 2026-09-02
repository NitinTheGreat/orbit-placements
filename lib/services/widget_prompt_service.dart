import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/home/presentation/widget_prompt.dart';
import 'home_widget_service.dart';

const String _opensKey = 'orbit.widget.opens';
const String _promptsKey = 'orbit.widget.prompts';
const String _dismissedKey = 'orbit.widget.dismissed';

class WidgetPromptService {
  const WidgetPromptService({this.homeWidget = const HomeWidgetService()});

  final HomeWidgetService homeWidget;

  Future<bool> isInstalled() async {
    if (!homeWidget.isSupported) {
      return true;
    }
    try {
      final widgets = await HomeWidget.getInstalledWidgets();
      return widgets.any(
        (widget) => (widget.androidClassName ?? '').contains(
          'OrbitWidgetProvider',
        ),
      );
    } on Object catch (error) {
      debugPrint('widget install check skipped: $error');
      return true;
    }
  }

  Future<bool> canPinDirectly() async {
    if (!homeWidget.isSupported) {
      return false;
    }
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } on Object catch (error) {
      debugPrint('pin support check skipped: $error');
      return false;
    }
  }

  Future<void> pin() async {
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: orbitWidgetProvider,
    );
  }

  Future<WidgetPromptState> registerOpen() async {
    if (!homeWidget.isSupported) {
      return const WidgetPromptState(installed: true);
    }

    final prefs = await SharedPreferences.getInstance();
    final installed = await isInstalled();

    if (installed) {
      return WidgetPromptState(
        opens: prefs.getInt(_opensKey) ?? 0,
        promptsShown: prefs.getInt(_promptsKey) ?? 0,
        installed: true,
        dismissedForever: prefs.getBool(_dismissedKey) ?? false,
      );
    }

    final opens = (prefs.getInt(_opensKey) ?? 0) + 1;
    await prefs.setInt(_opensKey, opens);

    return WidgetPromptState(
      opens: opens,
      promptsShown: prefs.getInt(_promptsKey) ?? 0,
      installed: false,
      dismissedForever: prefs.getBool(_dismissedKey) ?? false,
    );
  }

  Future<void> recordPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_promptsKey, (prefs.getInt(_promptsKey) ?? 0) + 1);
  }

  Future<void> stopAsking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }
}
