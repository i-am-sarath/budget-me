import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:money_pi/core/config/api_config.dart';

bool get _isMobile => Platform.isAndroid || Platform.isIOS;

class AdState {
  final bool isAdLoaded;
  const AdState({this.isAdLoaded = false});
  AdState copyWith({bool? isAdLoaded}) =>
      AdState(isAdLoaded: isAdLoaded ?? this.isAdLoaded);
}

class AdNotifier extends StateNotifier<AdState> {
  RewardedInterstitialAd? _ad;

  AdNotifier() : super(const AdState()) {
    if (_isMobile) _load();
  }

  void _load() {
    RewardedInterstitialAd.load(
      adUnitId: ApiConfig.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          if (mounted) state = state.copyWith(isAdLoaded: true);
        },
        onAdFailedToLoad: (_) {
          if (mounted) state = state.copyWith(isAdLoaded: false);
        },
      ),
    );
  }

  /// Shows the ad. Returns true if shown, false if not ready.
  /// [onRewarded] is called when the user earns the reward.
  Future<bool> show({required VoidCallback onRewarded}) async {
    if (!_isMobile || _ad == null) return false;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        if (mounted) {
          state = state.copyWith(isAdLoaded: false);
          _load();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _ad = null;
        if (mounted) {
          state = state.copyWith(isAdLoaded: false);
          _load();
        }
      },
    );

    await _ad!.show(onUserEarnedReward: (_, __) => onRewarded());
    return true;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }
}

final adProvider = StateNotifierProvider<AdNotifier, AdState>(
  (ref) => AdNotifier(),
);
