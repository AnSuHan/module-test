package com.ashmodule.fcm.domain.notification.controller;

import com.ashmodule.fcm.domain.notification.dto.request.SendMulticastRequest;
import com.ashmodule.fcm.domain.notification.dto.request.SendNotificationRequest;
import com.ashmodule.fcm.domain.notification.dto.request.SendTopicRequest;
import com.ashmodule.fcm.domain.notification.dto.response.MulticastResponse;
import com.ashmodule.fcm.domain.notification.dto.response.NotificationResponse;
import com.ashmodule.fcm.domain.notification.dto.response.NotificationStatisticsResponse;
import com.ashmodule.fcm.domain.notification.entity.Notification;
import com.ashmodule.fcm.domain.notification.service.NotificationLookupService;
import com.ashmodule.fcm.domain.notification.service.NotificationSendService;
import com.ashmodule.fcm.domain.notification.service.NotificationStatisticsService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 알림 발송/조회/통계 HTTP API. 비즈니스 로직은 모듈이 제공하는 서비스에 위임한다.
 */
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private static final Logger log = LoggerFactory.getLogger(NotificationController.class);

    private final NotificationSendService sendService;
    private final NotificationLookupService lookupService;
    private final NotificationStatisticsService statisticsService;

    /** 토큰을 로그에 그대로 남기지 않도록 앞 12자만 노출. */
    private static String mask(String token) {
        if (token == null) return "null";
        return token.length() <= 12 ? token : token.substring(0, 12) + "...(" + token.length() + ")";
    }

    /** 단건 발송 (서버 측 재시도 포함) */
    @PostMapping
    public NotificationResponse send(@RequestBody SendNotificationRequest request) {
        log.info("[발송요청] 단건 token={} title='{}' body='{}'",
                mask(request.token()), request.title(), request.body());
        NotificationResponse response = sendService.send(request.toServiceRequest());
        log.info("[발송결과] 단건 success={} messageId={} error={}",
                response.isSuccess(), response.getMessageId(), response.getErrorMessage());
        return response;
    }

    /** 토픽 발송 */
    @PostMapping("/topic")
    public NotificationResponse sendToTopic(@RequestBody SendTopicRequest request) {
        log.info("[발송요청] 토픽 topic={} title='{}'", request.topic(), request.title());
        NotificationResponse response = sendService.sendToTopic(request.toServiceRequest());
        log.info("[발송결과] 토픽 success={} messageId={} error={}",
                response.isSuccess(), response.getMessageId(), response.getErrorMessage());
        return response;
    }

    /** 멀티캐스트(다중 토큰) 발송 */
    @PostMapping("/multicast")
    public MulticastResponse sendMulticast(@RequestBody SendMulticastRequest request) {
        int count = request.tokens() == null ? 0 : request.tokens().size();
        log.info("[발송요청] 멀티캐스트 tokens={}개 title='{}'", count, request.title());
        return sendService.sendMulticast(request.toServiceRequest());
    }

    /** 발송 이력 조회. token 또는 topic 파라미터로 필터링, 없으면 전체 */
    @GetMapping
    public List<Notification> list(@RequestParam(required = false) String token,
                                   @RequestParam(required = false) String topic) {
        if (token != null) {
            return lookupService.findByToken(token);
        }
        if (topic != null) {
            return lookupService.findByTopic(topic);
        }
        return lookupService.findAll();
    }

    /** 발송 통계. start/end(ISO-8601) 둘 다 주면 기간 통계, 없으면 전체 */
    @GetMapping("/statistics")
    public NotificationStatisticsResponse statistics(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime start,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime end) {
        return statisticsService.getStatistics(start, end);
    }
}
