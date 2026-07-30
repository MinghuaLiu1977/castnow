import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:castnow_core/core/constants.dart';
import 'package:castnow_core/core/flavor_config.dart';
import 'package:castnow_core/core/subscription_service.dart';
import 'package:castnow_core/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final subscriptionService = SubscriptionService();

  if (FlavorConfig.isSubscriptionEnabled) {
    subscriptionService.init();
  } else {
    subscriptionService.initAsPaidApp();
  }

  runApp(
    ChangeNotifierProvider.value(
      value: subscriptionService,
      child: const CastNowApp(),
    ),
  );
}

class CastNowApp extends StatelessWidget {
  const CastNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: FlavorConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackgroundColor,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          surface: kSurfaceColor,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

