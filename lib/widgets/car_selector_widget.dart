import 'dart:async';
import 'package:flutter/material.dart';
import '../models/car.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── ویجت اصلی ──
// ─────────────────────────────────────────────────────────────────────────────
class CarSelectorWidget extends StatelessWidget {
  final List<Car> cars;
  final Car? selectedCar;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final ValueChanged<Car> onCarSelected;

  const CarSelectorWidget({
    super.key,
    required this.cars,
    required this.selectedCar,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onCarSelected,
  });

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Car>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CarSearchSheet(
        cars: cars,
        selectedCar: selectedCar,
      ),
    );
    if (result != null) {
      onCarSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) return _ShimmerBox(theme: theme);
    if (hasError && cars.isEmpty) return _ErrorBox(onRetry: onRetry, theme: theme);
    if (cars.isEmpty) return _EmptyBox(theme: theme);

    final bool isSelected = selectedCar != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border.all(
              color: isSelected ? theme.colorScheme.secondary.withOpacity(0.6) : theme.dividerColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.secondary.withOpacity(0.12) : theme.dividerColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  color: isSelected ? theme.colorScheme.secondary : theme.hintColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCar?.fullName ?? 'انتخاب یا جستجوی خودرو...',
                      style: TextStyle(
                        color: isSelected ? theme.textTheme.bodyLarge?.color : theme.hintColor,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isSelected && selectedCar!.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        selectedCar!.description,
                        style: TextStyle(color: theme.hintColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.secondary, size: 18)
              else
                Icon(Icons.keyboard_arrow_down_rounded, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Bottom Sheet جستجو ──
// ─────────────────────────────────────────────────────────────────────────────
class _CarSearchSheet extends StatefulWidget {
  final List<Car> cars;
  final Car? selectedCar;

  const _CarSearchSheet({required this.cars, required this.selectedCar});

  @override
  State<_CarSearchSheet> createState() => _CarSearchSheetState();
}

class _CarSearchSheetState extends State<_CarSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Car> _filtered = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filtered = widget.cars;
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // ✅ آپدیت فوری برای نمایش/مخفی دکمه X و شمارش نتایج بدون دابل setState
    final newQuery = _searchCtrl.text;
    if (_query == newQuery) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _applyFilter(newQuery);
    });
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _query = query;
      if (q.isEmpty) {
        _filtered = widget.cars;
      } else {
        _filtered = widget.cars.where((car) {
          return car.fullName.toLowerCase().contains(q) ||
              car.brand.toLowerCase().contains(q) ||
              car.model.toLowerCase().contains(q) ||
              car.engine.toLowerCase().contains(q) ||
              // ✅ اصلاح باگ کرش: استفاده از label برای Enum
              (car.fuelType?.label.toLowerCase().contains(q) ?? false) ||
              (car.transmission?.label.toLowerCase().contains(q) ?? false);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _applyFilter('');
  }

  void _selectCar(Car car) => Navigator.pop(context, car);

  List<Car> get _popularCars => _filtered.where((c) => c.isPopular).toList();
  List<Car> get _regularCars => _filtered.where((c) => !c.isPopular).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: topPad),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(theme),
          _buildHeader(theme),
          _buildSearchField(theme),
          const Divider(height: 1),
          Expanded(child: _buildList(theme)),
        ],
      ),
    );
  }

  Widget _buildHandle(ThemeData theme) => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        height: 4,
        width: 40,
        decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
      );

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          Icon(Icons.directions_car_rounded, color: theme.colorScheme.secondary, size: 22),
          const SizedBox(width: 8),
          Text('انتخاب خودرو', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_query.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_filtered.length} نتیجه',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          hintText: 'جستجو (پراید، دنا، پژو ۲۰۶، ...)',
          hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor),
          suffixIcon: _query.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: _clearSearch)
              : null,
          filled: true,
          fillColor: theme.cardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ✅ استفاده از ListView.builder برای پرفورمنس بهتر
  Widget _buildList(ThemeData theme) {
    if (_filtered.isEmpty) return _buildNoResult(theme);

    final popular = _popularCars;
    final regular = _regularCars;

    // ساخت یک لیست ترکیبی از هدرها و آیتم‌ها برای builder
    final items = <dynamic>[];
    if (popular.isNotEmpty && _query.isEmpty) {
      items.add('⭐ محبوب‌ترین‌ها');
      items.addAll(popular);
      items.add('divider');
      items.add('همه خودروها');
      items.addAll(regular);
    } else {
      items.addAll(_filtered);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is String) {
          if (item == 'divider') return const Divider(height: 8);
          return _buildSectionHeader(item, theme);
        } else if (item is Car) {
          return _buildCarTile(item, theme);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
    );
  }

  Widget _buildCarTile(Car car, ThemeData theme) {
    final isSelected = widget.selectedCar?.id == car.id;
    final query = _query.trim().toLowerCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectCar(car),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.secondary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.secondary.withOpacity(0.15) : theme.cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  color: isSelected ? theme.colorScheme.secondary : theme.hintColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(car.fullName, query, theme, isSelected: isSelected),
                    if (car.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        car.description,
                        style: TextStyle(fontSize: 11, color: theme.hintColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (car.isPopular && _query.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('⭐', style: TextStyle(fontSize: 10)),
                ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.secondary, size: 20)
              else
                Icon(Icons.chevron_left_rounded, color: theme.hintColor.withOpacity(0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, ThemeData theme, {bool isSelected = false}) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.secondary : theme.textTheme.bodyLarge?.color,
        ),
      );
    }

    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx < 0) {
      return Text(text, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: TextStyle(
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.25),
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }

  Widget _buildNoResult(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: theme.hintColor.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'خودرویی با نام "$_query" یافت نشد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.hintColor, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'نام برند یا مدل را به شکل دیگری امتحان کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.hintColor.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─ـ ویجت‌های کمکی ──
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final ThemeData theme;
  const _ShimmerBox({required this.theme});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(widget.theme.cardColor, widget.theme.dividerColor, _anim.value)!;
        return Container(
          height: 56,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;
  final ThemeData theme;
  const _ErrorBox({required this.onRetry, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('خطا در بارگذاری خودروها', style: TextStyle(color: Colors.redAccent, fontSize: 13))),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('تلاش مجدد'),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final ThemeData theme;
  const _EmptyBox({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.hintColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لیست خودروها خالی است. صفحه را بکشید تا دوباره بارگذاری شود.',
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
