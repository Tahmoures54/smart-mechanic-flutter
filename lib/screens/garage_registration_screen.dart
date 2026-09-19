import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../models/garage_registration.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/persian_numbers.dart';

/// ثبت تعمیرگاه و پیگیری چرخهٔ واقعی backend.
///
/// این صفحه فقط وضعیت دریافتی از /api/garages/register را نمایش می‌دهد؛
/// تأیید نهایی و نمایش در چت توسط backend و ادمین انجام می‌شود.
class GarageRegistrationScreen extends StatefulWidget {
  const GarageRegistrationScreen({super.key});

  @override
  State<GarageRegistrationScreen> createState() => _GarageRegistrationScreenState();
}

class _GarageRegistrationScreenState extends State<GarageRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<OwnedGarage> _garages = const [];
  bool _loading = true;
  bool _submitting = false;
  bool _locating = false;
  String? _error;
  String? _message;
  String? _buyingKey;

  ApiService get _api => context.read<ApiService>();
  AuthProvider get _auth => context.read<AuthProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGarages());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _specialtiesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGarages() async {
    final token = _auth.token;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final garages = await _api.getOwnedGarages(token);
      if (!mounted) return;
      setState(() {
        _garages = garages;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'دریافت فهرست تعمیرگاه‌ها ناموفق بود.';
      });
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw const _LocationException('اجازهٔ دسترسی به موقعیت مکانی داده نشد.');
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const _LocationException('موقعیت مکانی دستگاه خاموش است.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    } on _LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'دریافت موقعیت مکانی ناموفق بود. مختصات را دستی وارد کنید.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _register() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = _auth.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'برای ثبت تعمیرگاه ابتدا وارد حساب شوید.');
      return;
    }

    final lat = double.tryParse(normalizeDigits(_latController.text.trim()));
    final lng = double.tryParse(normalizeDigits(_lngController.text.trim()));
    if (lat == null || lng == null) {
      setState(() => _error = 'عرض و طول جغرافیایی را به‌درستی وارد کنید.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });
    try {
      await _api.registerGarage(
        token,
        name: _nameController.text,
        city: _cityController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        lat: lat,
        lng: lng,
        specialties: _specialtiesController.text
            .split(RegExp(r'[,،]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        description: _descriptionController.text,
      );
      _nameController.clear();
      _addressController.clear();
      _specialtiesController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      setState(() => _message = 'تعمیرگاه ثبت شد. برای نمایش در چت، یک پکیج معرفی بخرید.');
      await _loadGarages();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'ثبت تعمیرگاه ناموفق بود.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _buy(OwnedGarage garage, String productId) async {
    final token = _auth.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'برای خرید پکیج ابتدا وارد حساب شوید.');
      return;
    }
    final key = '$productId-${garage.id}';
    setState(() {
      _buyingKey = key;
      _error = null;
    });
    try {
      final url = await _api.getPaymentUrl(token, productId, garageId: garage.id);
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) setState(() => _error = 'صفحهٔ پرداخت باز نشد.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'ساخت لینک پرداخت ناموفق بود.');
    } finally {
      if (mounted) setState(() => _buyingKey = null);
    }
  }

  Future<void> _openWebVersion() async {
    final opened = await launchUrl(
      Uri.parse(Constants.garageRegistrationUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) setState(() => _error = 'نسخهٔ وب باز نشد.');
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: keyboardType == const TextInputType.numberWithOptions(decimal: true)
          ? TextDirection.ltr
          : null,
      decoration: _decoration(label, hint: hint),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'این فیلد الزامی است' : null
          : null,
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ثبت تعمیرگاه', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _field(_nameController, 'نام تعمیرگاه *', required: true),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(_cityController, 'شهر')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_phoneController, 'تلفن', keyboardType: TextInputType.phone)),
                ],
              ),
              const SizedBox(height: 10),
              _field(_addressController, 'آدرس'),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      _latController,
                      'عرض جغرافیایی *',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _lngController,
                      'طول جغرافیایی *',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      required: true,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(_locating ? 'در حال دریافت موقعیت…' : 'استفاده از موقعیت فعلی'),
                ),
              ),
              _field(_specialtiesController, 'تخصص‌ها', hint: 'موتور، برق، جلوبندی'),
              const SizedBox(height: 10),
              _field(_descriptionController, 'توضیحات', maxLines: 3),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _register,
                icon: const Icon(Icons.add_business_rounded),
                label: Text(_submitting ? 'در حال ثبت…' : 'ثبت تعمیرگاه'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGarageCard(OwnedGarage garage, ThemeData theme) {
    final canBuy = garage.chatStatus != 'approved';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.storefront_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(garage.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Chip(label: Text(garage.tierLabel, style: const TextStyle(fontSize: 11))),
              ],
            ),
            if (garage.city != null || garage.address != null) ...[
              const SizedBox(height: 4),
              Text(
                [garage.city, garage.address].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: garage.chatStatus == 'approved'
                    ? Colors.green.withOpacity(0.12)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    garage.chatStatus == 'approved' ? Icons.verified_rounded : Icons.info_outline_rounded,
                    size: 18,
                    color: garage.chatStatus == 'approved' ? Colors.green : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(garage.statusLabel, style: const TextStyle(fontSize: 12.5, height: 1.45))),
                ],
              ),
            ),
            if (canBuy) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _buyingKey == null ? () => _buy(garage, 'garage_silver_30') : null,
                      child: Text(_buyingKey == 'garage_silver_30-${garage.id}' ? '…' : 'نقره‌ای ۳۰ روز'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _buyingKey == null ? () => _buy(garage, 'garage_gold_30') : null,
                      child: Text(_buyingKey == 'garage_gold_30-${garage.id}' ? '…' : 'طلایی ۳۰ روز'),
                    ),
                  ),
                ],
              ),
            ],
            if (garage.chatStatus == 'approved' && garage.showInChat) ...[
              const SizedBox(height: 8),
              const Text('این تعمیرگاه طبق تأیید backend در پیشنهادهای چت قابل نمایش است.',
                  style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuthenticated = _auth.isAuthenticated;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت و معرفی تعمیرگاه'),
        actions: [
          IconButton(
            tooltip: 'نسخه وب',
            onPressed: _openWebVersion,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGarages,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              Text(
                'تعمیرگاه شما فقط پس از خرید پکیج و تأیید ادمین در انتهای پاسخ تشخیص کاربران نمایش داده می‌شود.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 12),
              if (!isAuthenticated)
                Card(
                  color: theme.colorScheme.errorContainer.withOpacity(0.45),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('برای ثبت تعمیرگاه باید ابتدا وارد حساب کاربری شوید.'),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                _MessageBox(text: _error!, error: true),
              ],
              if (_message != null) ...[
                const SizedBox(height: 8),
                _MessageBox(text: _message!),
              ],
              if (isAuthenticated) ...[
                const SizedBox(height: 8),
                _buildForm(theme),
                const SizedBox(height: 18),
                Text('تعمیرگاه‌های من', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (_garages.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('هنوز تعمیرگاهی ثبت نکرده‌اید.')))
                else
                  ..._garages.map((garage) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildGarageCard(garage, theme),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? Theme.of(context).colorScheme.error : Colors.green;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12.5, height: 1.45)),
    );
  }
}

class _LocationException implements Exception {
  const _LocationException(this.message);
  final String message;
}
