# [0.1.0](https://github.com/rees46/flutter-sdk/compare/v0.0.3...v0.1.0) (2026-07-07)


### Bug Fixes

* display incoming push notifications on Android ([6040922](https://github.com/rees46/flutter-sdk/commit/6040922493acff968292dba43e18083ab757148f))
* **push:** resolve notification small icon from the host app, not REES46 ([5fbb549](https://github.com/rees46/flutter-sdk/commit/5fbb549229fb24a2aa86786b1cce33caa072a207))
* tolerate string-encoded numbers in API response models ([a52c3f1](https://github.com/rees46/flutter-sdk/commit/a52c3f1a193c3775204a114cb127434cc9446c8a))


### Features

* add catalog read methods (profile, product counters, category, collection) ([6014a39](https://github.com/rees46/flutter-sdk/commit/6014a39667c554dad533d0c7836f5ee5d5418d3a))
* add loyalty methods (joinLoyalty, getLoyaltyStatus) ([4199f02](https://github.com/rees46/flutter-sdk/commit/4199f02bc9ef0d5305c9f5aadddfb8d89ac1ee3d))





## 0.0.3

* Fix automated publishing (configure pub.dev OIDC credential in CI).

## 0.0.2

* Add MIT license.

## 0.0.1

* Initial release: Flutter plugin wrapping the REES46 native Android and iOS
  SDKs via a Pigeon bridge.
* APIs: initialization, event tracking, purchase tracking, recommendations,
  product info, products list, blank/instant/full search, profile, and push
  token handling.
