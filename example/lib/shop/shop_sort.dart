import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A sort of the shop's results screens (search and category): what goes into the
/// screen's `sortBy` / `sortDir`. The kit draws no sort picker, the host brings one.
enum ShopSort {
  relevance('Relevance', null, null),
  priceAsc('Price: low to high', 'price', 'asc'),
  priceDesc('Price: high to low', 'price', 'desc'),
  discount('Discount', 'discount', 'desc');

  const ShopSort(this.label, this.sortBy, this.sortDir);

  final String label;

  /// `null` — no sort: the server's relevance.
  final String? sortBy;
  final String? sortDir;
}

/// The platform's plain picker of [ShopSort]: an action sheet on iOS, a bottom sheet
/// with the current one checked elsewhere. `null` — dismissed without a choice.
Future<ShopSort?> pickShopSort(BuildContext context, ShopSort current) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<ShopSort>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Sort by'),
        actions: [
          for (final sort in ShopSort.values)
            CupertinoActionSheetAction(
              isDefaultAction: sort == current,
              onPressed: () => Navigator.of(context).pop(sort),
              child: Text(sort.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  return showModalBottomSheet<ShopSort>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Sort by')),
          for (final sort in ShopSort.values)
            ListTile(
              title: Text(sort.label),
              trailing: sort == current ? const Icon(Icons.check) : null,
              selected: sort == current,
              onTap: () => Navigator.of(context).pop(sort),
            ),
        ],
      ),
    ),
  );
}
