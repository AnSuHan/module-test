package com.ashmodule.fcm.domain.notification.controller;

import com.ashmodule.fcm.domain.notification.dto.request.ScheduleNotificationRequest;
import com.ashmodule.fcm.domain.notification.service.NotificationScheduleService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

/**
 * 예약 발송 HTTP API. 실제 발송은 모듈의 스케줄러(@Scheduled, 매 분)가 처리한다.
 */
@RestController
@RequestMapping("/api/notifications/scheduled")
@RequiredArgsConstructor
public class ScheduledNotificationController {

    private final NotificationScheduleService scheduleService;

    /** 알림 발송 예약 */
    @PostMapping
    @ResponseStatus(HttpStatus.ACCEPTED)
    public void schedule(@RequestBody ScheduleNotificationRequest request) {
        scheduleService.schedule(request.toEntity());
    }
}
