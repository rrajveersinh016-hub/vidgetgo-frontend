import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';

import 'presentation/viewmodels/home_viewmodel.dart';
import 'presentation/screens/splash_screen.dart';
import 'main.dart';

class LoopHoleApp extends StatelessWidget {
  const LoopHoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
      ],
      child: MaterialApp(
        title: 'LoopHole',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const SplashScreen(),
      ),
    );
  }
}
