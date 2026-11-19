// Models of the SDK contract, as the native SDKs hand them over.

/// How likely the customer is to buy.
class PurchaseProbability {
  const PurchaseProbability({required this.probability, this.clientId});

  /// From 0 to 1.
  final double probability;

  /// The customer on the server; none for one it does not know.
  final String? clientId;
}
