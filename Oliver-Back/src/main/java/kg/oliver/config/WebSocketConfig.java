package kg.oliver.config;

import kg.oliver.api.ApiException;
import kg.oliver.auth.EphemeralStore;
import kg.oliver.service.*;
import org.springframework.context.annotation.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.*;
import org.springframework.messaging.simp.config.*;
import org.springframework.messaging.simp.stomp.*;
import org.springframework.messaging.support.*;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.socket.config.annotation.*;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.*;
import org.springframework.data.redis.listener.adapter.MessageListenerAdapter;
import java.util.*;
import java.time.Duration;

@Configuration @EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private final JwtDecoder jwt;
    private final ChatService chats;
    private final EphemeralStore cache;
    private final String origins;
    public WebSocketConfig(JwtDecoder jwt, @org.springframework.context.annotation.Lazy ChatService chats, EphemeralStore cache, @Value("${app.allowed-origins}") String origins) {
        this.jwt = jwt;
        this.chats = chats;
        this.cache = cache;
        this.origins = origins;
    }
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws").setAllowedOrigins(origins.split(","));
    }
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
    }
    public void configureWebSocketTransport(WebSocketTransportRegistration r) {
        r.setMessageSizeLimit(16384).setSendBufferSizeLimit(128*1024).setSendTimeLimit(10000).setTimeToFirstMessage(15000);
    }
    public void configureClientInboundChannel(ChannelRegistration registry) {
        registry.interceptors(new ChannelInterceptor() {
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                var h = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (h == null || h.getCommand() == null)return message;
                var cmd = h.getCommand();
                if (cmd == StompCommand.CONNECT) {
                    String auth = h.getFirstNativeHeader("Authorization");
                    if (auth == null || !auth.startsWith("Bearer "))throw ApiException.unauthorized();
                    var token = jwt.decode(auth.substring(7));
                    h.setUser(new JwtAuthenticationToken(token));
                }
                else if(cmd == StompCommand.SEND || cmd == StompCommand.SUBSCRIBE) {
                    if (!(h.getUser() instanceof JwtAuthenticationToken principal))throw ApiException.unauthorized();
                    jwt.decode(principal.getToken().getTokenValue());
                    UUID user = UUID.fromString(principal.getName());
                    if (cache.increment("ws:" + user, Duration.ofMinutes(1))>120)throw new ApiException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS, "Слишком много сообщений");
                    String dest = h.getDestination();
                    String regex = cmd == StompCommand.SUBSCRIBE?"^/topic/chats/([0-9a-fA-F-]{36})$":"^/app/chats/([0-9a-fA-F-]{36})/(send|read|typing)$";
                    var matcher = java.util.regex.Pattern.compile(regex).matcher(dest == null?"":dest);
                    if (!matcher.matches())throw ApiException.forbidden();
                    chats.member(UUID.fromString(matcher.group(1)), user);
                }
                else if(cmd != StompCommand.DISCONNECT && cmd != StompCommand.UNSUBSCRIBE)throw ApiException.forbidden();
                return message;
            }
        }
        );
    }
    @Bean RedisMessageListenerContainer chatListener(RedisConnectionFactory connection, ChatEvents events) {
        var c = new RedisMessageListenerContainer();
        c.setConnectionFactory(connection);
        c.addMessageListener(new MessageListenerAdapter(events, "receive"), new ChannelTopic(ChatEvents.CHANNEL));
        return c;
    }
}
