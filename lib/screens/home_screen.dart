import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/car.dart';
import 'login_screen.dart';
import 'shop_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import 'record_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

// Temporary note: full file restore in progress via multi-commit.
// See home_final in CI artifacts. Using complete implementation below.

export 'home_screen_full.dart' show HomeScreen;
