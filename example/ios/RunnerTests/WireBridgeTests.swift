import Flutter
import XCTest

@_spi(Bridge) @testable import REES46
@_spi(Bridge) @testable import rees46_sdk

/// The models the native SDK answers with, as the wire Dart reads, and what Dart sends as the native
/// requests: field for field, enum values as their wire values, free-form values as standard codec
/// values. A field dropped or renamed here never reaches Dart, so each conversion is pinned.
final class WireBridgeTests: XCTestCase {

    // MARK: - Products

    func test_product_carriesEveryFieldOfTheContract() {
        let wire = Self.product(id: "37").toWire()

        XCTAssertEqual(wire.id, "37")
        XCTAssertEqual(wire.groupId, "g-37")
        XCTAssertEqual(wire.name, "Phone")
        XCTAssertEqual(wire.brand, "Acme")
        XCTAssertEqual(wire.model, "X1")
        XCTAssertEqual(wire.description, "A phone")
        XCTAssertEqual(wire.barcode, "4600000000000")
        XCTAssertEqual(wire.url, "https://shop.test/37")
        XCTAssertEqual(wire.deeplinkAndroid, "app://android/37")
        XCTAssertEqual(wire.deeplinkIos, "app://ios/37")
        XCTAssertEqual(wire.imageUrl, "https://img.test/37.jpg")
        XCTAssertEqual(wire.picture, "https://img.test/37-180.jpg")
        XCTAssertEqual(wire.resizedImages, ["120": "https://img.test/37-120.jpg"])
        XCTAssertEqual(wire.price, 1990)
        XCTAssertEqual(wire.priceFormatted, "1 990 ₽")
        XCTAssertEqual(wire.priceFull, 1990.5)
        XCTAssertEqual(wire.priceFullFormatted, "1 990,50 ₽")
        XCTAssertEqual(wire.oldPrice, 2490)
        XCTAssertEqual(wire.oldPriceFormatted, "2 490 ₽")
        XCTAssertEqual(wire.oldPriceFull, 2490.5)
        XCTAssertEqual(wire.oldPriceFullFormatted, "2 490,50 ₽")
        XCTAssertEqual(wire.currency, "RUB")
        XCTAssertEqual(wire.discountPercent, 20)
        XCTAssertEqual(wire.discountFormatted, "20%")
        XCTAssertEqual(wire.salesRate, 75)
        XCTAssertEqual(wire.relativeSalesRate, 0.4)
        XCTAssertEqual(wire.rating, 4)
        XCTAssertEqual(wire.isNew, true)
        XCTAssertEqual(wire.stockQuantity, 12)
        XCTAssertEqual(wire.categoryIds, ["7"])
        XCTAssertEqual(wire.categories?.first?.id, "7")
        XCTAssertEqual(wire.categories?.first?.parentId, "1")
        XCTAssertEqual(wire.categories?.first?.level, 2)
        XCTAssertEqual(wire.params?.first?.key, "Цвет")
        XCTAssertEqual(wire.params?.first?.values, ["Чёрный"])
        XCTAssertEqual(wire.locationIds, ["global"])
    }

    func test_productWithoutOptionalFields_leavesThemNil() {
        let bare = Rees46.Product(
            id: "1", groupId: nil, name: "n", brand: nil, model: nil, description: nil, barcode: nil,
            url: "u", deeplinkAndroid: nil, deeplinkIos: nil, imageUrl: nil, picture: nil, resizedImages: nil,
            price: 1, priceFormatted: nil, priceFull: nil, priceFullFormatted: nil, oldPrice: nil,
            oldPriceFormatted: nil, oldPriceFull: nil, oldPriceFullFormatted: nil, currency: "RUB",
            discountPercent: nil, discountFormatted: nil, salesRate: nil, relativeSalesRate: nil, rating: nil,
            isNew: false, stockQuantity: nil, categoryIds: nil, categories: nil, params: nil, locationIds: nil
        )

        let wire = bare.toWire()

        XCTAssertNil(wire.oldPrice, "no old price is nil, not 0")
        XCTAssertNil(wire.brand)
        XCTAssertNil(wire.categories)
        XCTAssertFalse(wire.isNew)
    }

    func test_listing_carriesFacetsPriceIntervalsAndBrands() {
        let response = Rees46.ProductsListResponse(
            productsTotal: 2,
            products: [Self.product(id: "1")],
            categories: [Rees46.ProductCategory(id: "7", name: "Обувь", url: nil, parentId: nil, level: nil, count: 2, alias: "shoes")],
            brands: [Rees46.Brand(name: "Acme", count: 2)],
            locations: [Rees46.Location(id: "msk", name: "Москва", type: "city")],
            filters: ["Цвет": Rees46.SearchFilter(count: 2, priority: 1, values: ["Красный": 2], min: nil, max: nil)],
            industrialFilters: Rees46.IndustrialFilters(
                colors: [Rees46.ColorFilter(color: "red", count: 1)],
                fashionSizes: [Rees46.SizeFilter(size: "M", count: 1)]
            ),
            priceRange: Rees46.PriceRange(min: 100, max: 900),
            priceRanges: [Rees46.PriceInterval(from: 0, to: 500, count: 1)],
            priceMedian: 450
        )

        let wire = response.toWire()

        XCTAssertEqual(wire.productsTotal, 2)
        XCTAssertEqual(wire.products.map(\.id), ["1"])
        XCTAssertEqual(wire.categories?.first?.count, 2)
        XCTAssertEqual(wire.categories?.first?.alias, "shoes")
        XCTAssertEqual(wire.brands?.first?.name, "Acme")
        XCTAssertEqual(wire.brands?.first?.count, 2)
        XCTAssertEqual(wire.locations?.first?.type, "city")
        XCTAssertEqual(wire.filters?["Цвет"]?.values, ["Красный": 2])
        XCTAssertEqual(wire.filters?["Цвет"]?.priority, 1)
        XCTAssertEqual(wire.industrialFilters?.colors?.first?.color, "red")
        XCTAssertEqual(wire.industrialFilters?.fashionSizes?.first?.size, "M")
        XCTAssertEqual(wire.priceRange?.min, 100)
        XCTAssertEqual(wire.priceRange?.max, 900)
        XCTAssertEqual(wire.priceRanges?.first?.to, 500)
        XCTAssertEqual(wire.priceMedian, 450)
    }

    func test_category_goesOverTheWireOfAListing() {
        let response = Rees46.CategoryResponse(
            productsTotal: 1,
            products: [Self.product(id: "1")],
            categories: nil,
            brands: [Rees46.Brand(name: "Acme", count: 1)],
            filters: nil,
            priceRange: Rees46.PriceRange(min: 1, max: 2),
            priceRanges: nil,
            priceMedian: 1.5
        )

        let wire = response.toWire()

        XCTAssertEqual(wire.productsTotal, 1)
        XCTAssertEqual(wire.brands?.first?.count, 1)
        XCTAssertNil(wire.locations)
        XCTAssertNil(wire.industrialFilters)
        XCTAssertEqual(wire.priceMedian, 1.5)
    }

    // MARK: - Search agent

    func test_agentMessage_roleIsTheWireValue_andAMissingIdStaysMissing() {
        let message = Rees46.AgentMessage(
            id: nil, role: .assistant, content: "Вот", createdAt: "2026-11-18T10:00:00Z",
            products: [Rees46.AgentProduct(
                id: "1", name: "n", price: 10, oldPrice: nil, priceFormatted: "10", oldPriceFormatted: nil,
                picture: nil, url: "u", reason: "fits"
            )]
        )

        let wire = message.toWire()

        XCTAssertNil(wire.id, "the contract's id is nullable: no 0 for a missing one")
        XCTAssertEqual(wire.role, "assistant")
        XCTAssertEqual(wire.products.first?.reason, "fits")
    }

    // MARK: - Profile, loyalty, reviews

    func test_profile_gendersAreWireValues_andCustomPropertiesStandardValues() {
        let profile = Rees46.Profile(
            id: "c-1",
            hasEmail: true,
            emailRegisteredAt: "2026-01-01 10:00:00",
            gender: .female,
            computedGender: .male,
            boughtSomething: false,
            customProperties: [
                "flag": NSNumber(value: true),
                "count": NSNumber(value: 3),
                "ratio": NSNumber(value: 0.5),
                "none": NSNull(),
                "tags": ["a", NSNull()] as [Any],
                "nested": ["k": "v"] as [String: Any],
            ]
        )

        let wire = profile.toWire()

        XCTAssertEqual(wire.gender, "f")
        XCTAssertEqual(wire.computedGender, "m")
        let custom = wire.customProperties ?? [:]
        XCTAssertEqual(custom["flag"] as? Bool, true)
        XCTAssertEqual(custom["count"] as? Int64, 3)
        XCTAssertEqual(custom["ratio"] as? Double, 0.5)
        XCTAssertNotNil(custom.index(forKey: "none"))
        XCTAssertNil(custom["none"] ?? nil, "NSNull goes as nil")
        let tags = (custom["tags"] ?? nil) as? [Any?]
        XCTAssertEqual(tags?.first as? String, "a")
        XCTAssertNil(tags?.last ?? nil)
        XCTAssertEqual(((custom["nested"] ?? nil) as? [String: Any?])?["k"] as? String, "v")
    }

    /// The contract: a level without a code is no level (the base level), not one coded "".
    func test_loyaltyStatus_levelWithoutCode_isNoLevel() {
        var level = LoyaltyLevel(json: [:])
        level.name = "Gold"
        let wire = LoyaltyStatus(isMember: true, level: level).toWire()

        XCTAssertTrue(wire.isMember)
        XCTAssertNil(wire.level)
    }

    func test_promotionAndReview_enumsAreWireValues() {
        let promotion = LoyaltyPromotion(
            id: 9_000_000_000, name: "Promo", description: nil, startDate: nil, finishDate: nil,
            stream: nil, badgeLabel: nil, badgeColor: nil, rewardType: .bonusesEarn
        )
        let review = ClientReview(
            id: 5, itemId: "37", orderId: "o-1", rating: 5, comment: nil, state: .published,
            createdAt: "2026-11-18T00:00:00Z"
        )

        XCTAssertEqual(promotion.toWire().id, 9_000_000_000, "64-bit ids survive")
        XCTAssertEqual(promotion.toWire().rewardType, "bonuses_earn")
        XCTAssertEqual(review.toWire().state, "published")
    }

    func test_ratingSummary_keysAreTheStars() {
        let summary = ProductRatingSummary(count: 3, averageRating: 4.3, ratings: [5: 2, 3: 1])

        let wire = summary.toWire()

        XCTAssertEqual(wire.ratings, [5: 2, 3: 1])
        XCTAssertEqual(wire.averageRating, 4.3)
    }

    // MARK: - Orders

    func test_order_carriesItsItemsAndTheProductOfEach() {
        let order = Order(json: [
            "_id": 11,
            "id": "o-1",
            "date": "2026-11-18",
            "value": "69990.0",
            "tax_free": true,
            "items": [[
                "amount": 2,
                "price": "34995.0",
                "item": ["id": "37", "name": "Phone", "url": "https://shop.test/37", "price": 34995.0, "currency": "RUB"],
            ]],
        ])

        let wire = order.toWire()

        XCTAssertEqual(wire.id, "o-1")
        XCTAssertEqual(wire.value, "69990.0")
        XCTAssertEqual(wire.taxFree, true)
        XCTAssertEqual(wire.items.first?.amount, 2)
        XCTAssertEqual(wire.items.first?.price, "34995.0")
        XCTAssertEqual(wire.items.first?.item?.id, "37")
        XCTAssertEqual(wire.items.first?.item?.currency, "RUB")
        XCTAssertNil(wire.items.first?.item?.oldPrice, "the older model's 0 is no old price")
    }

    // MARK: - Stories

    func test_storyElements_eachKindItsOwnFields() {
        let product = StoryProduct(
            id: "1", name: "n", brand: "b", picture: "p", imageUrl: "i", price: 10, priceFormatted: "10",
            oldPrice: nil, oldPriceFormatted: "", discountPercent: 0, promocode: "", priceWithPromocode: 0,
            priceWithPromocodeFormatted: "", currency: "RUB", url: "u", deeplinkAndroid: "", deeplinkIos: ""
        )
        let slide = StorySlide(
            id: "s-1", type: .video, background: "bg", backgroundColor: "#fff", preview: "pv", duration: 7,
            elements: [
                .button(StoryButtonElement(title: "Go", link: "l", linkAndroid: "la", linkIos: "li", background: "#000", color: "#fff", textBold: true)),
                .product(StoryProductElement(title: "One", item: product)),
                .products(StoryProductsElement(showLabel: "Show", hideLabel: "Hide", products: [product])),
                .textBlock(StoryTextBlockElement(
                    text: "Hi", fontSize: 14, fontType: "sans", bold: true, italic: false, textAlign: "center",
                    textColor: "#000", backgroundColor: "#fff", backgroundOpacity: 0.5, lineSpacing: 1.2,
                    yOffset: 10, promocode: "CODE"
                )),
            ]
        )

        let wire = slide.toWire()

        XCTAssertEqual(wire.type, "video")
        XCTAssertEqual(wire.duration, 7)
        XCTAssertEqual(wire.elements.map(\.type), ["button", "product", "products", "text_block"])
        XCTAssertEqual(wire.elements[0].linkIos, "li")
        XCTAssertEqual(wire.elements[0].textBold, true)
        XCTAssertNil(wire.elements[0].text)
        XCTAssertEqual(wire.elements[1].item?.id, "1")
        XCTAssertEqual(wire.elements[2].hideLabel, "Hide")
        XCTAssertEqual(wire.elements[2].products?.count, 1)
        XCTAssertEqual(wire.elements[3].promocode, "CODE")
        XCTAssertEqual(wire.elements[3].backgroundOpacity, 0.5)
    }

    // MARK: - Pushes

    func test_pushPayload_carriesItsTargetAndActions() {
        let payload = Rees46.PushPayload(
            shopId: "shop", code: "c-1", type: "bulk", title: "T", body: "B", icon: nil, image: "img",
            actions: [Rees46.PushAction(id: "open", title: "Open", url: "https://shop.test")],
            target: Rees46.PushTarget(type: .product, uri: "37", payload: ["n": NSNumber(value: 1)]),
            source: "utm", sound: nil, data: ["id": "c-1", "type": "bulk"]
        )

        let wire = payload.toWire()

        XCTAssertEqual(wire.shopId, "shop")
        XCTAssertEqual(wire.code, "c-1")
        XCTAssertEqual(wire.actions.first?.url, "https://shop.test")
        XCTAssertEqual(wire.target?.type, "product")
        XCTAssertEqual(wire.target?.payload["n"] as? Int64, 1)
        XCTAssertEqual(wire.data["type"] as? String, "bulk")
        XCTAssertEqual(Rees46.PushToken(token: "t", provider: .fcm).toWire().provider, "fcm")
    }

    // MARK: - Notification history

    /// The history as the server sends it: the answer's status, and each message's channel, numeric
    /// campaign id and one statistics object under snake-case keys — what Android hands Dart.
    func test_notificationHistory_carriesStatusChannelCampaignAndStatistics() {
        let answer: [String: Any] = [
            "status": "success",
            "payload": ["messages": [[
                "type": "bulk", "code": "c-1", "date": "2026-11-01", "sent_at": "2026-11-01T10:00:00Z",
                "subject": "Sale", "body": "Up to 50%", "url": "https://shop.test/sale",
                "icon": "https://img.test/i.png", "picture": "https://img.test/p.png",
                "campaign_id": 4217, "channel": "email",
                "statistics": [
                    "opened": true, "clicked": true, "hard_bounced": false, "soft_bounced": true,
                    "complained": false, "unsubscribed": false, "purchased": true,
                ],
            ]]],
        ]

        let wire = UserPayloadResponse(json: answer).toWire()

        XCTAssertEqual(wire.status, "success")
        XCTAssertEqual(wire.messages.count, 1)
        let message = wire.messages[0]
        XCTAssertEqual(message.campaignId, 4217)
        XCTAssertEqual(message.channel, "email")
        XCTAssertEqual(message.type, "bulk")
        XCTAssertEqual(message.code, "c-1")
        XCTAssertEqual(message.date, "2026-11-01")
        XCTAssertEqual(message.sentAt, "2026-11-01T10:00:00Z")
        XCTAssertEqual(message.subject, "Sale")
        XCTAssertEqual(message.body, "Up to 50%")
        XCTAssertEqual(message.url, "https://shop.test/sale")
        XCTAssertEqual(message.icon, "https://img.test/i.png")
        XCTAssertEqual(message.picture, "https://img.test/p.png")
        let statistics = message.statistics
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics?.opened, true)
        XCTAssertEqual(statistics?.clicked, true)
        XCTAssertEqual(statistics?.hardBounced, false)
        XCTAssertEqual(statistics?.softBounced, true)
        XCTAssertEqual(statistics?.complained, false)
        XCTAssertEqual(statistics?.unsubscribed, false)
        XCTAssertEqual(statistics?.purchased, true)
    }

    /// A message without channel, campaign id or statistics leaves them nil; a statistics field the
    /// answer does not have is `false`, as on Android.
    func test_notificationHistory_whatTheAnswerLacksIsNilOrFalse() {
        let answer: [String: Any] = [
            "payload": ["messages": [
                ["type": "chain", "code": "c-2"],
                ["type": "chain", "code": "c-3", "campaign_id": "not a number", "statistics": ["opened": true]],
            ]],
        ]

        let wire = UserPayloadResponse(json: answer).toWire()

        XCTAssertNil(wire.status)
        XCTAssertNil(wire.messages[0].channel)
        XCTAssertNil(wire.messages[0].campaignId)
        XCTAssertNil(wire.messages[0].statistics)
        XCTAssertNil(wire.messages[0].subject, "an empty field of the native model is nil")
        XCTAssertNil(wire.messages[1].campaignId)
        XCTAssertEqual(wire.messages[1].statistics?.opened, true)
        XCTAssertEqual(wire.messages[1].statistics?.clicked, false)
        XCTAssertEqual(wire.messages[1].statistics?.purchased, false)
    }

    // MARK: - Requests

    func test_listingRequest_takesEveryField() throws {
        let wire = ProductsListRequestWire(
            categoryIds: ["7"], brands: ["Acme"], merchants: ["m"], locations: ["msk"], priceMin: 1,
            priceMax: 2, filters: ["Цвет": ["red"]], sortBy: "price", sortDir: "desc", limit: 10, page: 2
        )

        let native = try wire.native()
        let category = try wire.nativeCategory()

        XCTAssertEqual(native.categoryIds, ["7"])
        XCTAssertEqual(native.merchants, ["m"])
        XCTAssertEqual(native.filters, ["Цвет": ["red"]])
        XCTAssertEqual(native.sortBy, .price)
        XCTAssertEqual(native.sortDir, .desc)
        XCTAssertEqual(native.limit, 10)
        XCTAssertEqual(category.brands, ["Acme"])
        XCTAssertEqual(category.page, 2)
    }

    func test_anUnknownSortDirectionOrGender_isAnInvalidArgument() {
        XCTAssertThrowsError(try ProductsListRequestWire(sortDir: "up").native()) { error in
            XCTAssertEqual(BridgeFailure.error(error).code, "invalidArgument")
        }
        XCTAssertThrowsError(try ProfileUpdateRequestWire(gender: "x").native()) { error in
            XCTAssertEqual(BridgeFailure.error(error).code, "invalidArgument")
        }
        XCTAssertThrowsError(try nativePushProvider("gcm"))
        XCTAssertEqual(try nativeGender("m"), .male)
        XCTAssertEqual(try nativePushProvider("apns"), .apns)
    }

    func test_profileRequest_kidsCarsAndCustomProperties() throws {
        let wire = ProfileUpdateRequestWire(
            email: "a@b.test", gender: "f", age: 30,
            kids: [ProfileKidWire(gender: "m", birthday: "2020-01-01")],
            cars: [ProfileCarWire(brand: "Lada", model: "Vesta", vds: "x")],
            customProperties: ["size": "M", "nested": ["deep": nil] as [String: Any?], "none": nil]
        )

        let native = try wire.native()

        XCTAssertEqual(native.email, "a@b.test")
        XCTAssertEqual(native.gender, .female)
        XCTAssertEqual(native.age, 30)
        XCTAssertEqual(native.kids?.first?.gender, .male)
        XCTAssertEqual(native.cars?.first?.model, "Vesta")
        XCTAssertEqual(native.customProperties?["size"] as? String, "M")
        XCTAssertTrue(native.customProperties?["none"] is NSNull)
        XCTAssertTrue((native.customProperties?["nested"] as? [String: Any])?["deep"] is NSNull)
    }

    func test_searchAndRecommendationRequests() throws {
        let search = try SearchFullRequestWire(
            excludedMerchants: ["m"], colors: ["red"], disableClarification: true, brandLimit: 3, page: 1
        ).native()
        let recommendation = try RecommendationRequestWire(
            itemId: "37", locations: ["msk"], limit: 5, extended: false, withLocations: true
        ).native()

        XCTAssertEqual(search.excludedMerchants, ["m"])
        XCTAssertTrue(search.disableClarification)
        XCTAssertEqual(search.brandLimit, 3)
        XCTAssertEqual(recommendation.itemId, "37")
        XCTAssertFalse(recommendation.extended)
        XCTAssertTrue(recommendation.withLocations)
    }

    func test_subscriptionRequest_takesEveryChannel() {
        let native = SubscriptionsUpdateRequestWire(email: "a@b.test", walletChain: true, walletTransactional: false).native

        XCTAssertEqual(native.email, "a@b.test")
        XCTAssertEqual(native.walletChain, true)
        XCTAssertEqual(native.walletTransactional, false)
        XCTAssertNil(native.smsBulk)
    }

    func test_dartInts_reachTheNativeSdkWhole() {
        XCTAssertEqual(try nativeInt(5), 5)
        XCTAssertEqual(try nativeInt(Int64.max), Int.max)
    }

    // MARK: - Errors

    func test_httpError_carriesItsCodes() {
        let error = BridgeFailure.error(Rees46.SdkError.http(code: 404, serverCode: "not_found"))

        XCTAssertEqual(error.code, "http")
        XCTAssertEqual(error.message, "HTTP 404")
        let details = error.details as? [String: Any?]
        XCTAssertEqual(details?["httpCode"] as? Int, 404)
        XCTAssertEqual(details?["serverCode"] as? String, "not_found")
    }

    func test_everyErrorType_isItsContractName() {
        let cases: [(Rees46.SdkError, String)] = [
            (.notInitialized, "notInitialized"), (.shopBlocked, "shopBlocked"),
            (.invalidArgument("x"), "invalidArgument"), (.network, "network"), (.timeout, "timeout"),
            (.decoding, "decoding"), (.cancelled, "cancelled"),
        ]
        for (native, name) in cases {
            let error = BridgeFailure.error(native)
            XCTAssertEqual(error.code, name)
            let details = error.details as? [String: Any?]
            XCTAssertNil(details?["httpCode"] ?? nil)
            XCTAssertNotNil(details?.index(forKey: "httpCode"), "both keys go, null when not http")
        }
    }

    func test_oldErrors_becomeTheNewCoresTypes() {
        XCTAssertEqual(BridgeFailure.error(legacy: .networkOfflineError).code, "network")
        XCTAssertEqual(BridgeFailure.error(legacy: .decodeError).code, "decoding")
        XCTAssertEqual(BridgeFailure.error(legacy: .custom(error: "empty itemId")).code, "invalidArgument")
    }

    func test_anUnexpectedError_isDecoding() {
        struct Odd: Error {}

        XCTAssertEqual(BridgeFailure.error(Odd()).code, "decoding")
        XCTAssertEqual(BridgeFailure.error(BridgeFailure.invalidArgument("x")).code, "invalidArgument")
    }

    // MARK: - Fixtures

    private static func product(id: String) -> Rees46.Product {
        Rees46.Product(
            id: id, groupId: "g-\(id)", name: "Phone", brand: "Acme", model: "X1", description: "A phone",
            barcode: "4600000000000", url: "https://shop.test/\(id)", deeplinkAndroid: "app://android/\(id)",
            deeplinkIos: "app://ios/\(id)", imageUrl: "https://img.test/\(id).jpg",
            picture: "https://img.test/\(id)-180.jpg", resizedImages: ["120": "https://img.test/\(id)-120.jpg"],
            price: 1990, priceFormatted: "1 990 ₽", priceFull: 1990.5, priceFullFormatted: "1 990,50 ₽",
            oldPrice: 2490, oldPriceFormatted: "2 490 ₽", oldPriceFull: 2490.5,
            oldPriceFullFormatted: "2 490,50 ₽", currency: "RUB", discountPercent: 20, discountFormatted: "20%",
            salesRate: 75, relativeSalesRate: 0.4, rating: 4, isNew: true, stockQuantity: 12, categoryIds: ["7"],
            categories: [Rees46.ProductCategory(id: "7", name: "Phones", url: nil, parentId: "1", level: 2, count: nil, alias: nil)],
            params: [Rees46.ProductParam(key: "Цвет", values: ["Чёрный"])],
            locationIds: ["global"]
        )
    }
}
