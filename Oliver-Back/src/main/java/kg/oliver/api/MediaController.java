package kg.oliver.api;

import kg.oliver.service.MediaService;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.http.*;
import java.util.*;
import java.io.IOException;

@RestController @RequestMapping("/api/v1")
public class MediaController {
    private final MediaService service;
    public MediaController(MediaService service) {
        this.service = service;
    }
    @PostMapping(value = "/media/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE) @ResponseStatus(HttpStatus.CREATED) public Responses.Media upload(@RequestPart("file") MultipartFile file)throws IOException {
        return Responses.dto(service.upload(file, null, false), Responses.Media.class);
    }
    @PostMapping(value = "/products/{id}/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE) @ResponseStatus(HttpStatus.CREATED) public Responses.Media product(@PathVariable UUID id, @RequestPart("file") MultipartFile file)throws IOException {
        return Responses.dto(service.upload(file, id, false), Responses.Media.class);
    }
    @PostMapping(value = "/users/me/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE) public Responses.Avatar avatar(@RequestPart("file") MultipartFile file)throws IOException {
        return Responses.dto(Map.of("avatarUrl", service.upload(file, null, true).get("url")), Responses.Avatar.class);
    }
}
