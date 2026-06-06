package com.ashmodule.fcm.domain.notification.dto.request;

import java.util.List;
import java.util.Map;

/**
 * 멀티캐스트(다중 토큰) 발송 요청 (HTTP 역직렬화용).
 */
public record SendMulticastRequest(
        List<String> tokens,
        String title,
        String body,
        String image,
        String sound,
        String clickAction,
        Map<String, String> data
) {
    public MulticastNotificationRequest toServiceRequest() {
        return MulticastNotificationRequest.builder()
                .tokens(tokens)
                .title(title)
                .body(body)
                .image(image)
                .sound(sound)
                .clickAction(clickAction)
                .data(data)
                .build();
    }
}
