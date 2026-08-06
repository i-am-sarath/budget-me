import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP (User Messaging Platform) consent gate for AdMob.
///
/// Required before serving (personalised) ads to users in the EEA/UK and to
/// comply with Google Play's ads policy. Call [gatherConsent] once at startup
/// *before* loading any ad. Outside regulated regions UMP simply returns
/// "not required" and this is a no-op.
class ConsentService {
  ConsentService._();

  /// Requests a consent info update and shows the consent form if one is
  /// required and available. Never throws — ad serving should proceed even if
  /// the consent flow fails (UMP then withholds personalised ads itself).
  static Future<void> gatherConsent() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          // Loads + shows the form only if UMP says consent is required.
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {
          // Ignore — withholding the form just means no personalised ads.
        } finally {
          finish();
        }
      },
      (_) => finish(), // info update failed — proceed without consent
    );

    return completer.future;
  }
}
