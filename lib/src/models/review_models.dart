// Models of the SDK contract, as the native SDKs hand them over.

import 'values.dart';

/// A rating the server saved.
class PollReview {
  const PollReview({required this.id});

  /// 64-bit; a repeat on the same day gives the earlier review's id.
  final int id;
}

/// An NPS category: what is rated, with the question and the thanks per answer.
class NpsCategory {
  const NpsCategory({
    required this.code,
    required this.name,
    this.detractorQuestion,
    this.passiveQuestion,
    this.promoterQuestion,
    this.detractorSuccess,
    this.passiveSuccess,
    this.promoterSuccess,
    this.buttonLabel,
  });

  final String code;

  final String name;

  final String? detractorQuestion;

  final String? passiveQuestion;

  final String? promoterQuestion;

  final String? detractorSuccess;

  final String? passiveSuccess;

  final String? promoterSuccess;

  final String? buttonLabel;
}

/// A CSAT campaign.
class CsatCampaign {
  const CsatCampaign({
    required this.code,
    required this.name,
    this.dissatisfiedQuestion,
    this.neutralQuestion,
    this.satisfiedQuestion,
    this.dissatisfiedSuccess,
    this.neutralSuccess,
    this.satisfiedSuccess,
    this.buttonLabel,
  });

  final String code;

  final String name;

  final String? dissatisfiedQuestion;

  final String? neutralQuestion;

  final String? satisfiedQuestion;

  final String? dissatisfiedSuccess;

  final String? neutralSuccess;

  final String? satisfiedSuccess;

  final String? buttonLabel;
}

/// A CES campaign.
class CesCampaign {
  const CesCampaign({
    required this.code,
    required this.name,
    this.difficultQuestion,
    this.neutralQuestion,
    this.easyQuestion,
    this.difficultSuccess,
    this.neutralSuccess,
    this.easySuccess,
    this.buttonLabel,
  });

  final String code;

  final String name;

  final String? difficultQuestion;

  final String? neutralQuestion;

  final String? easyQuestion;

  final String? difficultSuccess;

  final String? neutralSuccess;

  final String? easySuccess;

  final String? buttonLabel;
}

/// A channel of ratings, common to NPS, CSAT and CES.
class PollChannel {
  const PollChannel({required this.code, required this.name});

  final String code;

  final String name;
}

/// The rating of a product over all its published reviews.
class ProductRatingSummary {
  const ProductRatingSummary({
    required this.count,
    this.averageRating,
    required this.ratings,
  });

  final int count;

  /// None without reviews.
  final double? averageRating;

  /// Reviews per star.
  final Map<int, int> ratings;
}

/// A published review of a product.
class ProductReview {
  const ProductReview({
    required this.id,
    required this.rating,
    this.comment,
    this.author,
    required this.createdAt,
  });

  /// 64-bit.
  final int id;

  final int rating;

  final String? comment;

  final String? author;

  /// ISO 8601.
  final String createdAt;
}

/// The reviews of a product and its rating.
class ProductReviewsResponse {
  const ProductReviewsResponse({required this.summary, required this.reviews});

  final ProductRatingSummary summary;

  /// The page asked for, newest first.
  final List<ProductReview> reviews;
}

/// A review the customer wrote in an order, in any state of moderation.
class ClientReview {
  const ClientReview({
    required this.id,
    required this.itemId,
    required this.orderId,
    required this.rating,
    this.comment,
    this.state,
    required this.createdAt,
  });

  /// 64-bit.
  final int id;

  final String itemId;

  final String orderId;

  final int rating;

  final String? comment;

  /// None for a state this release does not know.
  final ReviewState? state;

  /// ISO 8601.
  final String createdAt;
}
