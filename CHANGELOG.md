# [1.4.0](https://github.com/rees46/flutter-sdk/compare/v1.3.0...v1.4.0) (2026-10-26)


### Bug Fixes

* **ios:** native SDK 3.36.1 ([0590a08](https://github.com/rees46/flutter-sdk/commit/0590a08a978c82082b9f0b09851b29e83464dfcd))


### Features

* **ios:** plugin builds through Swift Package Manager ([cd86a05](https://github.com/rees46/flutter-sdk/commit/cd86a05f4ed2d48ddf2e031a55c8637428a8533b))





# [1.3.0](https://github.com/rees46/flutter-sdk/compare/v1.2.1...v1.3.0) (2026-10-20)


### Bug Fixes

* **android:** native SDK v2.45.0 ([4bf0666](https://github.com/rees46/flutter-sdk/commit/4bf0666f109fce095f4b5273d41010cf136262ba))


### Features

* **popups:** server popups over the root navigator, configurable UI theme ([ca28cd8](https://github.com/rees46/flutter-sdk/commit/ca28cd809f31b07929a62c9728a3f8f0430f89c5))





## [1.2.1](https://github.com/rees46/flutter-sdk/compare/v1.2.0...v1.2.1) (2026-10-15)


### Bug Fixes

* **android:** native SDK v2.42.0 ([80868b6](https://github.com/rees46/flutter-sdk/commit/80868b6eb1a3198a301cf7377f315b343626f5b5))





# [1.2.0](https://github.com/rees46/flutter-sdk/compare/v1.1.0...v1.2.0) (2026-10-14)


### Bug Fixes

* **android:** enableAutoPopupPresentation reaches the native SDK ([3e1f2c3](https://github.com/rees46/flutter-sdk/commit/3e1f2c3d758bcbd290723589db25e44389fc7ae7))
* **android:** full search returns the server response whole ([bfd52fa](https://github.com/rees46/flutter-sdk/commit/bfd52fa4f7eeddf1b04c19ef1c46e3446fee5bf5))
* **deps:** build against Android SDK 2.39.0 and iOS SDK 3.34.0 ([07af627](https://github.com/rees46/flutter-sdk/commit/07af627b80b376a4db67119160af1c1dafeeb71d))
* **ios:** a search page becomes the right offset ([1efc10d](https://github.com/rees46/flutter-sdk/commit/1efc10de489121898ad09ec4e00f276d7121fabf))
* **ui:** a carousel product closes the stories viewer with the sheet open ([644e6b7](https://github.com/rees46/flutter-sdk/commit/644e6b7d31856b1b527edb4b4ed9d2a1691e9cd0))
* **ui:** a stories button without a link keeps the viewer open ([f672df4](https://github.com/rees46/flutter-sdk/commit/f672df4dc24381d487e804b48ffdc4728d02a789))
* **ui:** a stories controller handed to a loaded block runs its queued open ([653b383](https://github.com/rees46/flutter-sdk/commit/653b383688ad8e45fed8c60aec08300b87dbc790))
* **ui:** a story restart seeks only a ready video ([3e6b9b6](https://github.com/rees46/flutter-sdk/commit/3e6b9b688fd727597573715c5cb040598843a512))
* **ui:** a viewed story's ring is solid ([ddc7db7](https://github.com/rees46/flutter-sdk/commit/ddc7db734d75c35878a01d0e27affecbe267bb53))
* **ui:** cards in a row share a baseline, loader replaces count and load more, dark fallback ([e3f38d9](https://github.com/rees46/flutter-sdk/commit/e3f38d991bb7ed500cb3d78cde4d14fd20eb3189))
* **ui:** filter edits survive a rebuild of the results screen ([c7639b7](https://github.com/rees46/flutter-sdk/commit/c7639b70276ceaa055cdd211dcf87f58b9608b6d))
* **ui:** follow the design file — button radii, LG height, input fill, loader slot ([17c3203](https://github.com/rees46/flutter-sdk/commit/17c3203a6380e618bbf4911a533521dab3416f87)), closes [#F2F2F2](https://github.com/rees46/flutter-sdk/issues/F2F2F2)
* **ui:** in-app popup cross, buttons and shadow as in the finished design ([9208d03](https://github.com/rees46/flutter-sdk/commit/9208d031a1449906ded36e601b11e1ab4bf54e7e))
* **ui:** restarting a story slide keeps its media and tracking ([bc5fbed](https://github.com/rees46/flutter-sdk/commit/bc5fbed8017425247d90323d62992368f5092792))
* **ui:** search results show "no results" only when there are none ([ed98135](https://github.com/rees46/flutter-sdk/commit/ed981356b672b3951251992c2bf48aa67192556b))
* **ui:** ship the icon assets from the package root so they bundle ([f433825](https://github.com/rees46/flutter-sdk/commit/f4338257cc56047132db3ce1f4b023bd8484932b))
* **ui:** stories controller queues open, turns the open viewer, waits for the SDK ([ece5bdc](https://github.com/rees46/flutter-sdk/commit/ece5bdcd05be5babe29d11edf9115dae41ce55f8))
* **ui:** stories drop promoToastPosition, the toast is always on top ([e6af726](https://github.com/rees46/flutter-sdk/commit/e6af726fd1377046048cd9f07b71f805a2da58bd))
* **ui:** stories readiness and retry timers freeze in the background ([fe0c4db](https://github.com/rees46/flutter-sdk/commit/fe0c4dbf532ee6078daf6a88e10c013bfe7db62a))
* **ui:** stories seen slides read back over the bridge without a failing cast ([a97de07](https://github.com/rees46/flutter-sdk/commit/a97de07befcd4f1c9e792104d64922bbfcfeb3f0))
* **ui:** stories show() reports an empty block ([f7a0164](https://github.com/rees46/flutter-sdk/commit/f7a0164c96a8b195bc9500063cdcd673a3fe42a1))
* **ui:** stories v2 drop repeated story ids ([97cb2e3](https://github.com/rees46/flutter-sdk/commit/97cb2e3be80d04eb8a3295dcbcb3f8d8b5bc8eee))
* **ui:** stories v2 follow the shared rules ([30763a3](https://github.com/rees46/flutter-sdk/commit/30763a32324fb8e65c2d10b43013a4cd7e5a341d)), closes [#1A1A1](https://github.com/rees46/flutter-sdk/issues/1A1A1)
* **ui:** stories v2 product card shows the promo code of the slide's text block ([edfd13f](https://github.com/rees46/flutter-sdk/commit/edfd13f0a90794ae7c5c8080f6ec560cf22efeb9))
* **ui:** stories v2 product picture no longer opens the product, taps on it page the story ([17936b4](https://github.com/rees46/flutter-sdk/commit/17936b4deac00d84078c0479179a141b598cdbdc))
* **ui:** stories video plays from the network while the cache fills ([e8a8102](https://github.com/rees46/flutter-sdk/commit/e8a8102eaac5c0f0798efa1b7d2c1f67a07ce008))
* **ui:** story text line spacing follows the nearest preset ([3bb7d34](https://github.com/rees46/flutter-sdk/commit/3bb7d34a908e8f657ad1b11a2ed20f0b4ab3284c))
* **ui:** the stories cross closes the viewer with the sheet open ([054d81b](https://github.com/rees46/flutter-sdk/commit/054d81b153183a2e42d50b647b61c74afde47636))
* **ui:** the stories sound button names the current sound state ([792baf4](https://github.com/rees46/flutter-sdk/commit/792baf4ef352fc024de3fa0733ab1b7121825ef7))
* **ui:** tokens follow the design file's variables again ([7ab98d5](https://github.com/rees46/flutter-sdk/commit/7ab98d573b621c4b2ca5d277b286985d1947c540)), closes [#F2F2F2](https://github.com/rees46/flutter-sdk/issues/F2F2F2) [#0D0D0](https://github.com/rees46/flutter-sdk/issues/0D0D0) [#1A1A1](https://github.com/rees46/flutter-sdk/issues/1A1A1) [#0D0D0](https://github.com/rees46/flutter-sdk/issues/0D0D0)


### Features

* **example:** appearance switch on the UI Kit screen ([7eb2b16](https://github.com/rees46/flutter-sdk/commit/7eb2b16f7ea8b8967fddfaafd12c5535f57896ea))
* **example:** catalogue empty state in the UI Kit pane ([4d97609](https://github.com/rees46/flutter-sdk/commit/4d97609e4ec9fd9a1b9603a2e7e9b8eb47b29dbd))
* **example:** catalogue exhibits laid out whole in the showcase scroll ([744586a](https://github.com/rees46/flutter-sdk/commit/744586a90715467e76ce706d0d91bee7848911b5))
* **example:** category suggestions with pictures in the instant search exhibit ([4542c49](https://github.com/rees46/flutter-sdk/commit/4542c491a2cc1775c7e3ad0433e1d7990baab081))
* **example:** dark theme wired, bundled photos, category title on the catalogue ([8e5f97b](https://github.com/rees46/flutter-sdk/commit/8e5f97b9125fd293ebc72b4dcdd311f7c1147abd))
* **example:** fullscreen in-app popup exhibits ([4027a0e](https://github.com/rees46/flutter-sdk/commit/4027a0e20e68e4c289f9d284143b8d38d505e516))
* **example:** in-app popup exhibits ([a275b21](https://github.com/rees46/flutter-sdk/commit/a275b21ea698d8aab2b8f60fda2fbbd5e372f557))
* **example:** instant search states, filters screen, card aspects in the UI Kit screen ([09f028f](https://github.com/rees46/flutter-sdk/commit/09f028f5e44c798f047629a5a647071a00a1148e))
* **example:** search tab running the live search widgets ([99a776d](https://github.com/rees46/flutter-sdk/commit/99a776dac09dfbf6d50f62c1f510978e014d5005))
* **example:** stories v2 exhibits ([cc894be](https://github.com/rees46/flutter-sdk/commit/cc894be973a9bad19825dd2c9f18cf29c1f20231))
* **example:** stories v2 round-2 exhibits ([a76ef3c](https://github.com/rees46/flutter-sdk/commit/a76ef3c2259f7c2475bc0f4aa15611c690975a38))
* **example:** stories v2 sample block with a gif story and a cover bar ([e9a5cf5](https://github.com/rees46/flutter-sdk/commit/e9a5cf58cfdf38b33850bcce2381db70c3b8784d))
* **example:** stories v2 sample product slide carries a text block promo ([32c5134](https://github.com/rees46/flutter-sdk/commit/32c51349b42313e3c839f966b40c5cae68fd9c05))
* **example:** toast and loyalty card exhibits ([9231598](https://github.com/rees46/flutter-sdk/commit/9231598fe8a21afe5592bd8017619c1493f4ff7d))
* **example:** UI Kit screen shows the design system's components and blocks ([5710346](https://github.com/rees46/flutter-sdk/commit/57103467f8495b91f00d555b7a5c9db5b0642617))
* **search:** facets, suggested queries, old price and discount through the bridge ([138cfb7](https://github.com/rees46/flutter-sdk/commit/138cfb7827dc73db2dcf3c0f9c7bb11d743995de))
* **stories:** block data through the bridge ([8672f2e](https://github.com/rees46/flutter-sdk/commit/8672f2ea1ce86b6a9aeceafdac405814c31a5d27))
* **stories:** seen slides, cache dir and audio session through the bridge ([e730f86](https://github.com/rees46/flutter-sdk/commit/e730f86fa0297ef9659b493ec65059fb723e346c))
* **ui:** card tap, product tap passthrough, title button toggles, rows without images ([971d4cc](https://github.com/rees46/flutter-sdk/commit/971d4cc834204b35bc5c5b1c24b39fed26a6171b))
* **ui:** design system tokens and base components ([2da82f1](https://github.com/rees46/flutter-sdk/commit/2da82f1ae42087e9a0da6253a25e2d34e816c7d6))
* **ui:** empty state in the catalogue ([48e833b](https://github.com/rees46/flutter-sdk/commit/48e833bdeecf186190c64e9f3a802da0045cee4e))
* **ui:** in-app popup widget ([e157e90](https://github.com/rees46/flutter-sdk/commit/e157e90f63f3ca0280a354db5f89ebf9388a2f61))
* **ui:** instant search and filters screens, text link ([6cb4a4d](https://github.com/rees46/flutter-sdk/commit/6cb4a4d128195ea0c4a54c8973ae58f76656d518))
* **ui:** instant search field and search results screen bound to the SDK ([c0f50a7](https://github.com/rees46/flutter-sdk/commit/c0f50a7a7959340703bf23ff07f7bbde1c6720f6))
* **ui:** keep the design system out of the package barrel until release ([0ce2708](https://github.com/rees46/flutter-sdk/commit/0ce2708664100a75d725188e417f24341a3daec8))
* **ui:** PersonalizationTheme extension so a host can rebrand the design system ([9833d40](https://github.com/rees46/flutter-sdk/commit/9833d40d0fc221dd5e9891c8cc2d6bae3d594de7))
* **ui:** price bounds as placeholders in the search filters ([7bdd4a3](https://github.com/rees46/flutter-sdk/commit/7bdd4a342277e4d6d4c628dac8a955d597df957f))
* **ui:** product card follows the image aspect, carousel old price 16/24 ([a35f351](https://github.com/rees46/flutter-sdk/commit/a35f35141e02a2aa3597a211624c634ae78f277c))
* **ui:** product card, product image and favorites badge ([6c41f9a](https://github.com/rees46/flutter-sdk/commit/6c41f9ab1bec275e98e965d5909bd4a868244c4a)), closes [#E51919](https://github.com/rees46/flutter-sdk/issues/E51919)
* **ui:** product lists and recommender block ([e8046f6](https://github.com/rees46/flutter-sdk/commit/e8046f6f6562ae9b4a9652a128da2e4ee5cde595))
* **ui:** search suggestions and catalogue screen, plus the arrow-rotate-cw icon ([609172c](https://github.com/rees46/flutter-sdk/commit/609172c1a3f96dfbe33500945efb97eb657b0e1e))
* **ui:** stories playback state machine ([023cffa](https://github.com/rees46/flutter-sdk/commit/023cffa8cf7e8afe6fff5bc153c80653316cdf9d))
* **ui:** stories seen store and sound state ([fd1bdae](https://github.com/rees46/flutter-sdk/commit/fd1bdaeeead90b08288516f64a9e969ce6ab715b))
* **ui:** stories v2 components ([d813ac1](https://github.com/rees46/flutter-sdk/commit/d813ac155e0208a7857b920032e57cff4f08f837))
* **ui:** stories v2 loads images itself, a gif off the slide stays on its first frame ([0b84eac](https://github.com/rees46/flutter-sdk/commit/0b84eac3014176cf79ee261e5c7acdd194ef6df2))
* **ui:** stories v2 plays gif slides for at least one loop and pauses them with the slide ([c324d27](https://github.com/rees46/flutter-sdk/commit/c324d279facf51730c4b38583f77f9049eead284))
* **ui:** stories v2 reads gif frame delays and loop length ([debbfd8](https://github.com/rees46/flutter-sdk/commit/debbfd854cae5ec51e92669acb3499d87717e4c0))
* **ui:** stories v2 viewer and widget ([973cddd](https://github.com/rees46/flutter-sdk/commit/973cddd1c7fd4ac075e3186d47532bd174301436))
* **ui:** stories v2 viewer and widget on the shared rules ([75ee846](https://github.com/rees46/flutter-sdk/commit/75ee846b5eb743ab4fe6fcba4e10159b12b41911))
* **ui:** toast and loyalty card ([2439d65](https://github.com/rees46/flutter-sdk/commit/2439d65312e956fb2a2d73fa9c0400a334f53bf5))
* **ui:** video cache for stories ([50721ac](https://github.com/rees46/flutter-sdk/commit/50721ac89b5b8b8270083aac3d5c1614540d11b2))


### Performance Improvements

* **ui:** the catalogue builds only the cards on screen ([6151cac](https://github.com/rees46/flutter-sdk/commit/6151cacf1a7198609e81c59289806790b9283795))





# [1.1.0](https://github.com/rees46/flutter-sdk/compare/v1.0.0...v1.1.0) (2026-10-14)


### Features

* **subscriptions:** manage subscriptions for every channel ([abaa645](https://github.com/rees46/flutter-sdk/commit/abaa6457e13c6de90ae7dfacbf2ce603d3679987))





# [1.0.0](https://github.com/rees46/flutter-sdk/compare/v0.4.0...v1.0.0) (2026-09-07)


### Bug Fixes

* **tracking:** let syncCart and syncFavorites report an empty collection ([a4b54aa](https://github.com/rees46/flutter-sdk/commit/a4b54aaf17624782c0a4264544a0e59a8b46de95))


* refactor(sdk)!: spell the facade REES46 ([d6678d6](https://github.com/rees46/flutter-sdk/commit/d6678d669727b8cd996034ad642fcd0ea87b41b8))


### BREAKING CHANGES

* `Rees46` and friends are now `REES46`.





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
