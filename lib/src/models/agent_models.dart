// Models of the SDK contract, as the native SDKs hand them over.

import 'values.dart';

/// A product in an answer of the search agent, with its current price and stock.
class AgentProduct {
  const AgentProduct({
    required this.id,
    this.name,
    this.price,
    this.oldPrice,
    this.priceFormatted,
    this.oldPriceFormatted,
    this.picture,
    this.url,
    this.reason,
  });

  final String id;

  final String? name;

  final double? price;

  final double? oldPrice;

  final String? priceFormatted;

  final String? oldPriceFormatted;

  final String? picture;

  /// The product's page; it carries the agent's attribution.
  final String? url;

  /// Why the agent picked it.
  final String? reason;
}

/// A message of a dialog with the search agent.
class AgentMessage {
  const AgentMessage({
    required this.id,
    this.role,
    this.content,
    this.createdAt,
    required this.products,
  });

  /// 64-bit.
  final int id;

  /// Who wrote it.
  final AgentMessageRole? role;

  final String? content;

  /// ISO 8601.
  final String? createdAt;

  /// The products of the agent's answer; empty for the customer's messages.
  final List<AgentProduct> products;
}

/// A dialog session with the search agent.
class AgentSession {
  const AgentSession({
    required this.id,
    this.title,
    this.updatedAt,
    required this.messages,
  });

  /// 64-bit.
  final int id;

  final String? title;

  /// ISO 8601.
  final String? updatedAt;

  /// Empty in the list of sessions and in [AgentResponse].
  final List<AgentMessage> messages;
}

/// The customer's dialog with the search agent: [sessions] (the last 20, newest first, without messages) and the messages of [session].
class AgentDialogResponse {
  const AgentDialogResponse({required this.sessions, this.session});

  final List<AgentSession> sessions;

  /// None while the customer has no session.
  final AgentSession? session;
}

/// The search agent's answer to a message.
class AgentResponse {
  const AgentResponse({required this.session, required this.message});

  /// The session the message went to (a new one without a `sessionId`), without messages.
  final AgentSession session;

  /// The agent's answer.
  final AgentMessage message;
}
