package com.ashmodule.fcm.domain.notification.dto.request;

import java.util.Map;

/**
 * 토픽 발송 요청 (HTTP 역직렬화용).
 */
public record SendTopicRequest(
        String topic,
        String title,
        String body,
        String image,
        String sound,
        String clickAction,
        Map<String, String> data
) {
    public TopicNotificationRequest toServiceRequest() {
        return TopicNotificationRequest.builder()
                .topic(topic)
                .title(title)
                .body(body)
                .image(image)
                .sound(sound)
                .clickAction(clickAction)
                .data(data)
                .build();
    }
}
