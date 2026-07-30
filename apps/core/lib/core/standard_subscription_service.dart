import 'subscription_service.dart';

class StandardSubscriptionService extends SubscriptionService {
  @override
  Future<void> init() async {
    await persistSubscribed(true);
  }
}
