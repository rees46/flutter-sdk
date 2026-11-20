package com.rees46.rees46_flutter_sdk

import com.personalization.LogLevel
import com.personalization.PushProvider
import com.personalization.api.models.products.SortBy
import com.personalization.api.models.products.SortDirection
import com.personalization.api.models.profile.Gender
import com.personalization.api.models.tracking.TrackingSourceType
import com.personalization.core.SdkException
import com.rees46.rees46_flutter_sdk.pigeon.InitConfig
import com.rees46.rees46_flutter_sdk.pigeon.ProductsListRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileCarWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileKidWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileUpdateRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.RecommendationRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchFullRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.SubscriptionsUpdateRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingItemWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingSourceWire
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

/** What Dart sends becomes the native SDK's request models, and a value they do not know is refused. */
internal class WireRequestsTest {

    private fun config(apiDomain: String = "api.rees46.ru", enableLogs: Boolean = false) = InitConfig(
        shopId = " shop-1 ",
        apiDomain = apiDomain,
        stream = "flutter",
        enableLogs = enableLogs,
        autoSendPushToken = false,
        sendAdvertisingId = true,
        enableAutoPopupPresentation = false,
        needReInitialization = true,
    )

    @Test
    fun theConfigurationKeepsEveryFieldAndTheApiHostOnly() {
        val native = config(apiDomain = "https://api.example.test/").toNative()

        assertEquals("shop-1", native.shopId)
        assertEquals("api.example.test", native.apiDomain)
        assertEquals("flutter", native.stream)
        assertEquals(false, native.autoSendPushToken)
        assertEquals(true, native.sendAdvertisingId)
        assertEquals(false, native.enableAutoPopupPresentation)
        assertEquals(true, native.needReInitialization)
        assertEquals(LogLevel.WARNING, native.logLevel)
        assertEquals(LogLevel.DEBUG, config(enableLogs = true).toNative().logLevel)
        assertEquals("api.rees46.ru", config(apiDomain = " ").toNative().apiDomain)
        assertEquals("app.rees46.ru", native.appDomain)
        assertNull(native.deviceId)
        assertNull(native.storageKey)
    }

    @Test
    fun theContractsSliderAndAgentSearchGoAsTheirWireValues() {
        assertEquals("slider", TrackingSourceWire("slider", "c").toNative().wireType)
        assertEquals("agent_search", TrackingSourceWire("agent_search", "c").toNative().wireType)
        assertEquals("c", TrackingSourceWire("slider", "c").toNative().code)
        assertEquals("stories", TrackingSourceWire("stories", "c").toNative().wireType)
        val refused = assertFailsWith<SdkException> { TrackingSourceWire("agentSearch", "c").toNative() }
        assertEquals("invalidArgument", BridgeFailures.of(refused).code)
    }

    @Test
    fun theContractsConfigurationFieldsReachTheNativeOne() {
        val native = config(enableLogs = true).copy(
            appDomain = "https://app.cluster.test/",
            deviceId = " did-kept ",
            logLevel = "info",
            storageKey = "partition-a",
        ).toNative()

        assertEquals("app.cluster.test", native.appDomain)
        assertEquals("did-kept", native.deviceId)
        assertEquals(LogLevel.INFO, native.logLevel, "logLevel wins over enableLogs")
        assertEquals("partition-a", native.storageKey)
        assertEquals(LogLevel.NONE, config().copy(logLevel = "none").toNative().logLevel)
        assertEquals(LogLevel.WARNING, config().copy(logLevel = "loud").toNative().logLevel)
    }

    @Test
    fun aListingRequestKeepsItsFiltersSortAndPage() {
        val wire = ProductsListRequestWire(
            categoryIds = listOf("c1"),
            brands = listOf("acme"),
            merchants = listOf("m1"),
            locations = listOf("msk"),
            priceMin = 10.0,
            priceMax = 100.0,
            filters = mapOf("Color" to listOf("Black")),
            sortBy = "sales_rate",
            sortDir = "asc",
            limit = 20,
            page = 2,
        )

        val list = wire.toNative()
        assertEquals(listOf("c1"), list.categoryIds)
        assertEquals(listOf("m1"), list.merchants)
        assertEquals(SortBy.SALES_RATE, list.sortBy)
        assertEquals(SortDirection.ASC, list.sortDir)
        assertEquals(20, list.limit)
        assertEquals(2, list.page)
        assertEquals(mapOf("Color" to listOf("Black")), list.filters)

        val category = wire.toCategoryRequest()
        assertEquals(listOf("acme"), category.brands)
        assertEquals(listOf("msk"), category.locations)
        assertEquals(10.0, category.priceMin)
        assertEquals(SortBy.SALES_RATE, category.sortBy)
        assertEquals(2, category.page)
    }

    @Test
    fun anOpenSortKeyGoesAsItIsAndAnUnknownDirectionIsRefused() {
        assertEquals(SortBy("popular"), ProductsListRequestWire(sortBy = "popular").toNative().sortBy)
        assertNull(ProductsListRequestWire().toNative().sortDir)
        assertFailsWith<IllegalArgumentException> { ProductsListRequestWire(sortDir = "up").toNative() }
    }

    @Test
    fun recommendationAndSearchRequestsConvert() {
        val block = RecommendationRequestWire(itemId = "37", limit = 6, extended = false, withLocations = true).toNative()
        assertEquals("37", block.itemId)
        assertEquals(6, block.limit)
        assertEquals(false, block.extended)
        assertEquals(true, block.withLocations)

        val search = SearchFullRequestWire(
            excludedMerchants = listOf("m2"),
            colors = listOf("red"),
            sortBy = "relevance",
            sortDir = "desc",
            disableClarification = true,
            categoryLimit = 3,
            brandLimit = 4,
        ).toNative()
        assertEquals(listOf("m2"), search.excludedMerchants)
        assertEquals(SortBy.RELEVANCE, search.sortBy)
        assertEquals(SortDirection.DESC, search.sortDir)
        assertEquals(true, search.disableClarification)
        assertEquals(3, search.categoryLimit)
        assertEquals(4, search.brandLimit)
    }

    @Test
    fun aProfileUpdateTakesGendersAndItsListsAndCustomProperties() {
        val request = ProfileUpdateRequestWire(
            externalId = "ext-1",
            gender = "f",
            age = 30,
            kids = listOf(ProfileKidWire(gender = "m", birthday = "2020-01-02")),
            cars = listOf(ProfileCarWire(brand = "Lada", model = "Vesta")),
            customProperties = mapOf("tier" to "gold", "visits" to 3L),
        ).toNative()

        assertEquals("ext-1", request.externalId)
        assertEquals(Gender.FEMALE, request.gender)
        assertEquals(30, request.age)
        assertEquals(Gender.MALE, request.kids!!.single().gender)
        assertEquals("Vesta", request.cars!!.single().model)
        assertEquals(mapOf("tier" to "gold", "visits" to 3L), request.customProperties)
        assertFailsWith<IllegalArgumentException> { ProfileUpdateRequestWire(gender = "x").toNative() }
    }

    @Test
    fun subscriptionsKeepEveryFlag() {
        val request = SubscriptionsUpdateRequestWire(email = "e", walletChain = true, maxTransactional = false).toNative()

        assertEquals("e", request.email)
        assertEquals(true, request.walletChain)
        assertEquals(false, request.maxTransactional)
        assertNull(request.smsBulk)
    }

    @Test
    fun trackingModelsAndProvidersConvertAndUnknownValuesAreRefused() {
        assertEquals(TrackingSourceType.INSTANT_SEARCH, TrackingSourceWire(type = "instant_search", code = "q").toNative().type)
        assertFailsWith<SdkException> { TrackingSourceWire(type = "gcm", code = "x").toNative() }
        assertEquals(4, TrackingItemWire(id = "37", quantity = 4).toNative().quantity)
        assertEquals(PushProvider.HMS, pushProvider("hms"))
        assertFailsWith<IllegalArgumentException> { pushProvider("apns") }
    }

    @Test
    fun aPurchasesAttributionBecomesJson() {
        val json = mapOf("type" to "dynamic", "nested" to mapOf("a" to 1L), "list" to listOf("x"), "none" to null)
            .toJsonObject()

        assertEquals("dynamic", json.getString("type"))
        assertEquals(1L, json.getJSONObject("nested").getLong("a"))
        assertEquals("x", json.getJSONArray("list").getString(0))
        assertEquals(true, json.isNull("none"))
    }
}
