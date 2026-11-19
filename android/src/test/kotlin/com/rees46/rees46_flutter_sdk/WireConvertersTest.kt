package com.rees46.rees46_flutter_sdk

import com.personalization.api.models.loyalty.LoyaltyLevel
import com.personalization.api.models.loyalty.LoyaltyPromotion
import com.personalization.api.models.loyalty.LoyaltyRewardType
import com.personalization.api.models.loyalty.LoyaltyStatus
import com.personalization.api.models.products.CategoryResponse
import com.personalization.api.models.products.PriceInterval
import com.personalization.api.models.products.Product
import com.personalization.api.models.products.ProductCategory
import com.personalization.api.models.products.ProductsListResponse
import com.personalization.api.models.products.SearchFilter
import com.personalization.api.models.profile.Gender
import com.personalization.api.models.profile.Profile
import com.personalization.api.models.recommendations.RecommendationResponse
import com.personalization.api.models.search.AgentMessage
import com.personalization.api.models.search.AgentMessageRole
import com.personalization.api.models.search.AgentProduct
import com.personalization.api.models.search.AgentResponse
import com.personalization.api.models.search.AgentSession
import com.personalization.api.models.search.Query
import com.personalization.api.models.search.SearchBlankResponse
import com.personalization.api.models.search.SearchRedirect
import com.personalization.api.models.search.SearchInstantResponse
import com.personalization.api.models.segments.Segment
import com.personalization.api.models.sliders.Slider
import com.personalization.api.models.sliders.SliderBanner
import com.personalization.api.models.stories.StoriesBlock
import com.personalization.api.models.stories.Story
import com.personalization.api.models.stories.StoryButtonElement
import com.personalization.api.models.stories.StoryProduct
import com.personalization.api.models.stories.StoryProductElement
import com.personalization.api.models.stories.StoryProductsElement
import com.personalization.api.models.stories.StorySlide
import com.personalization.api.models.stories.StorySlideType
import com.personalization.api.models.stories.StoryTextBlockElement
import com.personalization.api.models.subscriptions.SubscriptionStatus
import com.personalization.api.responses.cart.CartItem
import com.personalization.api.responses.orders.Order
import com.personalization.api.responses.orders.OrderItem
import com.personalization.api.responses.products.counters.ProductCounter
import com.personalization.api.responses.products.counters.ProductCountersResponse
import com.personalization.api.responses.products.product.ProductParam
import com.personalization.api.responses.reviews.ClientReview
import com.personalization.api.responses.reviews.ProductRatingSummary
import com.personalization.api.responses.reviews.ProductReview
import com.personalization.api.responses.reviews.ProductReviewsResponse
import com.personalization.api.responses.reviews.ReviewState
import com.personalization.api.responses.search.Brand
import com.personalization.api.responses.search.ColorFilter
import com.personalization.api.responses.search.IndustrialFilters
import com.personalization.api.responses.search.Location
import com.personalization.api.responses.search.PopularItem
import com.personalization.api.responses.search.PriceRange
import com.personalization.api.responses.search.SizeFilter
import org.json.JSONArray
import org.json.JSONObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The native models reach Dart field for field, by the contract's names, whole numbers as `Long`. */
internal class WireConvertersTest {

    private val product = Product(
        id = "37",
        groupId = "g-1",
        name = "Phone",
        brand = "Acme",
        model = "X1",
        description = "A phone",
        barcode = "4600000000000",
        url = "https://shop.test/37",
        deeplinkAndroid = "app://37",
        deeplinkIos = "ios://37",
        imageUrl = "https://img.test/37.jpg",
        picture = "https://img.test/37-180.jpg",
        resizedImages = mapOf("120" to "https://img.test/37-120.jpg"),
        price = 19990.0,
        priceFormatted = "19 990 ₽",
        priceFull = 19990.5,
        priceFullFormatted = "19 990,50 ₽",
        oldPrice = 24990.0,
        oldPriceFormatted = "24 990 ₽",
        oldPriceFull = 24990.5,
        oldPriceFullFormatted = "24 990,50 ₽",
        currency = "₽",
        discountPercent = 20,
        discountFormatted = "20%",
        salesRate = 73,
        relativeSalesRate = 0.8,
        rating = 4,
        isNew = true,
        stockQuantity = 12,
        categoryIds = listOf("c1"),
        categories = listOf(ProductCategory(id = "c1", name = "Phones", url = "/c1", parentId = "c0", level = 2)),
        params = listOf(ProductParam(key = "Color", values = listOf("Black"))),
        locationIds = listOf("msk"),
    )

    @Test
    fun aProductCarriesEveryFieldOfTheContract() {
        val wire = product.toWire()

        assertEquals("37", wire.id)
        assertEquals("g-1", wire.groupId)
        assertEquals("Phone", wire.name)
        assertEquals("Acme", wire.brand)
        assertEquals("X1", wire.model)
        assertEquals("A phone", wire.description)
        assertEquals("4600000000000", wire.barcode)
        assertEquals("https://shop.test/37", wire.url)
        assertEquals("app://37", wire.deeplinkAndroid)
        assertEquals("ios://37", wire.deeplinkIos)
        assertEquals("https://img.test/37.jpg", wire.imageUrl)
        assertEquals("https://img.test/37-180.jpg", wire.picture)
        assertEquals(mapOf("120" to "https://img.test/37-120.jpg"), wire.resizedImages)
        assertEquals(19990.0, wire.price)
        assertEquals("19 990 ₽", wire.priceFormatted)
        assertEquals(19990.5, wire.priceFull)
        assertEquals("19 990,50 ₽", wire.priceFullFormatted)
        assertEquals(24990.0, wire.oldPrice)
        assertEquals("24 990 ₽", wire.oldPriceFormatted)
        assertEquals(24990.5, wire.oldPriceFull)
        assertEquals("24 990,50 ₽", wire.oldPriceFullFormatted)
        assertEquals("₽", wire.currency)
        assertEquals(20L, wire.discountPercent)
        assertEquals("20%", wire.discountFormatted)
        assertEquals(73L, wire.salesRate)
        assertEquals(0.8, wire.relativeSalesRate)
        assertEquals(4L, wire.rating)
        assertEquals(true, wire.isNew)
        assertEquals(12L, wire.stockQuantity)
        assertEquals(listOf("c1"), wire.categoryIds)
        val category = wire.categories!!.single()
        assertEquals("c1", category.id)
        assertEquals("Phones", category.name)
        assertEquals("/c1", category.url)
        assertEquals("c0", category.parentId)
        assertEquals(2L, category.level)
        assertEquals("Color", wire.params!!.single().key)
        assertEquals(listOf("Black"), wire.params!!.single().values)
        assertEquals(listOf("msk"), wire.locationIds)
    }

    @Test
    fun aProductWithoutItsOptionalFieldsLeavesThemEmpty() {
        val wire = Product(id = "1", name = "P", url = "u", price = 1.0, currency = "₽").toWire()

        assertNull(wire.brand)
        assertNull(wire.oldPrice)
        assertNull(wire.discountPercent)
        assertNull(wire.categories)
        assertEquals(false, wire.isNew)
    }

    @Test
    fun aListingCarriesItsFacets() {
        val listing = ProductsListResponse(
            productsTotal = 120,
            products = listOf(product),
            categories = listOf(ProductCategory(id = "c1", count = 5, alias = "phones")),
            brands = listOf(Brand(count = 3, name = "Acme")),
            locations = listOf(Location(id = "msk", name = "Moscow", type = "city")),
            filters = mapOf("Color" to SearchFilter(count = 7, priority = 1, values = mapOf("Black" to 4))),
            industrialFilters = IndustrialFilters(
                colors = listOf(ColorFilter(color = "black", count = 2)),
                fashionSizes = listOf(SizeFilter(size = "M", count = 1)),
            ),
            priceRange = PriceRange(max = 30000.0, min = 100.0),
            priceRanges = listOf(PriceInterval(to = 1000.0, count = 9), PriceInterval(from = 1000.0, count = 3)),
            priceMedian = 1500.0,
        )

        val wire = listing.toWire()

        assertEquals(120L, wire.productsTotal)
        assertEquals("37", wire.products.single().id)
        assertEquals(5L, wire.categories!!.single().count)
        assertEquals("phones", wire.categories!!.single().alias)
        assertEquals("Acme", wire.brands!!.single().name)
        assertEquals(3L, wire.brands!!.single().count)
        assertEquals("city", wire.locations!!.single().type)
        val color = wire.filters!!.getValue("Color")
        assertEquals(7L, color.count)
        assertEquals(1L, color.priority)
        assertEquals(mapOf("Black" to 4L), color.values)
        assertEquals("black", wire.industrialFilters!!.colors!!.single().color)
        assertEquals("M", wire.industrialFilters!!.fashionSizes!!.single().size)
        assertEquals(100.0, wire.priceRange!!.min)
        assertEquals(30000.0, wire.priceRange!!.max)
        assertEquals(0.0, wire.priceRanges!![0].from)
        assertEquals(1000.0, wire.priceRanges!![0].to)
        assertNull(wire.priceRanges!![1].to)
        assertEquals(1500.0, wire.priceMedian)
    }

    @Test
    fun aCategoryIsTheListingsWireWithoutItsExtraFields() {
        val wire = CategoryResponse(productsTotal = 2, products = listOf(product), priceMedian = 10.0).toWire()

        assertEquals(2L, wire.productsTotal)
        assertEquals(1, wire.products.size)
        assertNull(wire.locations)
        assertNull(wire.industrialFilters)
        assertEquals(10.0, wire.priceMedian)
    }

    @Test
    fun countersRecommendationsAndSearchConvert() {
        val counters = ProductCountersResponse(daily = ProductCounter(view = 5, cart = 2, purchase = 1)).toWire()
        assertEquals(5L, counters.daily!!.view)
        assertNull(counters.now)

        val block = RecommendationResponse(id = 9, title = "Similar", link = "/s", products = listOf(product), itemIds = listOf("37"))
            .toWire()
        assertEquals(9L, block.id)
        assertEquals("Similar", block.title)
        assertEquals(listOf("37"), block.itemIds)

        val blank = SearchBlankResponse(
            products = listOf(product),
            lastProducts = true,
            lastQueries = listOf(Query(name = "phone", url = "/s?q=phone", score = 0.5)),
            popularBrands = listOf(PopularItem(name = "Acme", url = "/b/acme")),
        ).toWire()
        assertEquals(true, blank.lastProducts)
        assertEquals(0.5, blank.lastQueries!!.single().score)
        assertEquals("/b/acme", blank.popularBrands!!.single().url)
        assertNull(blank.suggests)

        val instant = SearchInstantResponse(
            searchQuery = "phone",
            clarification = false,
            productsTotal = 1,
            products = listOf(product),
            redirect = SearchRedirect(query = "phone", url = "/phones", deeplink = "app://phones"),
        ).toWire()
        assertEquals("phone", instant.searchQuery)
        assertEquals(1L, instant.productsTotal)
        assertEquals("/phones", instant.redirect!!.url)
    }

    @Test
    fun theSearchAgentsIdsAre64BitAndItsRoleGoesAsItsWireValue() {
        val message = AgentMessage(
            id = 5_000_000_000L,
            role = AgentMessageRole.ASSISTANT,
            content = "Try these",
            products = listOf(AgentProduct(id = "37", price = 10.0, reason = "cheap")),
        )
        val wire = AgentResponse(session = AgentSession(id = 7_000_000_000L), message = message).toWire()

        assertEquals(7_000_000_000L, wire.session.id)
        assertEquals(5_000_000_000L, wire.message.id)
        assertEquals("assistant", wire.message.role)
        assertEquals("cheap", wire.message.products.single().reason)
        assertTrue(wire.session.messages.isEmpty())
    }

    @Test
    fun aProfilesGendersGoAsTheirWireValuesAndItsCustomPropertiesAsPlainValues() {
        val custom = JSONObject().put("tier", "gold").put("visits", 3).put("tags", JSONArray().put("a").put(1.5))
        val profile = Profile(
            id = "u-1",
            hasEmail = true,
            gender = Gender.FEMALE,
            computedGender = Gender.MALE,
            customProperties = mapOf("json" to custom, "count" to 2, "none" to JSONObject.NULL),
        ).toWire()

        assertEquals("f", profile.gender)
        assertEquals("m", profile.computedGender)
        assertEquals(true, profile.hasEmail)
        val json = profile.customProperties!!["json"] as Map<*, *>
        assertEquals("gold", json["tier"])
        assertEquals(3L, json["visits"])
        assertEquals(listOf("a", 1.5), json["tags"])
        assertEquals(2L, profile.customProperties!!["count"])
        assertTrue(profile.customProperties!!.containsKey("none"))
        assertNull(profile.customProperties!!["none"])
    }

    @Test
    fun cartSegmentsSubscriptionsAndLoyaltyConvert() {
        assertEquals(3L, CartItem(id = "37", quantity = 3).toWire().quantity)
        assertEquals(12L, Segment(id = 12, type = "static").toWire().id)
        val status = SubscriptionStatus(exists = true, emailBulk = true, walletTransactional = true).toWire()
        assertEquals(true, status.exists)
        assertEquals(true, status.emailBulk)
        assertEquals(true, status.walletTransactional)
        assertEquals(false, status.smsBulk)

        val loyalty = LoyaltyStatus(isMember = true, level = LoyaltyLevel(code = "gold", name = "Gold", expirationDate = null))
            .toWire()
        assertEquals(true, loyalty.isMember)
        assertEquals("gold", loyalty.level!!.code)

        val promotion = LoyaltyPromotion(
            id = 9_000_000_000L,
            name = "Sale",
            description = null,
            startDate = "2026-11-01",
            finishDate = null,
            stream = null,
            badgeLabel = "-10%",
            badgeColor = "#f00",
            rewardType = LoyaltyRewardType.BONUSES_EARN,
        ).toWire()
        assertEquals(9_000_000_000L, promotion.id)
        assertEquals("bonuses_earn", promotion.rewardType)
    }

    @Test
    fun anOrderCarriesItsItemsAndTheirProducts() {
        val order = Order(id = "o-1", value = "69990.0", taxFree = false, items = listOf(OrderItem(amount = 2, price = "100.0")))
            .toWire()

        assertEquals("o-1", order.id)
        assertEquals("69990.0", order.value)
        assertEquals(2L, order.items.single().amount)
        assertNull(order.items.single().item)
    }

    @Test
    fun storiesConvertWithTheirElementsKinds() {
        val storyProduct = StoryProduct(
            id = "37", name = "Phone", brand = "Acme", picture = "p", imageUrl = "i", price = 10.0,
            priceFormatted = "10", oldPrice = null, oldPriceFormatted = "", discountPercent = 0.0, promocode = "",
            priceWithPromocode = 0.0, priceWithPromocodeFormatted = "", currency = "₽", url = "u",
            deeplinkAndroid = "", deeplinkIos = "",
        )
        val slide = StorySlide(
            id = "s1",
            type = StorySlideType.VIDEO,
            background = "b",
            backgroundColor = "#000",
            preview = "pv",
            duration = 7,
            elements = listOf(
                StoryButtonElement("Go", "l", "la", "li", "bg", "c", true),
                StoryProductElement("Buy", storyProduct),
                StoryProductsElement("Show", "Hide", listOf(storyProduct)),
                StoryTextBlockElement("Hi", 14.0, "serif", true, false, "center", "#fff", "#000", 0.5, 1.2, 0.3, "CODE"),
            ),
        )
        val block = StoriesBlock(id = "b1", stories = listOf(Story(id = "1", name = "N", avatar = "a", pinned = true, startPosition = 2, slides = listOf(slide))))
            .toWire()

        val story = block.stories.single()
        assertEquals(true, story.pinned)
        assertEquals(2L, story.startPosition)
        val wireSlide = story.slides.single()
        assertEquals("video", wireSlide.type)
        assertEquals(7L, wireSlide.duration)
        assertEquals(listOf("button", "product", "products", "text_block"), wireSlide.elements.map { it.type })
        assertEquals("la", wireSlide.elements[0].linkAndroid)
        assertEquals(true, wireSlide.elements[0].textBold)
        assertEquals("37", wireSlide.elements[1].item!!.id)
        assertEquals("Hide", wireSlide.elements[2].hideLabel)
        assertEquals("CODE", wireSlide.elements[3].promocode)
        assertEquals(0.5, wireSlide.elements[3].backgroundOpacity)
    }

    @Test
    fun slidersAndReviewsConvert() {
        val slider = Slider(code = "main", width = 640, height = 320, banners = listOf(SliderBanner("5", "b5", "img", null, null, null, null)))
            .toWire()
        assertEquals(640L, slider.width)
        assertEquals("b5", slider.banners.single().code)

        val reviews = ProductReviewsResponse(
            summary = ProductRatingSummary(count = 3, averageRating = 4.5, ratings = mapOf(5 to 2, 4 to 1)),
            reviews = listOf(ProductReview(id = 8_000_000_000L, rating = 5, createdAt = "2026-11-18T10:00:00Z")),
        ).toWire()
        assertEquals(mapOf(5L to 2L, 4L to 1L), reviews.summary.ratings)
        assertEquals(8_000_000_000L, reviews.reviews.single().id)

        val review = ClientReview(
            id = 1, itemId = "37", orderId = "o-1", rating = 4, state = ReviewState.PUBLISHED, createdAt = "2026-11-18",
        ).toWire()
        assertEquals("published", review.state)
        assertEquals(4L, review.rating)
    }

    @Test
    fun freeFormValuesBecomeTheCodecsOwnTypes() {
        assertEquals(5L, standard(5))
        assertEquals(1.5, standard(1.5f).let { (it as Double) })
        assertEquals(mapOf("a" to listOf(1L, "x")), standard(mapOf("a" to listOf(1, "x"))))
        assertNull(standard(JSONObject.NULL))
        assertEquals("text", standard(StringBuilder("text")))
    }
}
