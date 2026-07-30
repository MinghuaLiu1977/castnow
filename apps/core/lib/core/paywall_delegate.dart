import 'package:flutter/material.dart';

typedef ShowPaywallCallback = void Function(BuildContext context);

ShowPaywallCallback? _showPaywall;

void setShowPaywall(ShowPaywallCallback? callback) {
  _showPaywall = callback;
}

void showPaywallIfAvailable(BuildContext context) {
  _showPaywall?.call(context);
}
