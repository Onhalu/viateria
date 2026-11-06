# FAPI form return URLs

The sales form must send the buyer back to one of these URLs. The app reads only the query `vandery_plus` (`return`, `success`, or `cancel`). Other parameters are ignored. The URL never unlocks membership.

| Result | URL |
| --- | --- |
| Paid / closed the form after pay | `https://viateria.limitlessdreams.cz/?vandery_plus=return` |
| Buyer cancelled | `https://viateria.limitlessdreams.cz/?vandery_plus=cancel` |
| Mobile app | `com.viateria.viateria://vandery-plus?vandery_plus=return` or `vandery_plus=cancel` |

`return` and `success` both start the verifying poll. `cancel` also polls. The cancelled message is shown only when the server membership is inactive.

Web reads the page URL on load (`VanderyPlusReturnBinding` passes `Uri.base` when `kIsWeb`). Mobile uses `app_links` (`listenForVanderyPlusLinks` in `lib/main.dart`) and accepts only scheme `com.viateria.viateria` and host `vandery-plus`. Coming back to a checkout that is still submitting also polls. Return-link polls are debounced to one refresh per 2 seconds.

`VanderyPlusReturnBinding` is in the app tree and observes `AppLifecycleState.resumed`, which Flutter web emits on visibility/focus. That poll runs only while checkout is still `submitting`.

## What is configured

- Android intent filter: `com.viateria.viateria` host `vandery-plus` in `android/app/src/main/AndroidManifest.xml`. `MainActivity` is `singleTop`. No `autoVerify`.
- iOS custom URL scheme `com.viateria.viateria` is in `ios/Runner/Info.plist` (`CFBundleURLTypes`). `CFBundleURLName` is `com.viateria.viateria`. Host `vandery-plus` and the login callback share that one scheme. There is no second URL type. No associated domains.

## Not needed (Q5, 2026-11-06)

Universal links and Android App Links are not needed. There is no `Runner.entitlements`, no `apple-app-site-association`, and no `assetlinks.json`. The return that opens the app is the custom scheme above.

## UNVERIFIED (E2E-11)

FAPI help (napoveda.fapi.cz, articles 44 and 339, read 2026-11-06) says step 5 can point at a custom page, and the custom thank-you page with the FAPI SDK is described as HTTPS. The docs are silent on a custom scheme, so this is not confirmed. The thank-you page is also described as showing after the order is submitted; card payments may return from the gateway later. Sandbox E2E-11 has not been run: save `com.viateria.viateria://vandery-plus?vandery_plus=return` as the thank-you page, pay with a test card in iOS Safari and Android Chrome, and record whether the app opens.

If the scheme is rejected, the static bounce page in this repo is `web/vandery-plus/return/index.html`. Deploy of that page is Ask first. It is not deployed from this branch.

## Web checkout (open question, not a staging blocker)

One form has one return URL. A web buyer sent to the custom scheme will not land back in the browser. v1 can use the resumed poll above and the bounce page link “Pokračovat na webu”. Open question for Ondřej: is web checkout needed in v1, or is mobile enough?
