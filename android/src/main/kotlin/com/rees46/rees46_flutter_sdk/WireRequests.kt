package com.rees46.rees46_flutter_sdk

import com.personalization.LogLevel
import com.personalization.PushProvider
import com.personalization.Rees46Config
import com.personalization.api.models.products.CategoryRequest
import com.personalization.api.models.products.ProductsListRequest
import com.personalization.api.models.products.SortBy
import com.personalization.api.models.products.SortDirection
import com.personalization.api.models.profile.Gender
import com.personalization.api.models.profile.ProfileCar
import com.personalization.api.models.profile.ProfileKid
import com.personalization.api.models.profile.ProfileUpdateRequest
import com.personalization.api.models.purchase.PurchaseItemRequest
import com.personalization.api.models.recommendations.RecommendationRequest
import com.personalization.api.models.search.SearchFullRequest
import com.personalization.api.models.subscriptions.BackInStockProperties
import com.personalization.api.models.subscriptions.SubscriptionsUpdateRequest
import com.personalization.api.models.tracking.TrackingItem
import com.personalization.api.models.tracking.TrackingSource
import com.personalization.api.models.tracking.TrackingSourceType
import com.rees46.rees46_flutter_sdk.pigeon.BackInStockPropertiesWire
import com.rees46.rees46_flutter_sdk.pigeon.InitConfig
import com.rees46.rees46_flutter_sdk.pigeon.ProductsListRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileCarWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileKidWire
import com.rees46.rees46_flutter_sdk.pigeon.ProfileUpdateRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.PurchaseLineItemWire
import com.rees46.rees46_flutter_sdk.pigeon.RecommendationRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.SearchFullRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.SubscriptionsUpdateRequestWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingItemWire
import com.rees46.rees46_flutter_sdk.pigeon.TrackingSourceWire
import org.json.JSONObject

/*
 * What Dart sends, as the native SDK's request models. A value of a closed set that the native side does
 * not know (Dart only sends the ones it has) fails with [IllegalArgumentException], which the plugin reports
 * as `invalidArgument`; open sets (`SortBy`) go as they are.
 */

/**
 * The shop's configuration from Dart. The API's host only, as iOS takes it: a scheme and a trailing slash
 * go. `enableLogs` is the old way to ask for every message of the SDK's log.
 */
internal fun InitConfig.toNative(): Rees46Config {
    val defaults = Rees46Config(shopId = shopId.trim())
    return Rees46Config(
        shopId = shopId.trim(),
        apiDomain = apiHost(apiDomain) ?: defaults.apiDomain,
        stream = stream.trim().ifEmpty { defaults.stream },
        autoSendPushToken = autoSendPushToken,
        needReInitialization = needReInitialization,
        enableAutoPopupPresentation = enableAutoPopupPresentation,
        logLevel = if (enableLogs) LogLevel.DEBUG else LogLevel.WARNING,
        sendAdvertisingId = sendAdvertisingId,
    )
}

/** The API's host: without a scheme, a trailing slash and spaces; null when nothing is left. */
internal fun apiHost(domain: String?): String? =
    domain?.trim()
        ?.replace(Regex("^https?://", RegexOption.IGNORE_CASE), "")
        ?.trimEnd('/')
        ?.ifEmpty { null }

internal fun sortDirection(value: String?): SortDirection? = value?.let { wire ->
    SortDirection.entries.firstOrNull { it.value == wire }
        ?: throw IllegalArgumentException("Unknown sort direction: $wire")
}

internal fun gender(value: String?): Gender? = value?.let { wire ->
    Gender.entries.firstOrNull { it.value == wire } ?: throw IllegalArgumentException("Unknown gender: $wire")
}

internal fun pushProvider(value: String): PushProvider =
    PushProvider.fromId(value) ?: throw IllegalArgumentException("$value is not a push provider of Android")

internal fun ProductsListRequestWire.toNative(): ProductsListRequest = ProductsListRequest(
    categoryIds = categoryIds,
    brands = brands,
    merchants = merchants,
    locations = locations,
    priceMin = priceMin,
    priceMax = priceMax,
    filters = filters,
    sortBy = sortBy?.let(::SortBy),
    sortDir = sortDirection(sortDir),
    limit = limit?.toInt(),
    page = page?.toInt(),
)

/** `products.getCategory` takes the listing's request without its category and merchants. */
internal fun ProductsListRequestWire.toCategoryRequest(): CategoryRequest = CategoryRequest(
    brands = brands,
    locations = locations,
    filters = filters,
    priceMin = priceMin,
    priceMax = priceMax,
    sortBy = sortBy?.let(::SortBy),
    sortDir = sortDirection(sortDir),
    limit = limit?.toInt(),
    page = page?.toInt(),
)

internal fun RecommendationRequestWire.toNative(): RecommendationRequest = RecommendationRequest(
    itemId = itemId,
    categoryId = categoryId,
    searchQuery = searchQuery,
    excludedItemIds = excludedItemIds,
    brands = brands,
    locations = locations,
    limit = limit?.toInt(),
    extended = extended,
    withLocations = withLocations,
)

internal fun SearchFullRequestWire.toNative(): SearchFullRequest = SearchFullRequest(
    categoryIds = categoryIds,
    brands = brands,
    excludedBrands = excludedBrands,
    merchants = merchants,
    excludedMerchants = excludedMerchants,
    locations = locations,
    priceMin = priceMin,
    priceMax = priceMax,
    colors = colors,
    fashionSizes = fashionSizes,
    excludedItemIds = excludedItemIds,
    filters = filters,
    sortBy = sortBy?.let(::SortBy),
    sortDir = sortDirection(sortDir),
    disableClarification = disableClarification,
    categoryLimit = categoryLimit?.toInt(),
    brandLimit = brandLimit?.toInt(),
    limit = limit?.toInt(),
    page = page?.toInt(),
)

internal fun ProfileUpdateRequestWire.toNative(): ProfileUpdateRequest = ProfileUpdateRequest(
    email = email,
    phone = phone,
    externalId = externalId,
    loyaltyId = loyaltyId,
    telegramId = telegramId,
    fbId = fbId,
    vkId = vkId,
    firstName = firstName,
    lastName = lastName,
    gender = gender(gender),
    birthday = birthday,
    age = age?.toInt(),
    location = location,
    kids = kids?.map { it.toNative() },
    cars = cars?.map { it.toNative() },
    customProperties = customProperties,
)

internal fun ProfileKidWire.toNative(): ProfileKid = ProfileKid(gender = gender(gender), birthday = birthday)

internal fun ProfileCarWire.toNative(): ProfileCar = ProfileCar(brand = brand, model = model, vds = vds)

internal fun SubscriptionsUpdateRequestWire.toNative(): SubscriptionsUpdateRequest = SubscriptionsUpdateRequest(
    email = email,
    phone = phone,
    externalId = externalId,
    loyaltyId = loyaltyId,
    telegramId = telegramId,
    emailBulk = emailBulk,
    emailChain = emailChain,
    emailTransactional = emailTransactional,
    smsBulk = smsBulk,
    smsChain = smsChain,
    smsTransactional = smsTransactional,
    webPushBulk = webPushBulk,
    webPushChain = webPushChain,
    webPushTransactional = webPushTransactional,
    mobilePushBulk = mobilePushBulk,
    mobilePushChain = mobilePushChain,
    mobilePushTransactional = mobilePushTransactional,
    telegramBulk = telegramBulk,
    telegramChain = telegramChain,
    telegramTransactional = telegramTransactional,
    whatsappBulk = whatsappBulk,
    whatsappChain = whatsappChain,
    whatsappTransactional = whatsappTransactional,
    maxBulk = maxBulk,
    maxChain = maxChain,
    maxTransactional = maxTransactional,
    walletBulk = walletBulk,
    walletChain = walletChain,
    walletTransactional = walletTransactional,
)

internal fun BackInStockPropertiesWire.toNative(): BackInStockProperties =
    BackInStockProperties(fashionSize = fashionSize, fashionColor = fashionColor, barcode = barcode)

internal fun TrackingItemWire.toNative(): TrackingItem =
    TrackingItem(id = id, quantity = quantity.toInt(), price = price, fashionSize = fashionSize)

internal fun TrackingSourceWire.toNative(): TrackingSource {
    val sourceType = TrackingSourceType.entries.firstOrNull { it.value == type }
        ?: throw IllegalArgumentException("Unknown source type: $type")
    return TrackingSource(type = sourceType, code = code)
}

internal fun PurchaseLineItemWire.toNative(): PurchaseItemRequest = PurchaseItemRequest(
    id = id,
    amount = amount.toInt(),
    price = price,
    lineId = lineId,
    fashionSize = fashionSize,
)

/** A free-form map from Dart as the JSON the native purchase request carries its attribution in. */
internal fun Map<String, Any?>.toJsonObject(): JSONObject = JSONObject().also { json ->
    forEach { (key, value) -> json.put(key, toJsonValue(value)) }
}

private fun toJsonValue(value: Any?): Any = when (value) {
    null -> JSONObject.NULL
    is Map<*, *> -> JSONObject().also { json ->
        value.forEach { (key, item) -> json.put(key.toString(), toJsonValue(item)) }
    }
    is List<*> -> org.json.JSONArray().also { array -> value.forEach { array.put(toJsonValue(it)) } }
    else -> value
}
