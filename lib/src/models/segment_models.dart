// Models of the SDK contract, as the native SDKs hand them over.

/// A segment the customer is in ([SegmentsApi.get]).
class Segment {
  const Segment({required this.id, this.type = ''});

  final int id;

  /// `dynamic`, `static`, `less_often`, `rfm`, … — an open set; `""` when the
  /// server gives the segment none.
  final String type;
}
