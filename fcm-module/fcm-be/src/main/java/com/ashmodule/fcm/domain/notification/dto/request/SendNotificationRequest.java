package com.ashmodule.fcm.domain.notification.dto.request;

import java.util.Map;

/**
 * 단건 발송 요청 (HTTP 역직렬화용). 모듈의 빌더 전용 DTO 로 매핑한다.
 */
public record SendNotificationRequest(
        String token,
        String title,
        String body,
        String image,
        String sound,
        String clickAction,
        Map<String, String> data
) {
    public NotificationSendRequest toServiceRequest() {
        return NotificationSendRequest.builder()
                .token(token)
                .title(title)
                .body(body)
                .image(image)
                .sound(sound)
                .clickAction(clickAction)
                .data(data)
                .build();
    }
}
