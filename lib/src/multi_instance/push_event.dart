/// What happened to a push, for [REES46.handlePush]: each is its own request,
/// `track/delivered`, `track/opened`, `track/clicked` or `track/closed`.
enum PushEvent {
  /// The push reached the app.
  delivered,

  /// Its notification was shown.
  opened,

  /// The notification was tapped.
  clicked,

  /// The notification was dismissed without a tap.
  closed,
}
