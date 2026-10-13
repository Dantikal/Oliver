package kg.oliver.api;

import jakarta.validation.Valid;
import kg.oliver.service.CommunityService;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import java.util.UUID;

@RestController @RequestMapping("/api/v1")
public class CommunityController {
    private final CommunityService service;
    public CommunityController(CommunityService service) {
        this.service = service;
    }
    @GetMapping("/products/{id}/comments") public Responses.Page<Responses.Comment> comments(@PathVariable UUID id, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return Responses.page(service.comments(id, page, size), Responses.Comment.class);
    }
    @PostMapping("/products/{id}/comments") @ResponseStatus(HttpStatus.CREATED) public Responses.Comment add(@PathVariable UUID id, @Valid @RequestBody Requests.Comment r) {
        return Responses.dto(service.add(id, r), Responses.Comment.class);
    }
    @DeleteMapping("/comments/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(@PathVariable UUID id) {
        service.delete(id);
    }
    @PostMapping("/comments/{id}/like") public Responses.Likes like(@PathVariable UUID id) {
        return Responses.dto(service.like(id, true), Responses.Likes.class);
    }
    @DeleteMapping("/comments/{id}/like") public Responses.Likes unlike(@PathVariable UUID id) {
        return Responses.dto(service.like(id, false), Responses.Likes.class);
    }
    @GetMapping("/notifications") public Responses.Page<Responses.Notification> notifications(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return Responses.page(service.notifications(page, size), Responses.Notification.class);
    }
    @GetMapping("/notifications/counters") public Responses.Counters counters() {
        return Responses.dto(service.counters(), Responses.Counters.class);
    }
    @PostMapping("/notifications/read") @ResponseStatus(HttpStatus.NO_CONTENT) public void read(@Valid @RequestBody Requests.Read r) {
        service.read(r);
    }
}
