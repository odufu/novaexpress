import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Header style themes for Pangea Excel Data Table
enum TableHeaderStyle {
  classic, // Soft slate grey background (#F1F5F9 / #131D31)
  brandTinted, // Accent wash tinted with brand primary color
  darkContrast, // High-contrast deep navy/slate (#0F172A / #1E293B)
  minimalist, // Clean borderless white / transparent
}

/// Row spacing density
enum TableDensity {
  compact, // High density (tight rows)
  standard, // Standard balanced density
  spacious, // Relaxed touch-friendly rows
}

/// Global shared controller for Pangea Excel Table preferences.
/// Changing settings here immediately updates ALL tables across the platform in real time.
class PangeaTablePreferencesController extends ChangeNotifier {
  static final PangeaTablePreferencesController instance = PangeaTablePreferencesController._();
  PangeaTablePreferencesController._() {
    _loadPreferences();
  }

  double _fontSize = 12.0;
  TableHeaderStyle _headerStyle = TableHeaderStyle.classic;
  TableDensity _density = TableDensity.standard;
  bool _showVerticalGridlines = true;
  bool _showZebraStriping = true;
  int _defaultPageSize = 25;

  double get fontSize => _fontSize;
  TableHeaderStyle get headerStyle => _headerStyle;
  TableDensity get density => _density;
  bool get showVerticalGridlines => _showVerticalGridlines;
  bool get showZebraStriping => _showZebraStriping;
  int get defaultPageSize => _defaultPageSize;

  double get fontScale => _fontSize / 12.0;

  double get densityFactor {
    switch (_density) {
      case TableDensity.compact:
        return 0.88;
      case TableDensity.spacious:
        return 1.15;
      case TableDensity.standard:
        return 1.0;
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontSize = (prefs.getDouble('pangea_table_font_size') ?? 12.0).clamp(10.0, 16.0);
      final headerIdx = prefs.getInt('pangea_table_header_style');
      if (headerIdx != null && headerIdx >= 0 && headerIdx < TableHeaderStyle.values.length) {
        _headerStyle = TableHeaderStyle.values[headerIdx];
      }
      final densityIdx = prefs.getInt('pangea_table_density');
      if (densityIdx != null && densityIdx >= 0 && densityIdx < TableDensity.values.length) {
        _density = TableDensity.values[densityIdx];
      }
      _showVerticalGridlines = prefs.getBool('pangea_table_vertical_gridlines') ?? true;
      _showZebraStriping = prefs.getBool('pangea_table_zebra_striping') ?? true;
      _defaultPageSize = prefs.getInt('pangea_table_page_size') ?? 25;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(10.0, 16.0);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pangea_table_font_size', _fontSize);
    } catch (_) {}
  }

  Future<void> setHeaderStyle(TableHeaderStyle style) async {
    _headerStyle = style;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pangea_table_header_style', style.index);
    } catch (_) {}
  }

  Future<void> setDensity(TableDensity density) async {
    _density = density;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pangea_table_density', density.index);
    } catch (_) {}
  }

  Future<void> setVerticalGridlines(bool show) async {
    _showVerticalGridlines = show;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pangea_table_vertical_gridlines', show);
    } catch (_) {}
  }

  Future<void> setZebraStriping(bool show) async {
    _showZebraStriping = show;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pangea_table_zebra_striping', show);
    } catch (_) {}
  }

  Future<void> setDefaultPageSize(int size) async {
    _defaultPageSize = size;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pangea_table_page_size', size);
    } catch (_) {}
  }

  Future<void> resetToDefaults() async {
    _fontSize = 12.0;
    _headerStyle = TableHeaderStyle.classic;
    _density = TableDensity.standard;
    _showVerticalGridlines = true;
    _showZebraStriping = true;
    _defaultPageSize = 25;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pangea_table_font_size');
      await prefs.remove('pangea_table_header_style');
      await prefs.remove('pangea_table_density');
      await prefs.remove('pangea_table_vertical_gridlines');
      await prefs.remove('pangea_table_zebra_striping');
      await prefs.remove('pangea_table_page_size');
    } catch (_) {}
  }
}

/// Column definition for Pangea Excel Data Table
class ExcelColumnDef<T> {
  final String key;
  final String label;
  final String? group; // Optional Group Header (e.g. 'OPERATIONS COST')
  final double defaultWidth;
  final double minWidth;
  final TextAlign align;
  final Widget Function(BuildContext context, T item, int index, bool isDark, Color brandPrimary) cellBuilder;
  final String Function(T item)? searchString;
  final Comparable Function(T item)? sortValue;

  const ExcelColumnDef({
    required this.key,
    required this.label,
    this.group,
    required this.defaultWidth,
    this.minWidth = 50.0,
    this.align = TextAlign.left,
    required this.cellBuilder,
    this.searchString,
    this.sortValue,
  });
}

/// Generic, theme-responsive, Excel-style Data Table with:
/// - Adjustable/resizable columns via mouse drag
/// - Double-click splitter to reset column width
/// - Inline per-column search filters
/// - Multi-tier category group headers
/// - Crisp spreadsheet cell borders and alternating row styling
/// - Built-in pagination and per-page selector
/// - Interactive display & typography settings modal (font size slider, header styles, density)
class PangeaExcelDataTable<T> extends StatefulWidget {
  final List<T> items;
  final List<ExcelColumnDef<T>> columns;
  final Color brandPrimary;
  final String? emptyMessage;
  final Widget? trailingFooterAction;
  final bool showFilterRow;
  final void Function(T item)? onRowTap;
  final double? tableHeight;
  final double rowHeight;
  final bool enablePagination;
  final int? initialPageSize;
  final bool showSettingsButton;
  final bool showTopToolbar;

  const PangeaExcelDataTable({
    super.key,
    required this.items,
    required this.columns,
    this.brandPrimary = const Color(0xFF0D9488),
    this.emptyMessage,
    this.trailingFooterAction,
    this.showFilterRow = true,
    this.onRowTap,
    this.tableHeight,
    this.rowHeight = 44.0,
    this.enablePagination = true,
    this.initialPageSize,
    this.showSettingsButton = true,
    this.showTopToolbar = true,
  });

  @override
  State<PangeaExcelDataTable<T>> createState() => _PangeaExcelDataTableState<T>();
}

class _PangeaExcelDataTableState<T> extends State<PangeaExcelDataTable<T>> {
  late Map<String, double> _colWidths;
  final Map<String, String> _searchFilters = {};
  final Map<String, TextEditingController> _filterControllers = {};

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  String? _sortColumnKey;
  bool _sortAscending = true;
  int _currentPage = 0;
  late int _pageSize;

  @override
  void initState() {
    super.initState();
    _colWidths = {for (var c in widget.columns) c.key: c.defaultWidth};
    _pageSize = widget.initialPageSize ?? PangeaTablePreferencesController.instance.defaultPageSize;
    PangeaTablePreferencesController.instance.addListener(_onPreferencesChanged);
  }

  void _onPreferencesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant PangeaExcelDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (var c in widget.columns) {
      _colWidths.putIfAbsent(c.key, () => c.defaultWidth);
    }
  }

  @override
  void dispose() {
    PangeaTablePreferencesController.instance.removeListener(_onPreferencesChanged);
    _horizontalController.dispose();
    _verticalController.dispose();
    for (final c in _filterControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _getColWidth(String key) {
    final def = widget.columns.firstWhere((c) => c.key == key);
    return _colWidths[key] ?? def.defaultWidth;
  }

  double get _totalTableWidth => widget.columns.fold(0.0, (sum, col) => sum + _getColWidth(col.key));

  bool get _hasGroupHeaders => widget.columns.any((c) => c.group != null && c.group!.isNotEmpty);

  List<T> get _filteredAndSortedItems {
    var list = widget.items.where((item) {
      for (final entry in _searchFilters.entries) {
        if (entry.value.isEmpty) continue;
        final col = widget.columns.firstWhere((c) => c.key == entry.key);
        if (col.searchString != null) {
          final val = col.searchString!(item).toLowerCase();
          if (!val.contains(entry.value.toLowerCase())) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    if (_sortColumnKey != null) {
      final col = widget.columns.firstWhere((c) => c.key == _sortColumnKey);
      if (col.sortValue != null) {
        list.sort((a, b) {
          final valA = col.sortValue!(a);
          final valB = col.sortValue!(b);
          final cmp = Comparable.compare(valA, valB);
          return _sortAscending ? cmp : -cmp;
        });
      }
    }

    return list;
  }

  List<T> _getPagedItems(List<T> fullList) {
    if (!widget.enablePagination || _pageSize <= 0) {
      return fullList;
    }
    final totalCount = fullList.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 9999);
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = safePage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalCount);
    if (startIndex >= totalCount) return [];
    return fullList.sublist(startIndex, endIndex);
  }

  void _resetAllWidths() {
    setState(() {
      _colWidths = {for (var c in widget.columns) c.key: c.defaultWidth};
    });
  }

  void _clearFilters() {
    setState(() {
      _searchFilters.clear();
      _currentPage = 0;
      for (final ctrl in _filterControllers.values) {
        ctrl.clear();
      }
    });
  }

  void _openSettingsModal(BuildContext context) {
    PangeaTableSettingsModal.show(context, brandPrimary: widget.brandPrimary);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = PangeaTablePreferencesController.instance;
    final filtered = _filteredAndSortedItems;
    final pagedItems = _getPagedItems(filtered);
    final totalWidth = _totalTableWidth;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = widget.tableHeight != null || constraints.maxHeight.isFinite;
        final showTop = widget.showTopToolbar && (widget.enablePagination || widget.showSettingsButton);

        final tableContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Excel Table Top Toolbar with Pagination & Gear Settings Icon
            if (showTop)
              _buildTopToolbar(pagedItems.length, filtered.length, widget.items.length, isDark, borderColor),

            // Scrollable Table Core
            hasBoundedHeight
                ? Expanded(child: _buildScrollableCore(pagedItems, totalWidth, isDark, borderColor, true, prefs))
                : _buildScrollableCore(pagedItems, totalWidth, isDark, borderColor, false, prefs),

            // Excel Table Footer Toolbar with Pagination & Settings
            _buildFooterToolbar(pagedItems.length, filtered.length, widget.items.length, isDark, borderColor),
          ],
        );

        final decorated = Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: tableContent,
          ),
        );

        if (widget.tableHeight != null) {
          return SizedBox(
            height: widget.tableHeight,
            child: decorated,
          );
        }

        return decorated;
      },
    );
  }

  Widget _buildScrollableCore(
    List<T> displayedItems,
    double totalWidth,
    bool isDark,
    Color borderColor,
    bool isBounded,
    PangeaTablePreferencesController prefs,
  ) {
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Top Group Headers (if any)
              if (_hasGroupHeaders) _buildGroupHeaderRow(isDark, borderColor, prefs),

              // Column Headers Row with Resizers
              _buildHeaderRow(isDark, borderColor, prefs),

              // Inline Search Filter Row
              if (widget.showFilterRow) _buildFilterRow(isDark, borderColor, prefs),

              // Rows List
              if (isBounded)
                Expanded(
                  child: displayedItems.isEmpty
                      ? _buildEmptyState(isDark)
                      : Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _verticalController,
                            itemCount: displayedItems.length,
                            itemBuilder: (context, index) {
                              final absoluteIndex = (widget.enablePagination && _pageSize > 0)
                                  ? (_currentPage * _pageSize) + index + 1
                                  : index + 1;
                              return _buildDataRow(displayedItems[index], absoluteIndex, isDark, borderColor, prefs);
                            },
                          ),
                        ),
                )
              else
                displayedItems.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedItems.length,
                        itemBuilder: (context, index) {
                          final absoluteIndex = (widget.enablePagination && _pageSize > 0)
                              ? (_currentPage * _pageSize) + index + 1
                              : index + 1;
                          return _buildDataRow(displayedItems[index], absoluteIndex, isDark, borderColor, prefs);
                        },
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeaderRow(bool isDark, Color borderColor, PangeaTablePreferencesController prefs) {
    final groupBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);
    final groupHeight = (28.0 * prefs.fontScale).clamp(24.0, 38.0);
    final groupFontSize = (prefs.fontSize * 0.85).clamp(8.5, 13.0);

    // Group adjacent columns that share the same group label
    final groupSpans = <Map<String, dynamic>>[];
    String? currentGroup;
    double currentWidth = 0.0;

    for (final col in widget.columns) {
      final width = _getColWidth(col.key);
      if (col.group == currentGroup) {
        currentWidth += width;
      } else {
        if (currentGroup != null) {
          groupSpans.add({'group': currentGroup, 'width': currentWidth});
        }
        currentGroup = col.group;
        currentWidth = width;
      }
    }
    if (currentGroup != null) {
      groupSpans.add({'group': currentGroup, 'width': currentWidth});
    }

    return Container(
      height: groupHeight,
      decoration: BoxDecoration(
        color: groupBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: groupSpans.map((span) {
          final String title = span['group'] ?? '';
          final double w = span['width'] as double;

          return Container(
            width: w,
            height: groupHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: prefs.showVerticalGridlines
                  ? Border(right: BorderSide(color: borderColor, width: 0.8))
                  : null,
            ),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: groupFontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderRow(bool isDark, Color borderColor, PangeaTablePreferencesController prefs) {
    Color headerBg;
    Color headerTextColor;

    switch (prefs.headerStyle) {
      case TableHeaderStyle.brandTinted:
        headerBg = widget.brandPrimary.withValues(alpha: isDark ? 0.22 : 0.08);
        headerTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
        break;
      case TableHeaderStyle.darkContrast:
        headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
        headerTextColor = Colors.white;
        break;
      case TableHeaderStyle.minimalist:
        headerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        headerTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
        break;
      case TableHeaderStyle.classic:
        headerBg = isDark ? const Color(0xFF131D31) : const Color(0xFFF1F5F9);
        headerTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
        break;
    }

    final headerHeight = (40.0 * prefs.fontScale).clamp(34.0, 52.0);
    final headerFontSize = (prefs.fontSize * 0.95).clamp(9.5, 14.5);

    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
      ),
      child: Row(
        children: widget.columns.map((col) {
          final width = _getColWidth(col.key);
          final isSorted = _sortColumnKey == col.key;

          return Container(
            width: width,
            height: headerHeight,
            decoration: BoxDecoration(
              border: prefs.showVerticalGridlines
                  ? Border(right: BorderSide(color: borderColor, width: 0.8))
                  : null,
            ),
            child: Stack(
              children: [
                // Header Label + Sort
                InkWell(
                  onTap: col.sortValue != null
                      ? () {
                          setState(() {
                            if (_sortColumnKey == col.key) {
                              _sortAscending = !_sortAscending;
                            } else {
                              _sortColumnKey = col.key;
                              _sortAscending = true;
                            }
                          });
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: _getAlignment(col.align),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: col.align == TextAlign.center
                          ? MainAxisAlignment.center
                          : (col.align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start),
                      children: [
                        Flexible(
                          child: Text(
                            col.label,
                            style: GoogleFonts.inter(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: headerTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSorted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 13,
                            color: widget.brandPrimary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Interactive Mouse Resize Handle
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final current = _getColWidth(col.key);
                          final next = (current + details.delta.dx).clamp(col.minWidth, 650.0);
                          _colWidths[col.key] = next;
                        });
                      },
                      onDoubleTap: () {
                        setState(() {
                          _colWidths[col.key] = col.defaultWidth;
                        });
                      },
                      child: Container(
                        width: 10,
                        height: headerHeight,
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 1.5,
                          height: 18,
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterRow(bool isDark, Color borderColor, PangeaTablePreferencesController prefs) {
    final filterBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final filterHeight = (38.0 * prefs.fontScale).clamp(32.0, 48.0);
    final filterFontSize = (prefs.fontSize * 0.92).clamp(9.0, 13.5);

    return Container(
      height: filterHeight,
      decoration: BoxDecoration(
        color: filterBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: widget.columns.map((col) {
          final width = _getColWidth(col.key);

          // Clear button in first / index column
          if (col.key == 'index' || col.key == '#') {
            final hasActive = _searchFilters.values.any((q) => q.isNotEmpty);
            return Container(
              width: width,
              height: filterHeight,
              decoration: BoxDecoration(
                border: prefs.showVerticalGridlines
                    ? Border(right: BorderSide(color: borderColor, width: 0.8))
                    : null,
              ),
              child: Center(
                child: hasActive
                    ? IconButton(
                        icon: const Icon(Icons.clear_all_rounded, size: 14),
                        tooltip: 'Clear all column filters',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _clearFilters,
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          if (col.searchString == null) {
            return Container(
              width: width,
              height: filterHeight,
              decoration: BoxDecoration(
                border: prefs.showVerticalGridlines
                    ? Border(right: BorderSide(color: borderColor, width: 0.8))
                    : null,
              ),
            );
          }

          final ctrl = _filterControllers.putIfAbsent(col.key, () => TextEditingController());
          final isFiltered = _searchFilters[col.key]?.isNotEmpty ?? false;

          return Container(
            width: width,
            height: filterHeight,
            decoration: BoxDecoration(
              border: prefs.showVerticalGridlines
                  ? Border(right: BorderSide(color: borderColor, width: 0.8))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFiltered ? widget.brandPrimary : borderColor,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: TextField(
                controller: ctrl,
                onChanged: (val) {
                  setState(() {
                    if (val.trim().isEmpty) {
                      _searchFilters.remove(col.key);
                    } else {
                      _searchFilters[col.key] = val.trim();
                    }
                    _currentPage = 0;
                  });
                },
                style: GoogleFonts.inter(fontSize: filterFontSize, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'Filter...',
                  hintStyle: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDataRow(
    T item,
    int rowNumber,
    bool isDark,
    Color borderColor,
    PangeaTablePreferencesController prefs,
  ) {
    final effectiveRowHeight = (widget.rowHeight * prefs.fontScale * prefs.densityFactor).clamp(32.0, 140.0);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(prefs.fontScale),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: prefs.fontSize),
        child: _PangeaExcelDataRow<T>(
          key: ValueKey('row_$rowNumber'),
          item: item,
          rowNumber: rowNumber,
          rowHeight: effectiveRowHeight,
          isDark: isDark,
          borderColor: borderColor,
          brandPrimary: widget.brandPrimary,
          columns: widget.columns,
          getColWidth: _getColWidth,
          getAlignment: _getAlignment,
          onRowTap: widget.onRowTap,
          showVerticalGridlines: prefs.showVerticalGridlines,
          showZebraStriping: prefs.showZebraStriping,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart_outlined, size: 40, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              widget.emptyMessage ?? 'No data matching filter criteria',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (_searchFilters.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_rounded, size: 14),
                label: const Text('Clear All Column Filters'),
                style: TextButton.styleFrom(foregroundColor: widget.brandPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar(
    int pagedCount,
    int filteredCount,
    int totalCount,
    bool isDark,
    Color borderColor,
  ) {
    final isPaginated = widget.enablePagination && _pageSize > 0;
    final totalPages = isPaginated ? (filteredCount / _pageSize).ceil().clamp(1, 9999) : 1;
    final startIndex = isPaginated ? _currentPage * _pageSize : 0;
    final endIndex = isPaginated ? (startIndex + _pageSize).clamp(0, filteredCount) : filteredCount;

    final countString = filteredCount == 0
        ? 'No rows'
        : (isPaginated
            ? 'Showing ${startIndex + 1} to $endIndex of $filteredCount rows'
            : (filteredCount < totalCount
                ? 'Showing $filteredCount of $totalCount rows'
                : 'Showing all $totalCount rows'));

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Row Count Info
            Text(
              countString,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),

            // Pagination Controls (if enabled)
            if (isPaginated && filteredCount > 0) ...[
              const SizedBox(width: 12),
              Container(height: 16, width: 1, color: borderColor),
              const SizedBox(width: 12),
              Text(
                'Per page:',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: const [10, 25, 50, 100, -1].contains(_pageSize) ? _pageSize : 25,
                  isDense: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 100, child: Text('100', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: -1, child: Text('All', style: TextStyle(fontSize: 11.5))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 0;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'First page',
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Previous page',
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = _currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 4),
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Next page',
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = _currentPage + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Last page',
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
              ),
            ],

            const SizedBox(width: 12),
            Container(height: 16, width: 1, color: borderColor),
            const SizedBox(width: 12),

            // Reset Column Widths
            InkWell(
              onTap: _resetAllWidths,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restart_alt_rounded, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Reset Widths',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Table Settings Gear Icon Button on Top Toolbar
            if (widget.showSettingsButton) ...[
              const SizedBox(width: 12),
              Container(height: 16, width: 1, color: borderColor),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Table Settings & Font Scaling',
                child: InkWell(
                  key: const ValueKey('pangea_table_top_settings_gear_btn'),
                  onTap: () => _openSettingsModal(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.brandPrimary.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: widget.brandPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings_outlined, size: 14, color: widget.brandPrimary),
                        const SizedBox(width: 5),
                        Text(
                          'Settings',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (widget.trailingFooterAction != null) ...[
              const SizedBox(width: 14),
              widget.trailingFooterAction!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooterToolbar(
    int pagedCount,
    int filteredCount,
    int totalCount,
    bool isDark,
    Color borderColor,
  ) {
    final isPaginated = widget.enablePagination && _pageSize > 0;
    final totalPages = isPaginated ? (filteredCount / _pageSize).ceil().clamp(1, 9999) : 1;
    final startIndex = isPaginated ? _currentPage * _pageSize : 0;
    final endIndex = isPaginated ? (startIndex + _pageSize).clamp(0, filteredCount) : filteredCount;

    final countString = filteredCount == 0
        ? 'No rows'
        : (isPaginated
            ? 'Showing ${startIndex + 1} to $endIndex of $filteredCount rows'
            : (filteredCount < totalCount
                ? 'Showing $filteredCount of $totalCount rows'
                : 'Showing all $totalCount rows'));

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Row Count Info
            Text(
              countString,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),

            // Pagination Controls (if enabled)
            if (isPaginated && filteredCount > 0) ...[
              const SizedBox(width: 12),
              Container(height: 16, width: 1, color: borderColor),
              const SizedBox(width: 12),
              Text(
                'Per page:',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  isDense: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: 100, child: Text('100', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: -1, child: Text('All', style: TextStyle(fontSize: 11.5))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 0;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'First page',
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Previous page',
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = _currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 4),
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Next page',
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = _currentPage + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Last page',
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
              ),
            ],

            const SizedBox(width: 12),
            Container(height: 16, width: 1, color: borderColor),
            const SizedBox(width: 12),

            // Reset Column Widths
            InkWell(
              onTap: _resetAllWidths,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restart_alt_rounded, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Reset Column Widths',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),
            Text(
              '• Drag column borders to resize • Double-click divider to reset',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: const Color(0xFF94A3B8),
              ),
            ),

            // Table Settings Button (Opens Font Size, Header Style, & Display Settings Modal)
            if (widget.showSettingsButton) ...[
              const SizedBox(width: 12),
              Container(height: 16, width: 1, color: borderColor),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _openSettingsModal(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.brandPrimary.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.brandPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 13, color: widget.brandPrimary),
                      const SizedBox(width: 5),
                      Text(
                        'Settings',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (widget.trailingFooterAction != null) ...[
              const SizedBox(width: 14),
              widget.trailingFooterAction!,
            ],
          ],
        ),
      ),
    );
  }

  Alignment _getAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }
}

class _PangeaExcelDataRow<T> extends StatefulWidget {
  final T item;
  final int rowNumber;
  final double rowHeight;
  final bool isDark;
  final Color borderColor;
  final Color brandPrimary;
  final List<ExcelColumnDef<T>> columns;
  final double Function(String key) getColWidth;
  final Alignment Function(TextAlign align) getAlignment;
  final void Function(T item)? onRowTap;
  final bool showVerticalGridlines;
  final bool showZebraStriping;

  const _PangeaExcelDataRow({
    super.key,
    required this.item,
    required this.rowNumber,
    required this.rowHeight,
    required this.isDark,
    required this.borderColor,
    required this.brandPrimary,
    required this.columns,
    required this.getColWidth,
    required this.getAlignment,
    this.onRowTap,
    this.showVerticalGridlines = true,
    this.showZebraStriping = true,
  });

  @override
  State<_PangeaExcelDataRow<T>> createState() => _PangeaExcelDataRowState<T>();
}

class _PangeaExcelDataRowState<T> extends State<_PangeaExcelDataRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEven = widget.rowNumber % 2 == 0;
    Color rowBg;
    if (_isHovered) {
      rowBg = widget.isDark
          ? widget.brandPrimary.withValues(alpha: 0.12)
          : widget.brandPrimary.withValues(alpha: 0.06);
    } else if (isEven && widget.showZebraStriping) {
      rowBg = widget.isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.5)
          : const Color(0xFFF8FAFC);
    } else {
      rowBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    }

    return MouseRegion(
      cursor: widget.onRowTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onRowTap != null ? () => widget.onRowTap!(widget.item) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.rowHeight,
          decoration: BoxDecoration(
            color: rowBg,
            border: Border(bottom: BorderSide(color: widget.borderColor, width: 0.8)),
          ),
          child: Row(
            children: widget.columns.map((col) {
              final width = widget.getColWidth(col.key);

              return Container(
                width: width,
                height: widget.rowHeight,
                alignment: widget.getAlignment(col.align),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: widget.showVerticalGridlines
                      ? Border(right: BorderSide(color: widget.borderColor, width: 0.8))
                      : null,
                ),
                child: col.cellBuilder(
                  context,
                  widget.item,
                  widget.rowNumber,
                  widget.isDark,
                  widget.brandPrimary,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Modal / Dialog allowing users to personalize font size, header themes, density, and grid lines.
class PangeaTableSettingsModal extends StatelessWidget {
  final Color brandPrimary;

  const PangeaTableSettingsModal({
    super.key,
    this.brandPrimary = const Color(0xFF0D9488),
  });

  static Future<void> show(BuildContext context, {Color brandPrimary = const Color(0xFF0D9488)}) {
    return showDialog(
      context: context,
      builder: (ctx) => PangeaTableSettingsModal(brandPrimary: brandPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prefs = PangeaTablePreferencesController.instance;

    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) {
        final currentFontSize = prefs.fontSize;
        final currentScalePercent = (prefs.fontScale * 100).round();

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: brandPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.tune_rounded, size: 20, color: brandPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Table Display & Typography',
                              style: GoogleFonts.inter(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Real-time personalization across all Excel data tables',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Font Size Progress Slider
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.format_size_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Font Size & Scale',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: brandPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${currentFontSize.toStringAsFixed(1)} px • $currentScalePercent%',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: brandPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Slider with Minus / Plus Steppers
                        Row(
                          children: [
                            IconButton(
                              onPressed: currentFontSize > 10.0
                                  ? () => prefs.setFontSize(currentFontSize - 0.5)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Decrease font size',
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: brandPrimary,
                                  inactiveTrackColor: brandPrimary.withValues(alpha: 0.2),
                                  thumbColor: brandPrimary,
                                  overlayColor: brandPrimary.withValues(alpha: 0.15),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: currentFontSize,
                                  min: 10.0,
                                  max: 16.0,
                                  divisions: 12,
                                  onChanged: (val) => prefs.setFontSize(val),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: currentFontSize < 16.0
                                  ? () => prefs.setFontSize(currentFontSize + 0.5)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Increase font size',
                            ),
                          ],
                        ),

                        // Preset Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildPresetChip('Compact (10.5px)', 10.5, currentFontSize, prefs, brandPrimary),
                            _buildPresetChip('Standard (12.0px)', 12.0, currentFontSize, prefs, brandPrimary),
                            _buildPresetChip('Comfortable (13.5px)', 13.5, currentFontSize, prefs, brandPrimary),
                            _buildPresetChip('Large (15.0px)', 15.0, currentFontSize, prefs, brandPrimary),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Live Preview Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Preview: #ORD-9821 • Respira Detox Tea • 2x • ₦25,000 • Delivered',
                            style: GoogleFonts.inter(
                              fontSize: currentFontSize,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Table Header Style Section
                  Text(
                    'Table Header Style',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildHeaderStyleCard(
                        'Classic Slate',
                        'Balanced corporate slate',
                        TableHeaderStyle.classic,
                        prefs.headerStyle,
                        prefs,
                        brandPrimary,
                        isDark,
                      ),
                      _buildHeaderStyleCard(
                        'Brand Accent',
                        'Vibrant primary theme',
                        TableHeaderStyle.brandTinted,
                        prefs.headerStyle,
                        prefs,
                        brandPrimary,
                        isDark,
                      ),
                      _buildHeaderStyleCard(
                        'Dark Contrast',
                        'High-contrast executive',
                        TableHeaderStyle.darkContrast,
                        prefs.headerStyle,
                        prefs,
                        brandPrimary,
                        isDark,
                      ),
                      _buildHeaderStyleCard(
                        'Clean Minimal',
                        'White clean borderless',
                        TableHeaderStyle.minimalist,
                        prefs.headerStyle,
                        prefs,
                        brandPrimary,
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Density & Grid Controls
                  Text(
                    'Row Density & Gridlines',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDensityButton('Compact', TableDensity.compact, prefs, brandPrimary, isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDensityButton('Standard', TableDensity.standard, prefs, brandPrimary, isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDensityButton('Spacious', TableDensity.spacious, prefs, brandPrimary, isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(
                      'Vertical Column Gridlines',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Renders crisp spreadsheet borders between table columns',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    value: prefs.showVerticalGridlines,
                    activeColor: brandPrimary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) => prefs.setVerticalGridlines(val),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Alternating Row Stripes (Zebra)',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Highlights alternating rows for effortless visual tracking',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    value: prefs.showZebraStriping,
                    activeColor: brandPrimary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (val) => prefs.setZebraStriping(val),
                  ),
                  const SizedBox(height: 18),

                  // Modal Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => prefs.resetToDefaults(),
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Reset to Defaults'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetChip(
    String label,
    double targetSize,
    double currentSize,
    PangeaTablePreferencesController prefs,
    Color brandPrimary,
  ) {
    final isSelected = (currentSize - targetSize).abs() < 0.2;

    return InkWell(
      onTap: () => prefs.setFontSize(targetSize),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? brandPrimary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? brandPrimary : const Color(0xFF64748B).withValues(alpha: 0.3),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? brandPrimary : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStyleCard(
    String title,
    String desc,
    TableHeaderStyle style,
    TableHeaderStyle activeStyle,
    PangeaTablePreferencesController prefs,
    Color brandPrimary,
    bool isDark,
  ) {
    final isSelected = style == activeStyle;

    return InkWell(
      onTap: () => prefs.setHeaderStyle(style),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 245,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? brandPrimary.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? brandPrimary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? brandPrimary : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? brandPrimary : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDensityButton(
    String label,
    TableDensity density,
    PangeaTablePreferencesController prefs,
    Color brandPrimary,
    bool isDark,
  ) {
    final isSelected = prefs.density == density;

    return InkWell(
      onTap: () => prefs.setDensity(density),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? brandPrimary.withValues(alpha: 0.15) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? brandPrimary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? brandPrimary : (isDark ? Colors.white : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
