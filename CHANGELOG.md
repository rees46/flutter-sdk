## [1.6.4](https://github.com/rees46/flutter-sdk/compare/v1.6.3...v1.6.4) (2026-11-13)


### Bug Fixes

* **android:** the profile sends the advertising id as google_advertising_id; the API has no advertising_id and dropped it silently ([a12a8af](https://github.com/rees46/flutter-sdk/commit/a12a8af510c50c75bee6b2aeda336b5e35ed241a))
* **sdk:** native Android SDK 2.49.0 and iOS SDK 3.37.3 with the fixes checked against the live API: instant search merchants, push click attribution, profile dates, search filters, timeouts, APNs pushes and subscriptions ([d2b0b3c](https://github.com/rees46/flutter-sdk/commit/d2b0b3c1217af62854296549b0e7479e2668434f))





## [1.6.3](https://github.com/rees46/flutter-sdk/compare/v1.6.2...v1.6.3) (2026-11-12)


### Bug Fixes

* **sdk:** native Android SDK 2.48.0 and iOS SDK 3.37.2 with the fixes from the SDK audit ([585b4de](https://github.com/rees46/flutter-sdk/commit/585b4dee52446efed5f9defa5a0b934770e2911f))
* **sdk:** on Android getProductInfo and getProductsList end in an error when the native call fails, instead of never completing ([04ae29f](https://github.com/rees46/flutter-sdk/commit/04ae29fa5db65df883fde4f45e624ae1057f3d2b))
* **sdk:** on iOS instant search is the native suggest, not the full search, and a category answer carries the facets and the price range ([c059394](https://github.com/rees46/flutter-sdk/commit/c059394e74c43767879a090188c9d16ab4b95dce))
* **sdk:** REES46.initialize no longer leaves a failed native init as an unhandled error; the handle's ready gives its outcome ([5caf286](https://github.com/rees46/flutter-sdk/commit/5caf2869a98f37bdb1b1fb9faa10dbb3d026c554))





## [1.6.2](https://github.com/rees46/flutter-sdk/compare/v1.6.1...v1.6.2) (2026-11-10)


### Bug Fixes

* **ios:** a products list carries its categories on iOS, a listing category keeps its parent on Android, and the plugin asks for notification permission only with autoSendPushToken, as the native SDK does ([5ef2bc6](https://github.com/rees46/flutter-sdk/commit/5ef2bc6d7242f93a311218501e5b347fc6ff27cc))
* **sdk:** native iOS SDK 3.37.1, which keeps the device's A/B segment across launches ([c8dd210](https://github.com/rees46/flutter-sdk/commit/c8dd210567c356f7e7314d4e3443bea3a81177ac))





## [1.6.1](https://github.com/rees46/flutter-sdk/compare/v1.6.0...v1.6.1) (2026-11-10)


### Bug Fixes

* **ios:** the plugin imports the SDK's Category by name instead of qualifying it with the module, so it builds where the module and the SDK's facade enum share a name ([1cf2db7](https://github.com/rees46/flutter-sdk/commit/1cf2db7f5c3ea358e27c047e2d21aa13c3ee2c27))





# [1.6.0](https://github.com/rees46/flutter-sdk/compare/v1.5.0...v1.6.0) (2026-11-09)


### Bug Fixes

* **ios:** products list sends a discount only when there is one ([31b0906](https://github.com/rees46/flutter-sdk/commit/31b0906ead574365f9cc66e8baed86e40e8c6b76))
* **ui:** a discount_percent badge does not take discount_formatted ([59c6db5](https://github.com/rees46/flutter-sdk/commit/59c6db54412feaff99221e6087d34c4734d90bd0))
* **ui:** a request in flight can no longer block its cache key ([50e03fd](https://github.com/rees46/flutter-sdk/commit/50e03fd40956b41fbb17093a94706ee0e049958c))
* **ui:** badge text stays on one line ([185f26c](https://github.com/rees46/flutter-sdk/commit/185f26c7274b40bef29d315a2522ee14b7387530))
* **ui:** cache keys encode params, answers age on a monotonic clock ([8fb7b07](https://github.com/rees46/flutter-sdk/commit/8fb7b07c7d528973f251a4eef4073e59709e9519))
* **ui:** card prices and the narrow list card's button wrap instead of shrinking ([04fb31c](https://github.com/rees46/flutter-sdk/commit/04fb31c76036a2829b7da76a6fa56abf656d1634))
* **ui:** carousel dots are off by default ([f646caf](https://github.com/rees46/flutter-sdk/commit/f646caf06eb2f74f2daf400817702efb00029e9d))
* **ui:** discount badge only for a positive discount ([3564f2f](https://github.com/rees46/flutter-sdk/commit/3564f2f71ea107329b81398d7d4ab014968c08a5))
* **ui:** filters keep the title and buttons in place while sections scroll ([4890257](https://github.com/rees46/flutter-sdk/commit/489025791519b067aecc8318a3c996e4a2a67129))
* **ui:** load controller ignores load, retry and reset after dispose ([5da6069](https://github.com/rees46/flutter-sdk/commit/5da60692fbaf1bfb20f64ec8f162dcfa4bbd475f))
* **ui:** no results count above a failed first page ([a2c886d](https://github.com/rees46/flutter-sdk/commit/a2c886d3bc6b4a1f511c8d3fd2403ff71abbba70))
* **ui:** popups v3 keep to their design in a dark system theme — the consent checkbox takes the form's colors, kit blocks the theme of the popup's background; a link the host opened itself closes the popup without close ([54bfbf9](https://github.com/rees46/flutter-sdk/commit/54bfbf9787aec672eb4aa99beafac5f8f597ad2c))
* **ui:** search results always offer a retry after an error ([f292a7d](https://github.com/rees46/flutter-sdk/commit/f292a7dbdaac5bce9ec8788d428726eb60a186c2))
* **ui:** text blocks stand on y_offset inside the slide area, like polls ([c6e55bf](https://github.com/rees46/flutter-sdk/commit/c6e55bf10c172d26aa8970604f5974578b53d436))


### Features

* **example:** a tic-tac-toe mini-game the link rees46flutter://game (or the native demos' rees46://game) opens from outside, a popup or a story; trigger popups keep off it; [#185](https://github.com/rees46/flutter-sdk/issues/185) in the header's popup menu ([bcca0f9](https://github.com/rees46/flutter-sdk/commit/bcca0f93875eaae3d33945b367bcdfdb694a8526))
* **example:** API, UI Kit and Shop are bottom tabs ([48e6857](https://github.com/rees46/flutter-sdk/commit/48e68579821f324e030037c2e165aaf5d72dc0ff))
* **example:** category runs on the kit's category screen, with sorting and facet titles ([b6c2c86](https://github.com/rees46/flutter-sdk/commit/b6c2c861f5c75d8f4cba24157704ff064fb131f9))
* **example:** demo shop card mapper and add-to-cart helper ([343bf44](https://github.com/rees46/flutter-sdk/commit/343bf446de9aeddb7fd81630b416eb6c3798516a))
* **example:** demo shop category screen with paging and retry ([284c421](https://github.com/rees46/flutter-sdk/commit/284c42162a2f19cdda6cbd39aedb3f69d596c152))
* **example:** demo shop home and its entry on the main page ([540657c](https://github.com/rees46/flutter-sdk/commit/540657c85b548ae107047c8ae7b6412bad3d2ac5))
* **example:** demo shop product screen with similar products ([6c4e459](https://github.com/rees46/flutter-sdk/commit/6c4e459d134c2db117c73275a91ed65c5e070780))
* **example:** demo shop search screen on the kit results screen ([852170d](https://github.com/rees46/flutter-sdk/commit/852170d17ab9a6d861e918ce8ea84ff6d0724afd))
* **example:** live recommender blocks of the demo shop in Blocks ([721cccc](https://github.com/rees46/flutter-sdk/commit/721cccc413c830e58e9e2b5a533b5a06a065a6c3))
* **example:** one shop layout on all platforms, search behind a header button, a header menu shows demo popups by hand ([e96d461](https://github.com/rees46/flutter-sdk/commit/e96d461ab7d7f770bb7dead8e15115b1f0a57df0))
* **example:** popups v3 on in both demos, screens report themselves, popup products open in the shop ([94c78c6](https://github.com/rees46/flutter-sdk/commit/94c78c6bd753b8ca00efde2b1461b8bfce7b6919))
* **example:** product page has the shop's search on top and similar, bought-with and popular blocks ([12a1bb1](https://github.com/rees46/flutter-sdk/commit/12a1bb10fa22d04eedc29e0a9504d95b256bf384))
* **example:** shop home takes its categories from the listing ([fac66dd](https://github.com/rees46/flutter-sdk/commit/fac66ddd81c38a8b303301d6e7a0fc7c7581ed77))
* **example:** shop-only variant, its home stories on API v3 with sharing ([6fe14ae](https://github.com/rees46/flutter-sdk/commit/6fe14ae3acd1bf08ad2621347f298b5619c14d2c))
* **example:** stories V2 polls offline showcase ([14bff3d](https://github.com/rees46/flutter-sdk/commit/14bff3d3b5e56d74f41c03a69664693f48e78e7c))
* **example:** stories V2 with sharing and deep links to a story ([e355f45](https://github.com/rees46/flutter-sdk/commit/e355f4561138cc467e3d0b46622fb5295d97ab77))
* **ios:** bridge passes old price, discount, deeplink and facets ([818f6a1](https://github.com/rees46/flutter-sdk/commit/818f6a1debd5d74b2cb03fbf3580cb3b214b13e4))
* **sdk:** brands, colours and sizes carry product counts, product lists their categories ([024cc6e](https://github.com/rees46/flutter-sdk/commit/024cc6edf3dd2b385cd54cee1b825f5ae3fa987d))
* **sdk:** enableAutoPopupPresentation can be changed at any time, as on iOS and Android, and popups v3 follow it ([244c2bb](https://github.com/rees46/flutter-sdk/commit/244c2bbb5f8806d5ec64cb8fd35a3918d559ecf8))
* **sdk:** getCategory takes brands, locations and facet filters ([2df242f](https://github.com/rees46/flutter-sdk/commit/2df242f1a25b16261907331795e26034b596400c))
* **sdk:** native SDKs Android 2.47.0 and iOS 3.37.0; a category takes a price range and sorting, and the kit's category screen shows both ([bb40bef](https://github.com/rees46/flutter-sdk/commit/bb40befbbab91aeca5d43450840fd2a34e227e2a))
* **sdk:** products get old price, discount, deeplinks and facets ([039809e](https://github.com/rees46/flutter-sdk/commit/039809eddabdd281f0de2c7836cc7ad6f15c9799))
* **ui:** category screen shares the search results core ([3b0f44c](https://github.com/rees46/flutter-sdk/commit/3b0f44ca679773a206f269409b7c2b6158f24a24))
* **ui:** in-memory request cache for the kit's data widgets ([e8c4e2e](https://github.com/rees46/flutter-sdk/commit/e8c4e2e7a30b17d76f44191a309bdfa9a5c8e15b))
* **ui:** load state with retry for the kit's data widgets ([45b36f2](https://github.com/rees46/flutter-sdk/commit/45b36f29b4cec7e9bc425c97b3b038edd350ce2d))
* **ui:** one mapper from SDK products to the kit product ([6c7d374](https://github.com/rees46/flutter-sdk/commit/6c7d374e92ef37440d7429d6ec63a4779544b4ea))
* **ui:** PersonalizationRecommenderBlock loads its own products ([76c1628](https://github.com/rees46/flutter-sdk/commit/76c1628cf4bf989376e7ede1a32db77d7f747b50))
* **ui:** polls on stories V2 slides (API v3) ([0566ac5](https://github.com/rees46/flutter-sdk/commit/0566ac5ca5975114f586803a8f123fa636ed293e))
* **ui:** popups v3 — native rendering of the new popup builder's designs ([f301a7c](https://github.com/rees46/flutter-sdk/commit/f301a7c0ddc3bb698e793ad3450306028c1fb99b))
* **ui:** products block title is optional, rating behind showRating ([5620fb2](https://github.com/rees46/flutter-sdk/commit/5620fb22353b2cb165bc66ab99b7f357e4b88c5e))
* **ui:** request cache can peek a fresh answer synchronously ([4a06e57](https://github.com/rees46/flutter-sdk/commit/4a06e574ccb3992bdf33cafd02509820e1be2e90))
* **ui:** search results show a failed page and retry it ([e18e7f8](https://github.com/rees46/flutter-sdk/commit/e18e7f8461a9d55eea5ec53cf215343427a1eeba))
* **ui:** share link opens the shared slide, product campaigns too ([c590e64](https://github.com/rees46/flutter-sdk/commit/c590e644ad22de1dafa00d9c7e4eb7ab09a38e34))
* **ui:** showRating on the search results screen, off by default ([bf5ac6e](https://github.com/rees46/flutter-sdk/commit/bf5ac6e42374cacd444104ff80cf84ae209ef671))
* **ui:** stories polls restyled to the reference — frosted card, lettered options, results header and vote count ([6ba1549](https://github.com/rees46/flutter-sdk/commit/6ba1549be7d06b59fd616dfabd021c585b8b50da))
* **ui:** stories V2 share button and opening a campaign by link over API v3 ([b47e50c](https://github.com/rees46/flutter-sdk/commit/b47e50c736108b4057cba1881dc435019e0ad717))
* **ui:** the card button of a recommender block sets the source too ([b3dd3bc](https://github.com/rees46/flutter-sdk/commit/b3dd3bc4f890f7f0849e5084f3384a991de4eec3))
* **ui:** the UI kit opens to apps from package:rees46_sdk/rees46_sdk.dart; popups v3 and stories over API v3 move behind their own src barrel ([dcaf5f5](https://github.com/rees46/flutter-sdk/commit/dcaf5f50c27eadd73de759516d4510c16f49ff11))





# [1.5.0](https://github.com/rees46/flutter-sdk/compare/v1.4.0...v1.5.0) (2026-10-27)


### Features

* **popups:** one handler for the popups of every shop, one popup on screen across shops ([8945d3a](https://github.com/rees46/flutter-sdk/commit/8945d3afd89afdc0f372039fb0c593d790696ca8))





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
