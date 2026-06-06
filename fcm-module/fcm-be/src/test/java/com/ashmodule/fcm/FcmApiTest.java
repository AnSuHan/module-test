package com.ashmodule.fcm;

import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class FcmApiTest {

    private MockMvc mockMvc;

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();
    }

    @Test
    @DisplayName("토큰 유효성 검사 및 갱신 API 테스트")
    void tokenApiTest() throws Exception {
        String token = "test-token-123";

        // 1. 초기 상태: 유효함
        mockMvc.perform(get("/api/fcm-tokens/{token}/valid", token)
                .with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(true));

        // 2. 토큰 만료 처리
        mockMvc.perform(post("/api/fcm-tokens/{token}/invalidate", token)
                .with(user("admin").roles("ADMIN")).with(csrf()))
                .andExpect(status().isNoContent());

        // 3. 만료 후 상태: 유효하지 않음
        mockMvc.perform(get("/api/fcm-tokens/{token}/valid", token)
                .with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false));
    }

    @Test
    @DisplayName("알림 발송 API 테스트 (키 미등록으로 실패 리턴 확인)")
    void sendApiTest() throws Exception {
        Map<String, Object> request = Map.of(
                "token", "test-token",
                "title", "API Test Title",
                "body", "API Test Body"
        );

        // 단건 발송 - 실패 응답이 정상적으로 돌아와야 함 (무한 대기 없이)
        mockMvc.perform(post("/api/notifications")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .with(user("admin").roles("ADMIN")).with(csrf()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    @DisplayName("토픽 및 멀티캐스트 발송 API 테스트")
    void bulkSendApiTest() throws Exception {
        // 토픽 발송
        Map<String, Object> topicRequest = Map.of(
                "topic", "news",
                "title", "Topic Title",
                "body", "Topic Body"
        );
        mockMvc.perform(post("/api/notifications/topic")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(topicRequest))
                .with(user("admin").roles("ADMIN")).with(csrf()))
                .andExpect(status().isOk());

        // 멀티캐스트 발송
        Map<String, Object> multicastRequest = Map.of(
                "tokens", List.of("token1", "token2"),
                "title", "Multicast Title",
                "body", "Multicast Body"
        );
        mockMvc.perform(post("/api/notifications/multicast")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(multicastRequest))
                .with(user("admin").roles("ADMIN")).with(csrf()))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("발송 이력 및 통계 조회 API 테스트")
    void queryApiTest() throws Exception {
        // 이력 조회
        mockMvc.perform(get("/api/notifications")
                .with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON));

        // 통계 조회
        mockMvc.perform(get("/api/notifications/statistics")
                .with(user("admin").roles("ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCount").exists());
    }

    @Test
    @DisplayName("알림 예약 API 테스트")
    void scheduleApiTest() throws Exception {
        Map<String, Object> request = Map.of(
                "token", "test-token",
                "title", "Scheduled Title",
                "body", "Scheduled Body",
                "scheduledAt", LocalDateTime.now().plusDays(1).toString()
        );

        mockMvc.perform(post("/api/notifications/scheduled")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .with(user("admin").roles("ADMIN")).with(csrf()))
                .andExpect(status().isAccepted());
    }
}
