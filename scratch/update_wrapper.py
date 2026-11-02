with open('lib/core/widgets/ux_states/nova_state_wrapper.dart', 'r', encoding='utf-8') as f:
    text = f.read()

target = """  final Widget Function(BuildContext context, T data) builder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? offlineBuilder;

  const NovaStateWrapper({
    super.key,
    required this.isLoading,
    this.errorMessage,
    this.technicalError,
    this.isOffline = false,
    this.isSlowNetwork = false,
    required this.data,
    this.isEmptyCheck,
    this.searchQuery,
    this.onRetry,
    this.onClearSearch,
    required this.builder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.offlineBuilder,
  });"""

replacement = """  final Widget Function(BuildContext context, T data) builder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final Widget? emptyState;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? offlineBuilder;

  const NovaStateWrapper({
    super.key,
    required this.isLoading,
    this.errorMessage,
    this.technicalError,
    this.isOffline = false,
    this.isSlowNetwork = false,
    required this.data,
    this.isEmptyCheck,
    this.searchQuery,
    this.onRetry,
    this.onClearSearch,
    required this.builder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.emptyState,
    this.errorBuilder,
    this.offlineBuilder,
  });"""

text = text.replace(target, replacement)

target_empty = """      // 6. Empty State
      if (emptyBuilder != null) return emptyBuilder!(context);"""

repl_empty = """      // 6. Empty State
      if (emptyState != null) return emptyState!;
      if (emptyBuilder != null) return emptyBuilder!(context);"""

text = text.replace(target_empty, repl_empty)

with open('lib/core/widgets/ux_states/nova_state_wrapper.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print('Updated nova_state_wrapper.dart!')

