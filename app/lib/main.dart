import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'routing/app_router.dart';
import 'theme/theme.dart';

void main() {
  // Configure URL strategy for proper web routing
  usePathUrlStrategy();
  
  runApp(
    const ProviderScope(
      child: BetterSaidApp(),
    ),
  );
}

class BetterSaidApp extends ConsumerWidget {
  const BetterSaidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'BetterSaid',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
