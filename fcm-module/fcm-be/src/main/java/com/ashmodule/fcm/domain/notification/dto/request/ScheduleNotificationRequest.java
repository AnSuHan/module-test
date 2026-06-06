package com.ashmodule.fcm.domain.notification.dto.request;

import com.ashmodule.fcm.domain.notification.entity.ScheduledNotification;

import java.time.LocalDateTime;

/**
 * 예약 발송 요청 (HTTP 역직렬화용). token 또는 topic 중 하나를 지정한다.
 */
public record ScheduleNotificationRequest(
        String token,
        String topic,
        String title,
        String body,
        String image,
        String sound,
        String clickAction,
        LocalDateTime scheduledAt
) {
    public ScheduledNotification toEntity() {
        return ScheduledNotification.builder()
                .targetToken(token)
                .targetTopic(topic)
                .title(title)
                .body(body)
                .image(image)
                .sound(sound)
                .clickAction(clickAction)
                .scheduledAt(scheduledAt)
                .build();
    }
}
