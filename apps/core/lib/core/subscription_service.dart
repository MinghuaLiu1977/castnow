import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SubscriptionService extends ChangeNotifier {
  bool _isSubscribed = false;
  bool _isAvailable = false;
  bool _isPurchasing = false;
  String? _errorMessage;

  static const String _prefIsSubscribedKey = 'is_subscribed';

  bool get isSubscribed => _isSubscribed;
  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;
  String? get errorMessage => _errorMessage;

  void setSubscribed(bool value) {
    _isSubscribed = value;
  }

  void setAvailable(bool value) {
    _isAvailable = value;
  }

  void setPurchasing(bool value) {
    _isPurchasing = value;
    notifyListeners();
  }

  void setError(String? msg) {
    _errorMessage = msg;
  }

  Future<void> init();

  Future<void> persistSubscribed(bool status) async {
    _isSubscribed = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsSubscribedKey, status);
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _isAvailable = false;
    _isSubscribed = false;
    _isPurchasing = false;
    _errorMessage = null;
  }
}
