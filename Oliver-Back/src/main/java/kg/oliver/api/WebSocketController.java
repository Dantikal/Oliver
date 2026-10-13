package kg.oliver.api;

import kg.oliver.service.ChatService;
import jakarta.validation.Valid;
import org.springframework.messaging.handler.annotation.*;
import org.springframework.stereotype.Controller;
import java.security.Principal;
import java.util.UUID;

@Controller
public class WebSocketController {
    private final ChatService chats;
    public WebSocketController(ChatService chats) {
        this.chats = chats;
    }
    @MessageMapping("/chats/{id}/send") public void send(@DestinationVariable UUID id, @Valid @Payload Requests.Message r, Principal user) {
        chats.send(id, UUID.fromString(user.getName()), r);
    }
    @MessageMapping("/chats/{id}/read") public void read(@DestinationVariable UUID id, Principal user) {
        chats.read(id, UUID.fromString(user.getName()));
    }
    @MessageMapping("/chats/{id}/typing") public void typing(@DestinationVariable UUID id, Principal user) {
        chats.typing(id, UUID.fromString(user.getName()));
    }
}
