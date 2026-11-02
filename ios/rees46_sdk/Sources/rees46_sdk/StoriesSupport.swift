import AVFoundation
import Foundation

/// The slides of the UI kit's stories (V2) the user has seen, per shop: one UserDefaults entry
/// per shop, `[storyId: [slideId]]`. It survives app restarts, so a story reopens at its first
/// unseen slide and its cover keeps the seen segments.
///
/// The plugin's own store, not the native SDK's: the Flutter viewer is drawn in Dart.
enum StoriesSeenStore {
  private static let keyPrefix = "rees46_flutter_stories_seen."

  /// Seen slide ids by story id for `shop`; empty when nothing was seen yet.
  static func read(shop: String) -> [String: [String]] {
    let stored = UserDefaults.standard.dictionary(forKey: keyPrefix + shop) ?? [:]
    var result: [String: [String]] = [:]
    for (storyId, value) in stored {
      if let slides = value as? [String] { result[storyId] = slides }
    }
    return result
  }

  /// Adds `slideId` to the seen slides of `storyId` for `shop`.
  static func add(shop: String, storyId: String, slideId: String) {
    var stored = read(shop: shop)
    var slides = stored[storyId] ?? []
    if slides.contains(slideId) { return }
    slides.append(slideId)
    stored[storyId] = slides
    UserDefaults.standard.set(stored, forKey: keyPrefix + shop)
  }
}

/// The audio session while the stories viewer plays video.
///
/// - `begin` saves the app's session before the first video, `end` puts it back when the
///   viewer closes.
/// - Muted, the session is `ambient`: video never interrupts other apps' audio (the user's
///   music keeps playing). Unmuted, it is `playback`: the story's sound takes over.
/// - While active, the session's `outputVolume` is watched: the hardware volume going up is
///   reported through `onVolumeUp`, and the viewer unmutes.
final class StoriesAudio {
  static let shared = StoriesAudio()

  /// The hardware volume went up while the viewer plays video. Called on the main queue.
  var onVolumeUp: (() -> Void)?

  private var saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                      options: AVAudioSession.CategoryOptions)?
  private var volumeObservation: NSKeyValueObservation?
  /// The viewer played sound and so took the audio from other apps.
  private var tookAudio = false

  func begin() {
    guard saved == nil else { return }
    let session = AVAudioSession.sharedInstance()
    saved = (session.category, session.mode, session.categoryOptions)
  }

  func update(muted: Bool) {
    begin()
    let session = AVAudioSession.sharedInstance()
    if muted {
      try? session.setCategory(.ambient, mode: .default, options: [])
    } else {
      try? session.setCategory(.playback, mode: .default, options: [])
      tookAudio = true
    }
    // The volume is observable only on an active session; `ambient` mixes with other audio.
    try? session.setActive(true)
    observeVolume()
  }

  func end() {
    volumeObservation?.invalidate()
    volumeObservation = nil
    guard let saved = saved else { return }
    self.saved = nil
    let session = AVAudioSession.sharedInstance()
    // Deactivated before the category goes back, so a non-mixable category the app had does
    // not take over the audio here. After sound played, the app whose audio the story
    // interrupted is told it may resume. Fails harmlessly while something else still plays.
    try? session.setActive(false, options: tookAudio ? .notifyOthersOnDeactivation : [])
    try? session.setCategory(saved.category, mode: saved.mode, options: saved.options)
    tookAudio = false
  }

  private func observeVolume() {
    guard volumeObservation == nil else { return }
    volumeObservation = AVAudioSession.sharedInstance().observe(
      \.outputVolume, options: [.old, .new]
    ) { [weak self] _, change in
      guard let old = change.oldValue, let new = change.newValue, new > old else { return }
      DispatchQueue.main.async { self?.onVolumeUp?() }
    }
  }
}
