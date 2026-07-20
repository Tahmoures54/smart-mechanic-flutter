import 'package:flutter/material.dart';
import '../models/car.dart';

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

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // برای مدیریت بالا آمدن کیبورد
      backgroundColor: Colors.transparent,
      builder: (context) => _CarSearchSheet(
        cars: cars,
        selectedCar: selectedCar,
        onCarSelected: (car) {
          onCarSelected(car);
          Navigator.pop(context); // بستن پنل بعد از انتخاب
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Container(
        height: 60,
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError && cars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('خطا در بارگذاری خودروها', style: TextStyle(color: Colors.redAccent, fontSize: 13))),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تلاش مجدد'),
              onPressed: onRetry,
            )
          ],
        ),
      );
    }

    if (cars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Text(
          'هیچ خودرویی یافت نشد.\nبرای بارگذاری مجدد، صفحه را به پایین بکشید.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.hintColor),
        ),
      );
    }

    // 👈 دکمه شیک در صفحه اصلی (جایگزین کامبوباکس)
    return InkWell(
      onTap: () => _showSearchSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border.all(
            color: selectedCar == null ? theme.dividerColor : theme.colorScheme.secondary.withOpacity(0.5),
            width: selectedCar == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.directions_car_rounded,
              color: selectedCar == null ? theme.hintColor : theme.colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedCar?.fullName ?? 'برای جستجو و انتخاب خودرو ضربه بزنید...',
                style: TextStyle(
                  color: selectedCar == null ? theme.hintColor : theme.textTheme.bodyLarge?.color,
                  fontSize: 15,
                  fontWeight: selectedCar == null ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.search_rounded, color: theme.hintColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ==============================================================
// پنل کشویی جستجوی خودرو (مخفی از صفحه اصلی)
// ==============================================================
class _CarSearchSheet extends StatefulWidget {
  final List<Car> cars;
  final Car? selectedCar;
  final ValueChanged<Car> onCarSelected;

  const _CarSearchSheet({
    required this.cars,
    required this.selectedCar,
    required this.onCarSelected,
  });

  @override
  State<_CarSearchSheet> createState() => _CarSearchSheetState();
}

class _CarSearchSheetState extends State<_CarSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Car> _filteredCars = [];

  @override
  void initState() {
    super.initState();
    _filteredCars = widget.cars;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCars(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredCars = widget.cars;
      } else {
        _filteredCars = widget.cars
            .where((car) => car.fullName.toLowerCase().contains(query.trim().toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // محاسبه فضای کیبورد برای اینکه پنل روی کیبورد نیفتد
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight),
      padding: EdgeInsets.only(bottom: bottomInset), // هماهنگی با کیبورد
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // خط کوچک بالای پنل
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // نوار جستجو
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true, // کیبورد خودکار باز می‌شود
              onChanged: _filterCars,
              decoration: InputDecoration(
                hintText: 'جستجوی مدل خودرو (مثلاً ۲۰۶، دنا)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _filterCars('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const Divider(),
          
          // لیست نتایج جستجو
          Expanded(
            child: _filteredCars.isEmpty
                ? Center(
                    child: Text('خودرویی با این نام یافت نشد.', style: TextStyle(color: theme.hintColor)),
                  )
                : ListView.builder(
                    itemCount: _filteredCars.length,
                    itemBuilder: (context, index) {
                      final car = _filteredCars[index];
                      final isSelected = widget.selectedCar?.id == car.id;
                      
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.secondary.withOpacity(0.2) : theme.cardColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.directions_car,
                            color: isSelected ? theme.colorScheme.secondary : theme.hintColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          car.fullName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? theme.colorScheme.secondary : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.secondary) : null,
                        onTap: () => widget.onCarSelected(car),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
