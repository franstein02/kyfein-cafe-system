import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/pos/providers/pos_provider.dart';
import 'features/master_data/providers/master_data_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/notifications/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://psdeyhujegvaczqyozbz.supabase.co',
    publishableKey: 'sb_publishable_-uzUI0ciD9S5VJTr-NHeCA_IWZb-eHe',
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const KyfeinApp());
}

class KyfeinApp extends StatelessWidget {
  const KyfeinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProxyProvider<AuthProvider, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, auth, dashboard) => dashboard!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PosProvider>(
          create: (_) => PosProvider(),
          update: (_, auth, pos) => pos!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MasterDataProvider>(
          create: (_) => MasterDataProvider(),
          update: (_, auth, master) => master!..updateAuth(auth),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final textTheme = GoogleFonts.outfitTextTheme(
            Theme.of(context).textTheme,
          );
          return MaterialApp(
            title: 'Kyfein POS & Operations System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(textTheme: textTheme),
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: auth.isLoading
                ? const _SplashScreen()
                : auth.isAuthenticated
                    ? const DashboardScreen()
                    : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1B4332),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coffee, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Kyfein',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
