# [0.4.0](https://github.com/rees46/flutter-sdk/compare/v0.3.0...v0.4.0) (2026-09-03)


### Features

* **tracking:** bridge gift_package through to the natives ([f2faec8](https://github.com/rees46/flutter-sdk/commit/f2faec8240da7d7a09fe4f2c3c04d4837aa4b2bd))





# [0.3.0](https://github.com/rees46/flutter-sdk/compare/v0.2.0...v0.3.0) (2026-09-02)


### Bug Fixes

* **ci:** tag only the commit that bumps the version, sync only on release ([6906a03](https://github.com/rees46/flutter-sdk/commit/6906a031038c082cb7bea541e777830f6f694426))
* **tracking:** follow the native namespace rename and widen the source set ([d366b79](https://github.com/rees46/flutter-sdk/commit/d366b7916b2d38f87e20038d40ffffc104e02e34))


### Features

* **tracking:** bridge the standard events to the tracking namespace ([cae82df](https://github.com/rees46/flutter-sdk/commit/cae82df104f584be850487950eec27a39bb6e79e))





# [0.2.0](https://github.com/rees46/flutter-sdk/compare/v0.1.1...v0.2.0) (2026-08-17)


### Features

* **sdk:** multi-instance support — Rees46 facade, shop-aware push, demo ([77670a3](https://github.com/rees46/flutter-sdk/commit/77670a32c43210fda488cc9be3cc0a1e6c77fed5))





## [0.1.1](https://github.com/rees46/flutter-sdk/compare/v0.1.0...v0.1.1) (2026-08-05)


### Bug Fixes

* **ci:** tag from whatever branch the repo calls its trunk ([d8d1c03](https://github.com/rees46/flutter-sdk/commit/d8d1c0388112e8aa28f9916cb88f0dbcc4b7f4e7))





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
