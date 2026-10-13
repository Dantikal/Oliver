package kg.oliver.api;

import kg.oliver.auth.CurrentUser;
import kg.oliver.service.CatalogService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import java.util.UUID;
import java.math.BigDecimal;

@RestController @RequestMapping("/api/v1")
public class CatalogController {
    private final CatalogService service;
    public CatalogController(CatalogService service) {
        this.service = service;
    }
    @GetMapping("/users/me") public Responses.User me() {
        return Responses.dto(service.me(), Responses.User.class);
    }
    @PatchMapping("/users/me") public Responses.User profile(@Valid @RequestBody Requests.Profile r) {
        return Responses.dto(service.profile(r), Responses.User.class);
    }
    @GetMapping("/users/{id}") public Responses.PublicUser user(@PathVariable UUID id) {
        return Responses.dto(service.publicUser(id), Responses.PublicUser.class);
    }
    @GetMapping("/users/{id}/products") public Responses.Page<Responses.Product> userProducts(@PathVariable UUID id, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        service.publicUser(id);
        return Responses.page(service.products(null, null, null, null, null, null, null, page, size, "createdAt,desc", id, false), Responses.Product.class);
    }
    @GetMapping("/categories") public java.util.List<Responses.Category> categories() {
        return Responses.list(service.categories(), Responses.Category.class);
    }
    @GetMapping("/regions") public java.util.List<Responses.Lookup> regions() {
        return Responses.list(service.regions(), Responses.Lookup.class);
    }
    @GetMapping("/regions/{id}/cities") public java.util.List<Responses.Lookup> cities(@PathVariable long id) {
        return Responses.list(service.cities(id), Responses.Lookup.class);
    }
    @GetMapping("/products") public Responses.Page<Responses.Product> products(@RequestParam(required = false) String q, @RequestParam(required = false) Long categoryId, @RequestParam(required = false) Long regionId, @RequestParam(required = false) Long cityId, @RequestParam(required = false) String currency, @RequestParam(required = false) BigDecimal minPrice, @RequestParam(required = false) BigDecimal maxPrice, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size, @RequestParam(defaultValue = "createdAt,desc") String sort) {
        return Responses.page(service.products(q, categoryId, regionId, cityId, currency, minPrice, maxPrice, page, size, sort, null, false), Responses.Product.class);
    }
    @GetMapping("/products/me") public Responses.Page<Responses.Product> myProducts(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return Responses.page(service.products(null, null, null, null, null, null, null, page, size, "createdAt,desc", CurrentUser.id(), false), Responses.Product.class);
    }
    @GetMapping("/products/{id}") public Responses.Product product(@PathVariable UUID id) {
        return Responses.dto(service.product(id), Responses.Product.class);
    }
    @PostMapping("/products") @ResponseStatus(HttpStatus.CREATED) public Responses.Product create(@Valid @RequestBody Requests.Product r) {
        return Responses.dto(service.create(r), Responses.Product.class);
    }
    @PatchMapping("/products/{id}") public Responses.Product patch(@PathVariable UUID id, @Valid @RequestBody Requests.ProductPatch r) {
        return Responses.dto(service.patch(id, r), Responses.Product.class);
    }
    @DeleteMapping("/products/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(@PathVariable UUID id) {
        service.delete(id);
    }
    @GetMapping("/favorites") public Responses.Page<Responses.Product> favorites(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return Responses.page(service.products(null, null, null, null, null, null, null, page, size, "createdAt,desc", null, true), Responses.Product.class);
    }
    @GetMapping("/favorites/count") public Responses.Count count() {
        return Responses.dto(service.favoriteCount(), Responses.Count.class);
    }
    @PostMapping("/favorites/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void favorite(@PathVariable UUID id) {
        service.favorite(id, true);
    }
    @DeleteMapping("/favorites/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void unfavorite(@PathVariable UUID id) {
        service.favorite(id, false);
    }
}
