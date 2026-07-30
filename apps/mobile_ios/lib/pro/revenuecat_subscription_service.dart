import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:castnow_core/core/subscription_service.dart';
import 'revenuecat_config.dart';

class RevenueCatSubscriptionService extends SubscriptionService {
  static final RevenueCatSubscriptionService _instance =
      RevenueCatSubscriptionService._internal();

  factory RevenueCatSubscriptionService() => _instance;

  RevenueCatSubscriptionService._internal();

  List<Package> _products = [];
  Package? _annualPackage;
  StoreProduct? _localStoreProduct;

  List<Package> get products => _products;
  Package? get annualPackage => _annualPackage;
  StoreProduct? get localStoreProduct => _localStoreProduct;

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final hasKey = prefs.containsKey('is_subscribed');
    if (hasKey) {
      setSubscribed(prefs.getBool('is_subscribed') ?? false);
    }

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isIOS || Platform.isMacOS) {
      configuration = PurchasesConfiguration(RevenueCatConfig.appleApiKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      setAvailable(true);
    } else {
      setAvailable(false);
      setError('RevenueCat configuration failed.');
      notifyListeners();
      return;
    }

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updateSubscriptionStatus(customerInfo);
    });

    await loadProducts();

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      await _updateSubscriptionStatus(customerInfo);
    } catch (e) {
      debugPrint('Failed to get initial customer info: $e');
    }
  }

  Future<void> loadProducts() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      Offering? activeOffering = offerings.current;
      if (activeOffering == null && offerings.all.isNotEmpty) {
        activeOffering = offerings.all.values.first;
      }

      if (activeOffering != null) {
        _annualPackage = activeOffering.annual;
        _products = activeOffering.availablePackages;
        if (_annualPackage == null && _products.isNotEmpty) {
          _annualPackage = _products.first;
        }
        if (_products.isEmpty) {
          setError('No products found in the current offering.');
        }
      } else {
        setError('No products found in the current offering.');
      }

      if (_annualPackage == null) {
        try {
          final products =
              await Purchases.getProducts([RevenueCatConfig.entitlementID]);
          if (products.isNotEmpty) {
            _localStoreProduct = products.first;
          }
        } catch (_) {}
      }
    } on PlatformException catch (e) {
      setError(e.message);
      try {
        final products =
            await Purchases.getProducts([RevenueCatConfig.entitlementID]);
        if (products.isNotEmpty) {
          _localStoreProduct = products.first;
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _updateSubscriptionStatus(CustomerInfo customerInfo) async {
    final entitlements = customerInfo.entitlements.all;
    final activeKeys = [
      'pro',
      'com.screenshare.castnow.vip.year',
      'lifetime',
      'yearly',
      'monthly'
    ];
    bool isPremiumActive = false;
    for (var key in activeKeys) {
      if (entitlements[key]?.isActive == true) {
        isPremiumActive = true;
        break;
      }
    }
    if (isPremiumActive) {
      await persistSubscribed(true);
    } else {
      await persistSubscribed(false);
    }
  }

  Future<void> buyYearlySubscription() async {
    setPurchasing(true);
    setError(null);

    final packageToBuy = _annualPackage;
    if (packageToBuy == null) {
      if (_localStoreProduct != null) {
        try {
          PurchaseResult result =
              await Purchases.purchaseStoreProduct(_localStoreProduct!);
          await _updateSubscriptionStatus(result.customerInfo);
        } on PlatformException catch (e) {
          var errorCode = PurchasesErrorHelper.getErrorCode(e);
          if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
            setError(e.message);
          }
        } finally {
          setPurchasing(false);
        }
        return;
      }
      setError('No products available to purchase.');
      setPurchasing(false);
      return;
    }

    try {
      PurchaseResult result = await Purchases.purchasePackage(packageToBuy);
      await _updateSubscriptionStatus(result.customerInfo);
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        setError(e.message);
      }
    } finally {
      setPurchasing(false);
    }
  }

  Future<void> restorePurchases() async {
    setPurchasing(true);
    setError(null);

    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      await _updateSubscriptionStatus(customerInfo);

      final entitlements = customerInfo.entitlements.all;
      bool isPremiumActive =
          (entitlements['pro']?.isActive == true) ||
          (entitlements['com.screenshare.castnow.vip.year']?.isActive == true);
      if (!isPremiumActive) {
        setError('No active subscription found to restore.');
      }
    } on PlatformException catch (e) {
      setError(e.message);
    } finally {
      setPurchasing(false);
    }
  }
}
