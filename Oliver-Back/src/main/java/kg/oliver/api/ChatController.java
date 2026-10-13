package kg.oliver.api;

import kg.oliver.auth.CurrentUser;
import kg.oliver.service.ChatService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import java.util.UUID;

@RestController @RequestMapping("/api/v1/chats")
public class ChatController {
    private final ChatService service;
    public ChatController(ChatService service) {
        this.service = service;
    }
    @GetMapping public java.util.List<Responses.Chat> chats() {
        return Responses.list(service.list(), Responses.Chat.class);
    }
    @PostMapping public Responses.ChatId create(@Valid @RequestBody Requests.Chat r) {
        return Responses.dto(service.create(r), Responses.ChatId.class);
    }
    @GetMapping("/{id}/messages") public Responses.Page<Responses.Message> messages(@PathVariable UUID id, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return Responses.page(service.messages(id, page, size), Responses.Message.class);
    }
    @PostMapping("/{id}/messages") @ResponseStatus(HttpStatus.CREATED) public Responses.Message send(@PathVariable UUID id, @Valid @RequestBody Requests.Message r) {
        return Responses.dto(service.send(id, CurrentUser.id(), r), Responses.Message.class);
    }
    @PostMapping("/{id}/read") @ResponseStatus(HttpStatus.NO_CONTENT) public void read(@PathVariable UUID id) {
        service.read(id, CurrentUser.id());
    }
}
