# RevenueCat Setup

## Why purchases currently fail

`lib/core/config/api_config.dart` ships a **test** key:

```dart
defaultValue: 'test_PZwqjFJDFOucmHwgoHeAyMquzbG'
```

The `test_` prefix tells the RevenueCat SDK to use its built-in **simulated
test store** — you'll see `SimulatedStorePurchasingData` and `TestStoreProduct`
in the logs. The simulated store returns mock data that the native
`CustomerInfoMapper` cannot fully parse, producing the
`CustomerInfoMapper.kt:28` crash. **The test key cannot complete real Play
Billing purchases.**

## Fix

### 1. Get the real public SDK keys

RevenueCat dashboard → **Project Settings → API Keys**:

- **Android** key starts with `goog_…`
- **iOS** key starts with `appl_…`

These are the *public* SDK keys (safe to ship in the app). Never embed the
secret key (`sk_…`) — it's for the dashboard API only.

### 2. Apply the key

Pick one:

**Option A — build-time override (recommended for CI / release)**

```powershell
flutter run --dart-define=RC_ANDROID_KEY=goog_xxxxxxxxxxxxx
flutter build appbundle --dart-define=RC_ANDROID_KEY=goog_xxxxxxxxxxxxx --dart-define=RC_IOS_KEY=appl_xxxxxxxxxxxxx
```

**Option B — edit the default in `api_config.dart`**

Replace the `defaultValue` strings for `revenueCatAndroidKey` and
`revenueCatIosKey` with your real keys.

### 3. Set up products in the stores

The IDs in `api_config.dart` must match the store-side product IDs exactly:

| Constant | Value | Where to create |
|---|---|---|
| `productMonthly` | `monthly` | Play Console → Monetize → Subscriptions |
| `productYearly` | `yearly` | Play Console → Monetize → Subscriptions |
| `productLifetime` | `lifetime` | Play Console → Monetize → In-app products |

### 4. Wire them in RevenueCat

In the RevenueCat dashboard:

1. **Products** — add the three product IDs above, link to Play Store / App Store
2. **Entitlements** — create an entitlement called `pro` (matches
   `ApiConfig.entitlementPro`), attach all three products to it
3. **Offerings** — create / edit an offering with identifier `default`
   (matches `ApiConfig.offeringId`), add the three packages

### 5. Test on a real device

Real purchases require:

- Signed release-mode build (or internal-testing track on Play Console)
- Tester account added to Play Console → License testing
- Tester signed into the device with that account

The simulated test store does **not** require any of this — which is why the
test key "almost works" in dev but blows up on the mapper. Use a real key
end-to-end as soon as Play Console products are set up.

## Verifying the fix

After applying a real key you should see in logs:

- No more `SimulatedStorePurchasingData` / `TestStoreProduct`
- `Purchases - DEBUG: Vending Offerings from cache` referencing real product
  IDs and real prices
- `purchasePackage` completes with a real `CustomerInfo` and the `pro`
  entitlement flips to active

If `Purchases.getOfferings()` returns null/empty after the key swap, the
products aren't linked in the RC dashboard or aren't active in Play Console
yet.
