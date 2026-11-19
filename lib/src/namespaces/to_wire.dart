// The public request models turned into the models of the native channel, and the
// released parameter classes turned into the contract's requests. Not exported.

import 'package:flutter/foundation.dart';

import '../models/profile_models.dart';
import '../models/request_models.dart';
import '../models/values.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../products/products_list_params.dart';
import '../profile/profile_params.dart';
import '../recommendation/recommendation_params.dart';
import '../search/search_params.dart';

pigeon.ProductsListRequestWire productsListRequestToWire(
  ProductsListRequest? request,
) => pigeon.ProductsListRequestWire(
  categoryIds: request?.categoryIds,
  brands: request?.brands,
  merchants: request?.merchants,
  locations: request?.locations,
  priceMin: request?.priceMin,
  priceMax: request?.priceMax,
  filters: request?.filters,
  sortBy: request?.sortBy?.value,
  sortDir: request?.sortDir?.wireValue,
  limit: request?.limit,
  page: request?.page,
);

pigeon.ProductsListRequestWire categoryRequestToWire(
  CategoryRequest? request,
) => pigeon.ProductsListRequestWire(
  brands: request?.brands,
  locations: request?.locations,
  priceMin: request?.priceMin,
  priceMax: request?.priceMax,
  filters: request?.filters,
  sortBy: request?.sortBy?.value,
  sortDir: request?.sortDir?.wireValue,
  limit: request?.limit,
  page: request?.page,
);

pigeon.RecommendationRequestWire recommendationRequestToWire(
  RecommendationRequest? request,
) {
  final r = request ?? const RecommendationRequest();
  return pigeon.RecommendationRequestWire(
    itemId: r.itemId,
    categoryId: r.categoryId,
    searchQuery: r.searchQuery,
    excludedItemIds: r.excludedItemIds,
    brands: r.brands,
    locations: r.locations,
    limit: r.limit,
    extended: r.extended,
    withLocations: r.withLocations,
  );
}

pigeon.SearchFullRequestWire searchFullRequestToWire(
  SearchFullRequest? request,
) {
  final r = request ?? const SearchFullRequest();
  return pigeon.SearchFullRequestWire(
    categoryIds: r.categoryIds,
    brands: r.brands,
    excludedBrands: r.excludedBrands,
    merchants: r.merchants,
    excludedMerchants: r.excludedMerchants,
    locations: r.locations,
    priceMin: r.priceMin,
    priceMax: r.priceMax,
    colors: r.colors,
    fashionSizes: r.fashionSizes,
    excludedItemIds: r.excludedItemIds,
    filters: r.filters,
    sortBy: r.sortBy?.value,
    sortDir: r.sortDir?.wireValue,
    disableClarification: r.disableClarification,
    categoryLimit: r.categoryLimit,
    brandLimit: r.brandLimit,
    limit: r.limit,
    page: r.page,
  );
}

pigeon.ProfileUpdateRequestWire profileUpdateRequestToWire(
  ProfileUpdateRequest r,
) => pigeon.ProfileUpdateRequestWire(
  email: r.email,
  phone: r.phone,
  externalId: r.externalId,
  loyaltyId: r.loyaltyId,
  telegramId: r.telegramId,
  fbId: r.fbId,
  vkId: r.vkId,
  firstName: r.firstName,
  lastName: r.lastName,
  gender: r.gender?.wireValue,
  birthday: r.birthday,
  age: r.age,
  location: r.location,
  kids: r.kids
      ?.map(
        (k) => pigeon.ProfileKidWire(
          gender: k.gender?.wireValue,
          birthday: k.birthday,
        ),
      )
      .toList(),
  cars: r.cars
      ?.map(
        (c) =>
            pigeon.ProfileCarWire(brand: c.brand, model: c.model, vds: c.vds),
      )
      .toList(),
  customProperties: r.customProperties,
);

// region the released parameters

/// A comma-separated list of the released parameters as the contract's list:
/// `"a,b"` → `["a", "b"]`, the native SDK joins it back with commas.
List<String>? splitList(String? joined) {
  if (joined == null) return null;
  final parts = joined
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? null : parts;
}

/// The direction of a released `sort_dir` string; null for another value.
SortDirection? sortDirection(String? value) => switch (value) {
  'asc' => SortDirection.asc,
  'desc' => SortDirection.desc,
  _ => null,
};

/// [ProfileParams] of the released `setProfile` as the contract's request. The
/// fields the contract left out go as the free-form fields the API reads, as the
/// released bridges sent them: `loyalty_card_location`, `loyalty_status`,
/// `loyalty_bonuses`, `loyalty_bonuses_to_next_level`, `bought_something` (`1` /
/// `0`) and the advertising id (`google_advertising_id` on Android,
/// `apple_advertising_id` on iOS). [ProfileParams.userId] is the shop's id of the
/// customer: [ProfileUpdateRequest.externalId], sent as `id` as before.
ProfileUpdateRequest profileParamsToRequest(ProfileParams p) {
  final custom = <String, Object?>{
    ...?p.customProperties,
    if (p.loyaltyCardLocation != null)
      'loyalty_card_location': p.loyaltyCardLocation,
    if (p.loyaltyStatus != null) 'loyalty_status': p.loyaltyStatus,
    if (p.loyaltyBonuses != null) 'loyalty_bonuses': p.loyaltyBonuses,
    if (p.loyaltyBonusesToNextLevel != null)
      'loyalty_bonuses_to_next_level': p.loyaltyBonusesToNextLevel,
    if (p.boughtSomething != null)
      'bought_something': p.boughtSomething! ? '1' : '0',
    if (p.advertisingId != null)
      defaultTargetPlatform == TargetPlatform.iOS
              ? 'apple_advertising_id'
              : 'google_advertising_id':
          p.advertisingId,
  };
  return ProfileUpdateRequest(
    email: p.email,
    phone: p.phone,
    externalId: p.userId,
    loyaltyId: p.loyaltyId,
    telegramId: p.telegramId,
    fbId: p.fbId,
    vkId: p.vkId,
    firstName: p.firstName,
    lastName: p.lastName,
    gender: p.gender,
    birthday: p.birthday,
    age: p.age,
    location: p.location,
    customProperties: custom.isEmpty ? null : custom,
  );
}

/// [ProductsListParams] of the released `getProductsList` as the contract's
/// request.
ProductsListRequest productsListParamsToRequest(ProductsListParams? p) =>
    ProductsListRequest(
      categoryIds: splitList(p?.categories),
      brands: splitList(p?.brands),
      merchants: splitList(p?.merchants),
      locations: splitList(p?.locations),
      filters: p?.filters,
      limit: p?.limit,
      page: p?.page,
    );

/// [RecommendationParams] of the released `getRecommendation` as the contract's
/// request. `imageSize` has no counterpart in the native SDKs' request and is not
/// sent.
RecommendationRequest recommendationParamsToRequest(RecommendationParams? p) =>
    RecommendationRequest(
      itemId: p?.itemId,
      categoryId: p?.categoryId,
      locations: splitList(p?.locations),
      withLocations: p?.withLocations ?? false,
    );

/// [SearchParams] of the released `searchFull` as the contract's request.
SearchFullRequest searchParamsToRequest(SearchParams? p) => SearchFullRequest(
  categoryIds: p?.categories,
  brands: splitList(p?.brands),
  excludedBrands: p?.excludedBrands,
  locations: splitList(p?.locations),
  priceMin: p?.priceMin,
  priceMax: p?.priceMax,
  colors: p?.colors,
  fashionSizes: p?.fashionSizes,
  filters: p?.filters,
  sortBy: p?.sortBy == null ? null : SortBy(p!.sortBy!),
  sortDir: sortDirection(p?.sortDir),
  categoryLimit: p?.categoryLimit,
  brandLimit: p?.brandLimit,
  limit: p?.limit,
  page: p?.page,
);

// endregion
