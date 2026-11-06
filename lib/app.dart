import 'package:flutter/material.dart';

import 'features/app_shell.dart';
import 'theme/app_theme.dart';

class LaundryShopApp extends StatelessWidget {
  const LaundryShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laundry Shop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
