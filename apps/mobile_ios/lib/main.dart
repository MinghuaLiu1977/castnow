import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:castnow_core/core/constants.dart';
import 'package:castnow_core/core/flavor_config.dart';
import 'package:castnow_core/core/subscription_service.dart';
import 'package:castnow_core/core/standard_subscription_service.dart';
import 'package:castnow_core/core/paywall_delegate.dart';
import 'package:castnow_core/screens/home_screen.dart';
import 'pro/revenuecat_subscription_service.dart';
import 'pro/paywall_dialog.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final SubscriptionService subscriptionService;
  if (FlavorConfig.isSubscriptionEnabled) {
    subscriptionService = RevenueCatSubscriptionService();
    setShowPaywall((context) {
      showDialog(context: context, builder: (_) => const PaywallDialog());
    });
    setShowCustomerCenter(() {
      RevenueCatUI.presentCustomerCenter();
    });
  } else {
    subscriptionService = StandardSubscriptionService();
  }
  subscriptionService.init();

  runApp(
    ChangeNotifierProvider<SubscriptionService>.value(
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
