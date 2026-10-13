package kg.oliver;

import com.fasterxml.jackson.databind.*;
import kg.oliver.auth.RedisEphemeralStore;
import kg.oliver.repository.Store;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.data.redis.core.StringRedisTemplate;
import software.amazon.awssdk.services.s3.S3Client;
import java.time.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") class ApiIntegrationTest {
    @Autowired @org.springframework.beans.factory.annotation.Qualifier("clientInboundChannel") org.springframework.messaging.support.AbstractSubscribableChannel inbound;
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired Store db;
    @MockitoBean RedisEphemeralStore cache;
    @MockitoBean JavaMailSender mail;
    @MockitoBean S3Client s3;
    @MockitoBean(name = "chatListener") RedisMessageListenerContainer listener;
    @MockitoBean StringRedisTemplate redis;
    record Entry(String value, Instant expires) {}
    final Map<String, Entry> data = new ConcurrentHashMap<>();
    final List<SimpleMailMessage> letters = new ArrayList<>();
    @BeforeEach void setup() {
        data.clear();
        letters.clear();
        reset(cache, mail);
        doAnswer(i -> {
            data.put(i.getArgument(0), new Entry(i.getArgument(1), Instant.now().plus(i.<Duration>getArgument(2))));
            return null;
        }
        ).when(cache).put(anyString(), anyString(), any());
        when(cache.get(anyString())).thenAnswer(i -> get(i.getArgument(0)));
        when(cache.take(anyString())).thenAnswer(i -> {
            String k = i.getArgument(0);
            String v = get(k);
            data.remove(k);
            return v;
        }
        );
        doAnswer(i -> {
            data.remove(i.<String>getArgument(0));
            return null;
        }
        ).when(cache).delete(anyString());
        when(cache.consume(anyString(), anyString())).thenAnswer(i -> {
            String k = i.getArgument(0);
            if (Objects.equals(get(k), i.getArgument(1))) {
                data.remove(k);
                return true;
            }
            return false;
        }
        );
        when(cache.replace(anyString(), anyString(), anyString(), any())).thenAnswer(i -> {
            String k = i.getArgument(0);
            if (!Objects.equals(get(k), i.getArgument(1)))return false;
            data.put(k, new Entry(i.getArgument(2), Instant.now().plus(i.<Duration>getArgument(3))));
            return true;
        }
        );
        when(cache.increment(anyString(), any())).thenAnswer(i -> {
            String k = i.getArgument(0);
            String v = get(k);
            long n = v == null?1:Long.parseLong(v) + 1;
            data.put(k, new Entry(Long.toString(n), v == null?Instant.now().plus(i.<Duration>getArgument(1)):data.get(k).expires()));
            return n;
        }
        );
        doAnswer(i -> {
            letters.add(i.getArgument(0));
            return null;
        }
        ).when(mail).send(any(SimpleMailMessage.class));
    }
    String get(String k) {
        Entry e = data.get(k);
        return e == null || e.expires().isBefore(Instant.now())?null:e.value();
    }
    JsonNode call(String method, String path, Object body, String token, int status)throws Exception {
        var request = MockMvcRequestBuilders.request(org.springframework.http.HttpMethod.valueOf(method), path);
        if (body != null)request.contentType("application/json").content(json.writeValueAsBytes(body));
        if (token != null)request.header("Authorization", "Bearer " + token);
        String out = mvc.perform(request).andExpect(status().is(status)).andReturn().getResponse().getContentAsString();
        return out.isBlank()?json.nullNode():json.readTree(out);
    }
    JsonNode register(String label)throws Exception {
        return call("POST", "/api/v1/auth/register", Map.of("email", label + "@example.com", "phone", "+996" + String.format("%09d", Math.abs(label.hashCode())%1000000000), "fullName", label, "password", "Password123!", "confirmPassword", "Password123!"), null, 201);
    }
    JsonNode login(String label)throws Exception {
        var session = call("POST", "/api/v1/auth/login", Map.of("email", label + "@example.com", "password", "Password123!"), null, 200);
        var matcher = Pattern.compile("[0-9]{6}").matcher(letters.get(letters.size()-1).getText());
        assertThat(matcher.find()).isTrue();
        return call("POST", "/api/v1/auth/verify-2fa", Map.of("sessionId", session.get("sessionId").asText(), "code", matcher.group()), null, 200);
    }
    Map<String, Object> product() {
        return Map.of("title", "Телефон", "description", "В хорошем состоянии", "categoryId", 31, "price", 12500, "currency", "KGS", "regionId", 1, "cityId", 1, "phone", "+996555111222");
    }
    @Test void completeMarketplaceFlowAndAccessBoundaries()throws Exception {
        register("seller");
        var buyerUser = register("buyer");
        register("outsider");
        String seller = login("seller").get("accessToken").asText();
        String buyer = login("buyer").get("accessToken").asText();
        String outsider = login("outsider").get("accessToken").asText();
        assertThat(call("GET", "/api/v1/users/me", null, seller, 200).has("passwordHash")).isFalse();
        call("GET", "/api/v1/products/me", null, null, 401);
        String id = call("POST", "/api/v1/products", product(), seller, 201).get("id").asText();
        call("PATCH", "/api/v1/products/" + id, Map.of("title", "Чужое"), buyer, 403);
        call("DELETE", "/api/v1/products/" + id, null, buyer, 403);
        assertThat(call("GET", "/api/v1/products?q=телефон&categoryId=3&sort=price,asc", null, null, 200).get("total").asInt()).isGreaterThanOrEqualTo(1);
        call("POST", "/api/v1/favorites/" + id, null, buyer, 204);
        call("POST", "/api/v1/favorites/" + id, null, buyer, 204);
        assertThat(call("GET", "/api/v1/favorites/count", null, buyer, 200).get("count").asInt()).isEqualTo(1);
        assertThat(call("GET", "/api/v1/notifications/counters", null, seller, 200).get("newLikes").asInt()).isEqualTo(1);
        String comment = call("POST", "/api/v1/products/" + id + "/comments", Map.of("text", "Есть доставка?"), buyer, 201).get("id").asText();
        call("POST", "/api/v1/products/" + id + "/comments", Map.of("text", "Да", "parentCommentId", comment), seller, 201);
        call("POST", "/api/v1/comments/" + comment + "/like", null, seller, 200);
        assertThat(call("POST", "/api/v1/comments/" + comment + "/like", null, seller, 200).get("likesCount").asInt()).isEqualTo(1);
        call("DELETE", "/api/v1/comments/" + comment, null, seller, 403);
        assertThat(call("GET", "/api/v1/products/" + id + "/comments", null, null, 200).get("items").get(0).get("replies").size()).isEqualTo(1);
        String peer = call("GET", "/api/v1/users/me", null, seller, 200).get("id").asText();
        String chat = call("POST", "/api/v1/chats", Map.of("peerId", peer, "productId", id), buyer, 200).get("chatId").asText();
        assertThat(call("POST", "/api/v1/chats", Map.of("peerId", buyerUser.get("userId").asText()), seller, 200).get("chatId").asText()).isEqualTo(chat);
        call("GET", "/api/v1/chats/" + chat + "/messages", null, outsider, 403);
        call("POST", "/api/v1/chats/" + chat + "/messages", Map.of("type", "TEXT", "content", "Здравствуйте"), buyer, 201);
        call("POST", "/api/v1/chats/" + chat + "/messages", Map.of("type", "TEXT", "content", "Чужое"), outsider, 403);
        assertThat(call("GET", "/api/v1/notifications/counters", null, seller, 200).get("unreadMessages").asInt()).isEqualTo(1);
        call("POST", "/api/v1/chats/" + chat + "/read", null, seller, 204);
        assertThat(call("GET", "/api/v1/notifications/counters", null, seller, 200).get("unreadMessages").asInt()).isZero();
        call("DELETE", "/api/v1/products/" + id, null, seller, 204);
        call("GET", "/api/v1/products/" + id, null, null, 404);
    }
    @Test void twoFactorRotationResetAndLogout()throws Exception {
        register("authuser");
        var session = call("POST", "/api/v1/auth/login", Map.of("email", "authuser@example.com", "password", "Password123!"), null, 200);
        String sid = session.get("sessionId").asText();
        call("POST", "/api/v1/auth/resend-2fa", Map.of("sessionId", sid), null, 429);
        var matcher = Pattern.compile("[0-9]{6}").matcher(letters.get(letters.size()-1).getText());
        matcher.find();
        String code = matcher.group();
        call("POST", "/api/v1/auth/verify-2fa", Map.of("sessionId", sid, "code", code.equals("000000")?"000001":"000000"), null, 401);
        var tokens = call("POST", "/api/v1/auth/verify-2fa", Map.of("sessionId", sid, "code", code), null, 200);
        call("POST", "/api/v1/auth/verify-2fa", Map.of("sessionId", sid, "code", code), null, 401);
        String original = tokens.get("refreshToken").asText();
        var rotated = call("POST", "/api/v1/auth/refresh", Map.of("refreshToken", original), null, 200);
        call("POST", "/api/v1/auth/refresh", Map.of("refreshToken", original), null, 401);
        call("POST", "/api/v1/auth/logout", Map.of("refreshToken", rotated.get("refreshToken").asText()), null, 204);
        call("POST", "/api/v1/auth/refresh", Map.of("refreshToken", rotated.get("refreshToken").asText()), null, 401);
        var active = login("authuser");
        call("POST", "/api/v1/auth/forgot-password", Map.of("email", "authuser@example.com"), null, 200);
        String text = letters.get(letters.size()-1).getText();
        String resetToken = text.substring(text.indexOf("token=") + 6);
        call("POST", "/api/v1/auth/reset-password", Map.of("token", resetToken, "newPassword", "ChangedPassword123!"), null, 200);
        call("GET", "/api/v1/users/me", null, active.get("accessToken").asText(), 401);
        call("POST", "/api/v1/auth/refresh", Map.of("refreshToken", active.get("refreshToken").asText()), null, 401);
        call("POST", "/api/v1/auth/reset-password", Map.of("token", resetToken, "newPassword", "ChangedAgain123!"), null, 401);
        call("POST", "/api/v1/auth/login", Map.of("email", "authuser@example.com", "password", "Password123!"), null, 401);
    }
    @Test void validationAndPublicRoutes()throws Exception {
        call("GET", "/api/v1/categories", null, null, 200);
        assertThat(call("GET", "/api/v1/regions", null, null, 200).size()).isEqualTo(9);
        call("GET", "/api/v1/regions/1/cities", null, null, 200);
        call("GET", "/api/v1/products?page=-1", null, null, 400);
        call("GET", "/api/v1/products?sort=drop%20table", null, null, 400);
        call("POST", "/api/v1/auth/register", Map.of("email", "invalid"), null, 400);
        call("GET", "/api/v1/users/me", null, "broken", 401);
        call("GET", "/swagger-ui.html", null, null, 302);
        java.nio.file.Files.writeString(java.nio.file.Path.of("target/openapi.json"), json.writerWithDefaultPrettyPrinter().writeValueAsString(call("GET", "/v3/api-docs", null, null, 200)));
        call("GET", "/actuator/health", null, null, 200);
    }
    @Test void invalidMediaAndLocationAreRejected()throws Exception {
        register("validation");
        String token = login("validation").get("accessToken").asText();
        var p = new HashMap<>(product());
        p.put("cityId", 2);
        call("POST", "/api/v1/products", p, token, 409);
        p = new HashMap<>(product());
        p.put("media", List.of(Map.of("mediaId", UUID.randomUUID().toString())));
        call("POST", "/api/v1/products", p, token, 404);
        call("PATCH", "/api/v1/users/me", Map.of("avatarUrl", "https://evil.invalid/file"), token, 400);
        mvc.perform(MockMvcRequestBuilders.multipart("/api/v1/media/upload").file("file", "<script>alert(1)</script>".getBytes()).header("Authorization", "Bearer " + token)).andExpect(status().isBadRequest());
    }
    @Test void twoFactorExpiresAndStopsAfterFiveAttempts()throws Exception {
        register("limits");
        var session = call("POST", "/api/v1/auth/login", Map.of("email", "limits@example.com", "password", "Password123!"), null, 200);
        String sid = session.get("sessionId").asText();
        var matcher = Pattern.compile("[0-9]{6}").matcher(letters.get(letters.size()-1).getText());
        matcher.find();
        String correct = matcher.group();
        String wrong = correct.equals("000000")?"000001":"000000";
        for (int i = 0; i<6; i++)call("POST", "/api/v1/auth/verify-2fa", Map.of("sessionId", sid, "code", wrong), null, 401);
        call("POST", "/api/v1/auth/verify-2fa", Map.of("sessionId", sid, "code", correct), null, 401);
        session = call("POST", "/api/v1/auth/login", Map.of("email", "limits@example.com", "password", "Password123!"), null, 200);
        sid = session.get("sessionId").asText();
        var state = data.get("2fa:" + sid);
        data.put("2fa:" + sid, new Entry(state.value(), Instant.now().minusSeconds(1)));
        call("POST", "/api/v1/auth/verify-2fa", Map.of("sessionId", sid, "code", correct), null, 401);
    }
    @Test void websocketAuthorizesConnectSubscriptionsAndSends()throws Exception {
        register("wsseller");
        register("wsbuyer");
        register("wsstranger");
        String seller = login("wsseller").get("accessToken").asText();
        String buyer = login("wsbuyer").get("accessToken").asText();
        String stranger = login("wsstranger").get("accessToken").asText();
        String peer = call("GET", "/api/v1/users/me", null, seller, 200).get("id").asText();
        String chat = call("POST", "/api/v1/chats", Map.of("peerId", peer), buyer, 200).get("chatId").asText();
        var interceptor = inbound.getInterceptors().stream().filter(i -> i.getClass().getName().contains("WebSocketConfig")).findFirst().orElseThrow();
        java.security.Principal buyerPrincipal = connect(interceptor, buyer);
        java.security.Principal strangerPrincipal = connect(interceptor, stranger);
        var sub = org.springframework.messaging.simp.stomp.StompHeaderAccessor.create(org.springframework.messaging.simp.stomp.StompCommand.SUBSCRIBE);
        sub.setUser(buyerPrincipal);
        sub.setDestination("/topic/chats/" + chat);
        assertThat(interceptor.preSend(org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0], sub.getMessageHeaders()), inbound)).isNotNull();
        var denied = org.springframework.messaging.simp.stomp.StompHeaderAccessor.create(org.springframework.messaging.simp.stomp.StompCommand.SUBSCRIBE);
        denied.setUser(strangerPrincipal);
        denied.setDestination("/topic/chats/" + chat);
        assertThatThrownBy(() -> interceptor.preSend(org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0], denied.getMessageHeaders()), inbound)).isInstanceOf(kg.oliver.api.ApiException.class);
        var send = org.springframework.messaging.simp.stomp.StompHeaderAccessor.create(org.springframework.messaging.simp.stomp.StompCommand.SEND);
        send.setUser(buyerPrincipal);
        send.setDestination("/topic/chats/" + chat);
        assertThatThrownBy(() -> interceptor.preSend(org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0], send.getMessageHeaders()), inbound)).isInstanceOf(kg.oliver.api.ApiException.class);
        var anonymous = org.springframework.messaging.simp.stomp.StompHeaderAccessor.create(org.springframework.messaging.simp.stomp.StompCommand.CONNECT);
        assertThatThrownBy(() -> interceptor.preSend(org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0], anonymous.getMessageHeaders()), inbound)).isInstanceOf(kg.oliver.api.ApiException.class);
    }
    java.security.Principal connect(org.springframework.messaging.support.ChannelInterceptor interceptor, String token) {
        var h = org.springframework.messaging.simp.stomp.StompHeaderAccessor.create(org.springframework.messaging.simp.stomp.StompCommand.CONNECT);
        h.setNativeHeader("Authorization", "Bearer " + token);
        h.setLeaveMutable(true);
        var message = org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0], h.getMessageHeaders());
        interceptor.preSend(message, inbound);
        return h.getUser();
    }
    @Test void mediaUploadOwnershipAndAdminModeration()throws Exception {
        register("uploader");
        register("mediaother");
        register("moderator");
        String uploader = login("uploader").get("accessToken").asText();
        String other = login("mediaother").get("accessToken").asText();
        byte[] png = Base64.getDecoder().decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6lN8AAAAASUVORK5CYII=");
        String result = mvc.perform(MockMvcRequestBuilders.multipart("/api/v1/media/upload").file("file", png).header("Authorization", "Bearer " + uploader)).andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        var media = json.readTree(result);
        var body = new HashMap<>(product());
        body.put("media", List.of(Map.of("mediaId", media.get("mediaId").asText())));
        call("POST", "/api/v1/products", body, other, 403);
        String id = call("POST", "/api/v1/products", body, uploader, 201).get("id").asText();
        call("PATCH", "/api/v1/users/me", Map.of("avatarUrl", media.get("url").asText()), uploader, 200);
        db.update("update users set role='ADMIN',token_version=token_version+1 where email=?", "moderator@example.com");
        String admin = login("moderator").get("accessToken").asText();
        call("DELETE", "/api/v1/products/" + id, null, admin, 204);
    }
}
