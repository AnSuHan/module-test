package com.ashmodule.fcm.domain.notification.controller;

import com.ashmodule.fcm.domain.notification.service.FcmTokenManagementService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * FCM 토큰 관리 HTTP API.
 */
@RestController
@RequestMapping("/api/fcm-tokens")
@RequiredArgsConstructor
public class FcmTokenController {

    private final FcmTokenManagementService tokenService;

    /** 토큰 유효성 확인 */
    @GetMapping("/{token}/valid")
    public Map<String, Boolean> isValid(@PathVariable String token) {
        return Map.of("valid", tokenService.isTokenValid(token));
    }

    /** 토큰 만료 처리 */
    @PostMapping("/{token}/invalidate")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void invalidate(@PathVariable String token,
                           @RequestParam(required = false, defaultValue = "MANUAL") String reason) {
        tokenService.invalidateToken(token, reason);
    }
}
