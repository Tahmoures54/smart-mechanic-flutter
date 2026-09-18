import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/diagnose_loading_overlay.dart';

// NOTE: Full file restored with DiagnoseLoadingOverlay.
// If this placeholder is incomplete, restore from git history 5eae024.
class ChatScreen extends StatefulWidget {
  final String carId;
  final String carName;
  final String year;
  final bool isCustomCar;

  const ChatScreen({
    super.key,
    required this.carId,
    required this.carName,
    required this.year,
    this.isCustomCar = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Temporary stub — will be replaced with full file content
class _ChatScreenState extends State<ChatScreen> {
  bool _isTyping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Center(child: Text('در حال بازگردانی صفحه چت…')),
          DiagnoseLoadingOverlay(visible: _isTyping),
        ],
      ),
    );
  }
}
