package com.rees46.rees46_flutter_sdk

import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Whether a stories video has an audio track: the viewer hides its sound button only when the
 * track list says there is none. The container is read off the main thread (a network video
 * reads its header over the network), each read on a thread of its own, so a read that hangs
 * does not hold the next ones. A read that is not done in [timeoutMs] answers null
 * (inconclusive: the button stays). The answer goes back on the main thread, where Pigeon
 * replies, exactly once.
 */
internal class StoriesVideoAudio(
    private val probe: (String) -> Boolean? = ::readHasAudio,
    private val worker: Executor = defaultWorker,
    private val main: (Runnable) -> Unit = { mainHandler.post(it) },
    private val schedule: (Long, Runnable) -> Unit = { delay, task ->
        mainHandler.postDelayed(task, delay)
    },
    private val timeoutMs: Long = TIMEOUT_MS,
) {

    /** Answers [callback] with the audio of [source]: null when it cannot be read in time. */
    fun hasAudio(source: String, callback: (Result<Boolean?>) -> Unit) {
        val answered = AtomicBoolean(false)
        fun reply(answer: Boolean?) {
            if (answered.compareAndSet(false, true)) {
                main(Runnable { callback(Result.success(answer)) })
            }
        }
        schedule(timeoutMs, Runnable { reply(null) })
        try {
            worker.execute {
                val answer = try {
                    probe(source)
                } catch (e: Exception) {
                    null
                }
                reply(answer)
            }
        } catch (e: Exception) {
            // No thread for the read: inconclusive.
            reply(null)
        }
    }

    companion object {
        /** How long a read may take before the answer is inconclusive. */
        const val TIMEOUT_MS = 5_000L

        /** A thread per read, kept a minute for the next one; daemon threads. */
        private val defaultWorker: Executor by lazy {
            Executors.newCachedThreadPool { task ->
                Thread(task, "rees46-stories-audio").apply { isDaemon = true }
            }
        }
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
