package kg.oliver.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.*;
import org.slf4j.*;
import java.util.*;

@Component
public class ChatEvents {
    public static final String CHANNEL = "oliver:chat-events";
    private final StringRedisTemplate redis;
    private final ObjectMapper json;
    private final SimpMessagingTemplate stomp;
    private static final Logger log = LoggerFactory.getLogger(ChatEvents.class);
    public ChatEvents(StringRedisTemplate redis, ObjectMapper json, SimpMessagingTemplate stomp) {
        this.redis = redis;
        this.json = json;
        this.stomp = stomp;
    }
    public void publish(UUID chat, Map<String, Object> event) {
        Runnable send = () -> {
            try {
                redis.convertAndSend(CHANNEL, json.writeValueAsString(Map.of("chatId", chat, "event", event)));
            }
            catch (Exception e) {
                log.error("Chat event delivery failed for {}", chat, e);
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive())TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            public void afterCommit() {
                send.run();
            }
        }
        );
        else send.run();
    }
    @SuppressWarnings("unchecked") public void receive(String message) {
        try {
            var m = json.readValue(message, Map.class);
            stomp.convertAndSend("/topic/chats/" + m.get("chatId"), m.get("event"));
        }
        catch (Exception e) {
            log.error("Invalid chat event", e);
        }
    }
}
