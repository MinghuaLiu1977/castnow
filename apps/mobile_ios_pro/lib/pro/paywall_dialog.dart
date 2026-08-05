import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:castnow_core/core/subscription_service.dart';
import 'revenuecat_subscription_service.dart';
import 'package:castnow_core/core/flavor_config.dart';
import 'package:castnow_core/l10n/app_strings.dart';
import 'package:castnow_core/widgets/glass_container.dart';


class PaywallDialog extends StatefulWidget {
  const PaywallDialog({super.key});

  @override
  State<PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends State<PaywallDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackImpression();
    });
  }

  Future<void> _trackImpression() async {
    final subService = context.read<SubscriptionService>() as RevenueCatSubscriptionService;
    final offeringId = subService.annualPackage?.offeringIdentifier ?? 'default';
    
    try {
      // 使用 10.x SDK 官方最新的 Dart 接口直接上报自定义付费墙曝光
      await Purchases.trackCustomPaywallImpression(
        params: CustomPaywallImpressionParams(
          offeringId: offeringId,
        ),
      );
      debugPrint("[PaywallDialog] Showed custom paywall & tracked impression via Dart API: $offeringId");
    } catch (e) {
      debugPrint("[PaywallDialog] Failed to track custom paywall impression: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final subService = context.watch<SubscriptionService>() as RevenueCatSubscriptionService;
    final isLoading = subService.isPurchasing;
    final isSubscribed = subService.isSubscribed;

    if (isSubscribed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      insetPadding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.cyanAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                AppStrings.paywallTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.unlockUnlimitedCasting,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              _buildFeatureRow(Icons.timer_off_rounded, AppStrings.paywallUnlimitedTime),
              _buildFeatureRow(Icons.hd_rounded, AppStrings.hdVideoQuality),
              _buildFeatureRow(Icons.mic_rounded, AppStrings.crystalClearAudio),
              // Plan Duration details
              GlassContainer(
                blurSigma: 4,
                backgroundOpacity: 0.1,
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CastNow VIP - 1 Year",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            AppStrings.premiumPlanDesc,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      subService.annualPackage != null 
                          ? "${subService.annualPackage!.storeProduct.priceString}/yr" 
                          : (subService.localStoreProduct != null
                              ? "${subService.localStoreProduct!.priceString}/yr"
                              : "\$2.99/yr"),
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: Colors.cyanAccent.withOpacity(0.4),
                  ),
                  onPressed: isLoading
                      ? null
                      : () => subService.buyYearlySubscription(),
                    child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          AppStrings.subscribeNow,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: isLoading ? null : () => subService.restorePurchases(),
                child: Text(
                  AppStrings.paywallRestore,
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(0.8),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: Text(
                  AppStrings.maybeLater,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
               Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      try {
                        final Uri uri = Uri.parse("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          // Fallback
                          await launchUrl(uri, mode: LaunchMode.platformDefault);
                        }
                      } catch (e) {
                        debugPrint("Error launching terms EULA: $e");
                      }
                    },
                    child: Text(AppStrings.termsOfUse, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, decoration: TextDecoration.underline, decorationColor: Colors.white.withOpacity(0.4))),
                  ),
                  Text(AppStrings.andConnector, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final Uri uri = Uri.parse("${FlavorConfig.webFullUrl}/privacy.html");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          // Fallback
                          await launchUrl(uri, mode: LaunchMode.platformDefault);
                        }
                      } catch (e) {
                        debugPrint("Error launching privacy: $e");
                      }
                    },
                    child: Text(AppStrings.privacyPolicy, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, decoration: TextDecoration.underline, decorationColor: Colors.white.withOpacity(0.4))),
                  ),
                ],
              )
            ],
          ),
        ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 24),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
