package com.rees46.rees46_flutter_sdk

import android.content.Context
import android.content.SharedPreferences

/**
 * The slides of the UI kit's stories (V2) the user has seen, per shop: one preferences file
 * per shop, a key per story id holding the set of seen slide ids. It survives app restarts, so a
 * story reopens at its first unseen slide and its cover keeps the seen segments.
 *
 * The plugin's own store, not the native SDK's: the Flutter viewer is drawn in Dart, and the
 * native SDK keeps no such state for it.
 */
internal object StoriesSeenStore {

    private const val PREFS_PREFIX = "rees46_flutter_stories_seen_"

    /** Seen slide ids by story id for [shop]; empty when nothing was seen yet. */
    fun read(context: Context, shop: String): Map<String, List<String>> =
        prefs(context, shop).all.mapNotNull { (storyId, value) ->
            (value as? Set<*>)?.filterIsInstance<String>()?.let { storyId to it.sorted() }
        }.toMap()

    /** Adds [slideId] to the seen slides of [storyId] for [shop]. */
    fun add(context: Context, shop: String, storyId: String, slideId: String) {
        val prefs = prefs(context, shop)
        // The returned set must not be modified in place: copy it.
        val seen = prefs.getStringSet(storyId, null).orEmpty()
        if (slideId in seen) return
        prefs.edit().putStringSet(storyId, seen + slideId).apply()
    }

    // The shop id becomes part of a file name: anything but letters, digits, `-` and `_` is
    // replaced.
    private fun prefs(context: Context, shop: String): SharedPreferences =
        context.getSharedPreferences(
            PREFS_PREFIX + shop.replace(Regex("[^A-Za-z0-9_-]"), "_"),
            Context.MODE_PRIVATE,
        )
}
