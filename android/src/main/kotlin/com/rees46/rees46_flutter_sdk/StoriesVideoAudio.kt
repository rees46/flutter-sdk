package com.rees46.rees46_flutter_sdk

import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * Whether a stories video has an audio track: the viewer shows its sound button only then, as
 * the web SDK does. The container is read off the main thread (a network video reads its
 * header over the network) and the answer goes back on the main thread, where Pigeon replies.
 */
internal class StoriesVideoAudio(
    private val probe: (String) -> Boolean? = ::readHasAudio,
    private val worker: Executor = defaultWorker,
    private val main: (Runnable) -> Unit = { mainHandler.post(it) },
) {

    /** Answers [callback] with the audio of [source]: null when it cannot be read. */
    fun hasAudio(source: String, callback: (Result<Boolean?>) -> Unit) {
        worker.execute {
            val answer = try {
                probe(source)
            } catch (e: Exception) {
                null
            }
            main(Runnable { callback(Result.success(answer)) })
        }
    }

    companion object {
        private val defaultWorker: Executor by lazy { Executors.newSingleThreadExecutor() }
        private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

        /** `http(s)` addresses are read over the network, anything else is a file path. */
        fun isRemote(source: String): Boolean =
            source.startsWith("http://", ignoreCase = true) ||
                source.startsWith("https://", ignoreCase = true)

        /**
         * `METADATA_KEY_HAS_AUDIO` is there only when the container has an audio track; null
         * when the source cannot be opened.
         */
        fun readHasAudio(source: String): Boolean? {
            val retriever = MediaMetadataRetriever()
            return try {
                if (isRemote(source)) {
                    retriever.setDataSource(source, emptyMap())
                } else {
                    retriever.setDataSource(source)
                }
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) != null
            } catch (e: Exception) {
                null
            } finally {
                try {
                    retriever.release()
                } catch (e: Exception) {
                    // Nothing was opened.
                }
            }
        }
    }
}
