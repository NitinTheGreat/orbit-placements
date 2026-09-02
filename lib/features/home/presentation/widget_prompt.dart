const int promptEveryNthOpen = 3;
const int maxWidgetPrompts = 5;

class WidgetPromptState {
  const WidgetPromptState({
    this.opens = 0,
    this.promptsShown = 0,
    this.installed = false,
    this.dismissedForever = false,
  });

  final int opens;
  final int promptsShown;
  final bool installed;
  final bool dismissedForever;

  WidgetPromptState copyWith({
    int? opens,
    int? promptsShown,
    bool? installed,
    bool? dismissedForever,
  }) {
    return WidgetPromptState(
      opens: opens ?? this.opens,
      promptsShown: promptsShown ?? this.promptsShown,
      installed: installed ?? this.installed,
      dismissedForever: dismissedForever ?? this.dismissedForever,
    );
  }
}

bool shouldPromptForWidget(WidgetPromptState state) {
  if (state.installed) {
    return false;
  }
  if (state.dismissedForever) {
    return false;
  }
  if (state.promptsShown >= maxWidgetPrompts) {
    return false;
  }
  if (state.opens <= 0) {
    return false;
  }
  return state.opens % promptEveryNthOpen == 0;
}

bool promptingIsFinished(WidgetPromptState state) {
  return state.installed ||
      state.dismissedForever ||
      state.promptsShown >= maxWidgetPrompts;
}
