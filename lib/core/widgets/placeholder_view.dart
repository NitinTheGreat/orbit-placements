import 'package:flutter/material.dart';

class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.title,
    this.subtitle,
    this.showAppBar = true,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final bool showAppBar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actions != null) ...[
                const SizedBox(height: 24),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
