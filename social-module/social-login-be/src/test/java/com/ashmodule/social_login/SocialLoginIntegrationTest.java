package com.ashmodule.social_login;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class SocialLoginIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("Google 인가 URL 요청 시 200 OK와 함께 authorizationUrl, state를 반환해야 한다")
    void givenGoogleProvider_whenAuthorize_thenReturnsUrlAndState() throws Exception {
        mockMvc.perform(get("/auth/social/google/authorize"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.authorizationUrl").exists())
                .andExpect(jsonPath("$.state").exists());
    }

    @Test
    @DisplayName("등록되지 않은 공급자로 인가 요청 시 404 Not Found를 반환해야 한다")
    void givenUnsupportedProvider_whenAuthorize_thenReturns404() throws Exception {
        mockMvc.perform(get("/auth/social/unsupported/authorize"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("UNSUPPORTED_PROVIDER"));
    }

    @Test
    @DisplayName("잘못된 state로 로그인 요청 시 401 Unauthorized를 반환해야 한다")
    void givenInvalidState_whenLogin_thenReturns401() throws Exception {
        String requestBody = """
                {
                    "code": "dummy-code",
                    "state": "invalid-state"
                }
                """;

        mockMvc.perform(post("/auth/social/google/login")
                        .contentType("application/json")
                        .content(requestBody))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_STATE"));
    }
}
