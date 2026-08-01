import 'dart:io';

enum AppFlavor { pro, standard }

class FlavorConfig {
  static AppFlavor _flavor = AppFlavor.pro;

  static void init(AppFlavor flavor) {
    _flavor = flavor;
  }

  static AppFlavor get flavor => _flavor;

  static bool get isPro => flavor == AppFlavor.pro;
  static bool get isStandard => flavor == AppFlavor.standard;

  static String get appDisplayName {
    return isPro ? 'CastNow Pro' : 'CastNow';
  }

  static String get appTitle {
    return isPro ? 'CastNow Pro - Screen Cast' : 'CastNow - Screen Cast';
  }

  static String get bundleIdBase {
    return 'com.eastlakestudio.castnow';
  }

  static String get bundleId {
    return isPro ? '$bundleIdBase.pro' : bundleIdBase;
  }

  static String get broadcastExtensionId {
    return isPro
        ? '$bundleIdBase.pro.BroadcastExtension'
        : '$bundleIdBase.BroadcastExtension';
  }

  static String get appGroupId {
    return isPro
        ? 'group.$bundleIdBase.pro'
        : 'group.castnow.app';
  }

  static bool get isSubscriptionEnabled => isPro;

  static String get webBaseUrl {
    return isPro ? 'castnow.vercel.app' : 'castnow.padap.cn';
  }

  static String get webFullUrl {
    return 'https://$webBaseUrl';
  }
}
