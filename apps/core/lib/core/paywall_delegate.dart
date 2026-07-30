import 'package:flutter/material.dart';

typedef ShowPaywallCallback = void Function(BuildContext context);

ShowPaywallCallback? _showPaywall;
VoidCallback? _showCustomerCenter;

void setShowPaywall(ShowPaywallCallback? callback) {
  _showPaywall = callback;
}

void showPaywallIfAvailable(BuildContext context) {
  _showPaywall?.call(context);
}

void setShowCustomerCenter(VoidCallback? callback) {
  _showCustomerCenter = callback;
}

void showCustomerCenterIfAvailable() {
  _showCustomerCenter?.call();
}
