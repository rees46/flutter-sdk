/// Push lifecycle event routed by [Rees46.handlePush].
///
/// The Flutter vocabulary — `received` / `delivered` / `clicked` — matches the
/// SDK's existing push callbacks. Native maps it to its own set: Android
/// `PushEventType` has no `delivered`, so both `delivered` and `received` track
/// `track/received`; iOS `PushEvent` keeps `delivered` as a distinct beacon.
///
/// The declaration ORDER is a wire contract — the enum index is sent to native
/// through the Pigeon `handlePush`. Do not reorder.
enum PushEvent { received, delivered, clicked }
