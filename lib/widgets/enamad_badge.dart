import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/brand.dart';

/// نشان اعتماد اینماد + لینک به سایت رسمی
class EnamadBadge extends StatelessWidget {
  final bool compact;

  const EnamadBadge({super.key, this.compact = false});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact ? 72.0 : 96.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          child: InkWell(
            onTap: () => _open(Brand.enamadProfileUrl),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.network(
                Brand.enamadLogoUrl,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: Text(
                      'اینماد',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _open(Brand.websiteUrl),
          icon: const Icon(Icons.language_rounded, size: 18),
          label: const Text('smart-mec.ir'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.secondary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          'نماد اعتماد الکترونیکی',
          style: TextStyle(
            fontSize: 11,
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }
}
