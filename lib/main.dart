import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: 'https://qexvtratttwkcdxevrdy.supabase.co',
    anonKey: 'sb_publishable_BVCMuBH1r7II6C0bycVXTA_2Er32_Ay',
  );

  await NotificationService.initialize();
  runApp(const ProviderScope(child: LiquidationScannerApp()));
}

class LiquidationScannerApp extends StatelessWidget {
  const LiquidationScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Liquidation Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
