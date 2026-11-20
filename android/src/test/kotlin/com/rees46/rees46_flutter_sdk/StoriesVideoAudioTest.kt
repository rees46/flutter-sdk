package com.rees46.rees46_flutter_sdk

import java.util.concurrent.Executor
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class StoriesVideoAudioTest {
    /** Runs the work when asked, so the order of the threads is visible. */
    private class Queue : Executor {
        val tasks = mutableListOf<Runnable>()
        override fun execute(command: Runnable) {
            tasks += command
        }

        fun run() {
            val pending = tasks.toList()
            tasks.clear()
            pending.forEach { it.run() }
        }
    }

    @Test
    fun theProbeRunsOffTheCallerAndTheAnswerComesOnTheMainThread() {
        val worker = Queue()
        val main = Queue()
        val probed = mutableListOf<String>()
        val audio = StoriesVideoAudio(
            probe = { probed += it; true },
            worker = worker,
            main = { main.execute(it) },
        )
        val answers = mutableListOf<Result<Boolean?>>()
        audio.hasAudio("https://cdn.example/v.mp4") { answers += it }
        assertTrue(probed.isEmpty(), "not on the caller's thread")
        worker.run()
        assertEquals(listOf("https://cdn.example/v.mp4"), probed)
        assertTrue(answers.isEmpty(), "the reply waits for the main thread")
        main.run()
        assertEquals(true, answers.single().getOrNull())
    }

    @Test
    fun noAudioIsFalseAndAFailedReadIsNull() {
        val direct = Executor { it.run() }
        val answers = mutableListOf<Boolean?>()
        StoriesVideoAudio(probe = { false }, worker = direct, main = { it.run() })
            .hasAudio("/cache/v.mp4") { answers += it.getOrThrow() }
        StoriesVideoAudio(
            probe = { throw IllegalStateException("broken") },
            worker = direct,
            main = { it.run() },
        ).hasAudio("/cache/v.mp4") { answers += it.getOrThrow() }
        StoriesVideoAudio(probe = { null }, worker = direct, main = { it.run() })
            .hasAudio("x") { answers += it.getOrThrow() }
        assertEquals(listOf<Boolean?>(false, null, null), answers)
    }

    @Test
    fun httpAddressesAreRemoteTheRestAreFiles() {
        assertTrue(StoriesVideoAudio.isRemote("https://cdn.example/v.mp4"))
        assertTrue(StoriesVideoAudio.isRemote("HTTP://cdn.example/v.mp4"))
        assertFalse(StoriesVideoAudio.isRemote("/data/user/0/app/cache/stories/v.mp4"))
        assertFalse(StoriesVideoAudio.isRemote("file:///cache/v.mp4"))
    }

    @Test
    fun thePluginAnswersThroughIt() {
        val plugin = Rees46FlutterSdkPlugin()
        plugin.storiesVideoAudio = StoriesVideoAudio(
            probe = { it.endsWith("sound.mp4") },
            worker = { it.run() },
            main = { it.run() },
        )
        val answers = mutableListOf<Boolean?>()
        plugin.storiesVideoHasAudio("https://cdn.example/sound.mp4") { answers += it.getOrThrow() }
        plugin.storiesVideoHasAudio("https://cdn.example/mute.mp4") { answers += it.getOrThrow() }
        assertEquals(listOf<Boolean?>(true, false), answers)
    }
}
