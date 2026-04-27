import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:agent_money/core/config/api_config.dart';

// ─────────────────────────────────────────────
// Single source of truth for Pro entitlement.
// Always fetched from RevenueCat, never a local flag.
// Use ref.watch(proStatusProvider) in widgets.
// ─────────────────────────────────────────────

final proStatusProvider = FutureProvider<bool>((ref) async {
  try {
    final CustomerInfo info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(ApiConfig.entitlementPro);
  } catch (_) {
    return false; // fail-safe: treat as free on any error
  }
});

// ─────────────────────────────────────────────
// Convenience extension for one-shot reads
// ─────────────────────────────────────────────

extension ProRef on WidgetRef {
  /// Quick one-shot check. For reactive UI use ref.watch(proStatusProvider).
  Future<bool> get isPro async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(ApiConfig.entitlementPro);
    } catch (_) {
      return false;
    }
  }
}
