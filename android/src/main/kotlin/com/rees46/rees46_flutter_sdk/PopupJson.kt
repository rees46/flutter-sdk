package com.rees46.rees46_flutter_sdk

import com.personalization.sdk.data.models.dto.popUp.PopupDto
import org.json.JSONObject

/**
 * The popup as the server sends it — the keys the native SDK parsed it from — so Dart reads
 * one shape from both platforms.
 */
internal fun PopupDto.toJson(): JSONObject = JSONObject().apply {
    put("id", id)
    put("position", position.value)
    put("delay", delay)
    components?.let { components ->
        put(
            "components",
            JSONObject()
                .put("header", components.header)
                .put("text", components.text)
                .put("image", components.image)
                .put("button", components.button)
                .put("header_enabled", components.headerEnabled)
                .put("text_enabled", components.textEnabled)
                .put("image_enabled", components.imageEnabled),
        )
    }
    popupActions?.let { actions ->
        val json = JSONObject()
        actions.link?.let { link ->
            json.put(
                "link",
                JSONObject()
                    .put("link_android", link.linkAndroid)
                    .put("link_ios", link.linkIos)
                    .put("link_web", link.linkWeb)
                    .put("button_text", link.buttonText),
            )
        }
        actions.close?.let { json.put("close", JSONObject().put("button_text", it.buttonText)) }
        actions.pushSubscribe?.let {
            json.put("system_mobile_push_subscribe", JSONObject().put("button_text", it.buttonText))
        }
        put("popup_actions", json)
    }
}
