import 'package:flutter/material.dart';
import 'nova_empty_state.dart';
import 'nova_loading_state.dart';
import 'nova_error_state.dart';
import 'nova_no_internet_state.dart';
import 'nova_slow_network_state.dart';
import 'nova_no_search_results_state.dart';

/// Unified State Wrapper
/// Handles all 10 essential UI/UX states in a single, composable reactive widget.
/// Guarantees that screens never look blank, broken, or unresponsive.
class NovaStateWrapper<T> extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final dynamic technicalError;
  final bool isOffline;
  final bool isSlowNetwork;
  final T? data;
  final bool Function(T data)? isEmptyCheck;
  final String? searchQuery;
  final VoidCallback? onRetry;
  final VoidCallback? onClearSearch;
  final Widget Function(BuildContext context, T data) builder;
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
  });

  @override
  Widget build(BuildContext context) {
    final currentData = data;
    final hasNoData = currentData == null || (isEmptyCheck != null ? isEmptyCheck!(currentData) : _defaultIsEmpty(currentData));
    final hasData = !hasNoData;

    // 1. Loading State
    if (isLoading && hasNoData) {
      if (loadingBuilder != null) return loadingBuilder!(context);
      return NovaLoadingSkeleton.cardList();
    }

    // 2. Offline / No Internet State (when no cached data exists)
    if (isOffline && hasNoData) {
      if (offlineBuilder != null) return offlineBuilder!(context);
      return NovaNoInternetState(onRetry: onRetry);
    }

    // 3. Error State (when data is absent and error occurred)
    if (errorMessage != null && hasNoData) {
      if (errorBuilder != null) return errorBuilder!(context);
      return NovaErrorState(
        title: 'Operation Encountered an Issue',
        message: errorMessage!,
        technicalDetails: technicalError,
        onRetry: onRetry,
      );
    }

    if (hasNoData) {
      // 4. No Search Results State
      if (searchQuery != null && searchQuery!.trim().isNotEmpty) {
        return NovaNoSearchResultsState(
          searchQuery: searchQuery!,
          onClearSearch: onClearSearch,
        );
      }

      // 5. Empty State
      if (emptyState != null) return emptyState!;
      if (emptyBuilder != null) return emptyBuilder!(context);
      return NovaEmptyState(
        icon: Icons.inbox_rounded,
        title: 'No Records Found',
        message: 'There are no active records in this logistics category.',
        actionLabel: 'Refresh',
        onAction: onRetry,
      );
    }

    // 7. Active Data State (with optional Slow Network banner or Offline cache badge)
    return Column(
      children: [
        if (isSlowNetwork)
          const NovaSlowNetworkBanner(),
        if (isOffline && hasData)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFFFEF3C7),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 14, color: Color(0xFF92400E)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Offline Mode: Viewing locally cached logistics data',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
                if (onRetry != null)
                  InkWell(
                    onTap: onRetry,
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E), decoration: TextDecoration.underline),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: builder(context, data as T),
        ),
      ],
    );
  }

  bool _defaultIsEmpty(T val) {
    if (val is Iterable) return val.isEmpty;
    if (val is Map) return val.isEmpty;
    return false;
  }
}

