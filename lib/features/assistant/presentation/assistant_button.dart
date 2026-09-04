import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../services/assistant_service.dart';

const Key assistantMessagesKey = Key('assistant-messages');
const Key assistantChipsKey = Key('assistant-chips');
const Key assistantInputKey = Key('assistant-input');

const double assistantButtonSize = 52;
const double assistantButtonInset = OrbitSpacing.lg;

class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key, this.service});

  final AssistantService? service;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitTheme.of(context);

    return Pressable(
      onTap: () => showAssistantPanel(context, service: service),
      child: Container(
        width: assistantButtonSize,
        height: assistantButtonSize,
        decoration: BoxDecoration(
          color: colors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: colors.accentEdge),
          boxShadow: [
            BoxShadow(
              color: colors.ink.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_outlined,
          size: 22,
          color: colors.surfaceRaised,
        ),
      ),
    );
  }
}

Future<void> showAssistantPanel(
  BuildContext context, {
  AssistantService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AssistantPanel(service: service),
  );
}

class AssistantPanel extends StatefulWidget {
  const AssistantPanel({super.key, this.service});

  final AssistantService? service;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  late final AssistantService _service = widget.service ?? AssistantService();
  final TextEditingController _controller = TextEditingController();

  bool _busy = false;
  AssistantAnswer? _answer;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask({String? presetId, String? text}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final answer = await _service.ask(presetId: presetId, text: text);
      if (!mounted) {
        return;
      }
      setState(() {
        _answer = answer;
        _busy = false;
      });
      _controller.clear();
    } on AssistantException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitTheme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final maxPanelHeight = media.size.height * 0.72;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(OrbitSpacing.md),
        padding: const EdgeInsets.all(OrbitSpacing.lg),
        constraints: BoxConstraints(maxHeight: maxPanelHeight),
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
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: colors.accentInk,
                ),
                const SizedBox(width: OrbitSpacing.sm),
                Text('Ask Orbit', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 19),
                  color: colors.inkFaint,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: OrbitSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                key: assistantMessagesKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_answer == null && _error == null && !_busy)
                      Text(
                        'Orbit answers from your own drives only.',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (_busy)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: OrbitSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: OrbitSpacing.md),
                            Text(
                              'Reading your drives',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: OrbitSpacing.sm),
                        padding: const EdgeInsets.all(OrbitSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.urgentWash,
                          borderRadius: BorderRadius.circular(
                            OrbitRadius.control,
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.urgentInk,
                          ),
                        ),
                      ),
                    if (_answer != null && !_busy) ...[
                      const SizedBox(height: OrbitSpacing.sm),
                      Text(
                        _answer!.question,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: OrbitSpacing.sm),
                      Text(
                        _answer!.answer,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: OrbitSpacing.lg),
            SizedBox(
              key: assistantChipsKey,
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: assistantPresets.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: OrbitSpacing.sm),
                itemBuilder: (context, index) {
                  final preset = assistantPresets[index];
                  return Center(
                    child: Pressable(
                      onTap: _busy ? null : () => _ask(presetId: preset.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OrbitSpacing.md,
                          vertical: OrbitSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentWash,
                          borderRadius: BorderRadius.circular(OrbitRadius.pill),
                          border: Border.all(color: colors.accentEdge),
                        ),
                        child: Text(
                          preset.label,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.accentInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: OrbitSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: assistantInputKey,
                    controller: _controller,
                    enabled: !_busy,
                    textInputAction: TextInputAction.send,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Or ask something else',
                    ),
                    onSubmitted: (value) => _ask(text: value),
                  ),
                ),
                const SizedBox(width: OrbitSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 19),
                  color: colors.accentInk,
                  onPressed: _busy ? null : () => _ask(text: _controller.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
