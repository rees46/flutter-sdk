import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

import 'shop.dart';

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

/// Height of a row of the sort sheet.
const double _sortRowHeight = 52;

/// The shop's sort picker, the same on both platforms: a bottom sheet on the kit's
/// modal surface, "Sort by" over the sorts, the current one checked; a tap picks and
/// closes. It covers the tab bar too. `null` — dismissed without a choice.
Future<ShopSort?> pickShopSort(BuildContext context, ShopSort current) {
  final theme = PersonalizationTheme.of(context);
  return showModalBottomSheet<ShopSort>(
    context: context,
    useRootNavigator: true,
    backgroundColor: theme.colors.backgroundModal,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(theme.radius.modal),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => _ShopSortSheet(current: current),
  );
}

class _ShopSortSheet extends StatelessWidget {
  const _ShopSortSheet({required this.current});

  final ShopSort current;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    const side = PersonalizationSpacing.paddingModal;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: side),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: side),
              child: Text(
                'Sort by',
                style: shopTextStyle(
                  context,
                  PersonalizationTypography.lgEmphasized,
                  colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: PersonalizationSpacing.md),
            for (final sort in ShopSort.values)
              Semantics(
                button: true,
                selected: sort == current,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(sort),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _sortRowHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: side),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              sort.label,
                              style: shopTextStyle(
                                context,
                                PersonalizationTypography.baseDefault,
                                colors.textPrimary,
                              ),
                            ),
                          ),
                          if (sort == current)
                            Icon(Icons.check, color: colors.brandPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
