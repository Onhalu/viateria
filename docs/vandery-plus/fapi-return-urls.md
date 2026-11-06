# FAPI form return URLs

The sales form must send the buyer back to one of these URLs. The app reads the query `vandery_plus`.

| Result | URL |
| --- | --- |
| Paid / closed the form after pay | `https://viateria.limitlessdreams.cz/?vandery_plus=return` |
| Buyer cancelled | `https://viateria.limitlessdreams.cz/?vandery_plus=cancel` |
| Mobile app | `com.viateria.viateria://vandery-plus?vandery_plus=return` or `vandery_plus=cancel` |

`return` and `success` both start the verifying poll. `cancel` does not activate membership.

Web reads the page URL on load. Mobile uses `app_links` (`listenForVanderyPlusLinks` in `lib/main.dart`). Coming back to a checkout that is still submitting also polls.

## What is configured

- Android intent filter: `com.viateria.viateria` host `vandery-plus` in `android/app/src/main/AndroidManifest.xml`.
- iOS custom URL scheme `com.viateria.viateria` is already in `ios/Runner/Info.plist` (`CFBundleURLTypes`). That scheme receives `com.viateria.viateria://vandery-plus?vandery_plus=return`.

## What is missing

iOS associated domains (universal links) are not configured. There is no `Runner.entitlements` with `com.apple.developer.associated-domains`, and this repo does not host `https://viateria.limitlessdreams.cz/.well-known/apple-app-site-association`. An HTTPS return therefore opens the site in the browser, not the app, until that file and the Apple capability exist. Android App Links for the HTTPS host are also not set (`android:autoVerify` and `assetlinks.json` are absent). The custom-scheme return above is the path that opens the app today.
