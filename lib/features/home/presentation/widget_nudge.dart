import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../services/widget_prompt_service.dart';
import 'widget_prompt.dart';

class WidgetNudge extends StatefulWidget {
  const WidgetNudge({
    super.key,
    required this.child,
    this.service = const WidgetPromptService(),
  });

  final Widget child;
  final WidgetPromptService service;

  @override
  State<WidgetNudge> createState() => _WidgetNudgeState();
}

class _WidgetNudgeState extends State<WidgetNudge> {
  bool _considered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consider());
  }

  Future<void> _consider() async {
    if (_considered) {
      return;
    }
    _considered = true;

    final state = await widget.service.registerOpen();
    if (!mounted || !shouldPromptForWidget(state)) {
      return;
    }

    final canPin = await widget.service.canPinDirectly();
    if (!mounted) {
      return;
    }

    await widget.service.recordPromptShown();
    if (!mounted) {
      return;
    }

    final choice = await showModalBottomSheet<_NudgeChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NudgeSheet(canPin: canPin),
    );

    if (choice == _NudgeChoice.add && canPin) {
      await widget.service.pin();
    } else if (choice == _NudgeChoice.never) {
      await widget.service.stopAsking();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _NudgeChoice { add, later, never }

class _NudgeSheet extends StatelessWidget {
  const _NudgeSheet({required this.canPin});

  final bool canPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);

    return Container(
      margin: const EdgeInsets.all(OrbitSpacing.lg),
      padding: const EdgeInsets.all(OrbitSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(OrbitRadius.sheet),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.widgets_outlined, size: 20, color: colors.accentInk),
              const SizedBox(width: OrbitSpacing.md),
              Expanded(
                child: Text(
                  'Keep your next deadline on the home screen',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: OrbitSpacing.md),
          Text(
            canPin
                ? 'Orbit can show the two drives that matter right now without '
                      'you opening the app. Adding it takes one tap.'
                : 'Orbit can show the two drives that matter right now without '
                      'you opening the app. Long-press an empty spot on your '
                      'home screen, choose Widgets, and pick Orbit.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: OrbitSpacing.xl),
          Row(
            children: [
              if (canPin)
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_NudgeChoice.add),
                    child: const Text('Add the widget'),
                  ),
                )
              else
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_NudgeChoice.later),
                    child: const Text('Got it'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: OrbitSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(_NudgeChoice.later),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_NudgeChoice.never),
                style: TextButton.styleFrom(foregroundColor: colors.inkFaint),
                child: const Text('Do not ask again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
