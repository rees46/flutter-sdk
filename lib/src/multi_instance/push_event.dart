/// Push lifecycle event routed by [REES46.handlePush].
///
/// The Flutter vocabulary — `received` / `delivered` / `clicked` — matches the
/// SDK's released push callbacks. On the wire, on both platforms: [received] (the
/// push reached the app) is `track/delivered`, [delivered] (its notification is on
/// screen) is `track/opened`, and [clicked] is `track/clicked`.
///
/// The declaration ORDER is a wire contract — the enum index is sent to native
/// through the Pigeon `handlePush`. Do not reorder.
enum PushEvent { received, delivered, clicked }
