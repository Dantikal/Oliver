package kg.oliver.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.*;

public final class Requests {
    public record Register(@NotBlank @Pattern(regexp = "\\+996[0-9]{9}") String phone, @NotBlank @Email @Size(max = 254) String email, @NotBlank @Size(max = 120) String fullName, @NotBlank @Size(min = 8, max = 72) String password, @NotBlank @Size(max = 72) String confirmPassword) {}
    public record Login(@NotBlank @Email String email, @NotBlank @Size(max = 72) String password) {}
    public record Verify(@NotNull UUID sessionId, @NotBlank @Pattern(regexp = "[0-9]{6}") String code) {}
    public record Session(@NotNull UUID sessionId) {}
    public record Refresh(@NotBlank @Size(max = 256) String refreshToken) {}
    public record Forgot(@NotBlank @Email String email) {}
    public record Reset(@NotBlank @Size(max = 256) String token, @NotBlank @Size(min = 8, max = 72) String newPassword) {}
    public record Profile(@Size(min = 1, max = 120) String fullName, @Size(max = 2048) String avatarUrl) {}
    public record Product(@NotBlank @Size(max = 200) String title, @NotBlank @Size(max = 20000) String description, @NotNull Long categoryId, @NotNull @DecimalMin("0.00") @DecimalMax("999999999999.99") @Digits(integer = 12, fraction = 2) BigDecimal price, @NotNull @Pattern(regexp = "KGS|USD|EUR|RUB|KZT") String currency, @NotNull Long regionId, @NotNull Long cityId, @NotBlank @Pattern(regexp = "\\+996[0-9]{9}") String phone, @Size(max = 2048) String whatsappLink, @Size(max = 2048) String telegramLink, @Size(max = 20) List<@Valid MediaRef> media) {}
    public record ProductPatch(@Size(min = 1, max = 200) String title, @Size(min = 1, max = 20000) String description, Long categoryId, @DecimalMin("0.00") @DecimalMax("999999999999.99") @Digits(integer = 12, fraction = 2) BigDecimal price, @Pattern(regexp = "KGS|USD|EUR|RUB|KZT") String currency, Long regionId, Long cityId, @Pattern(regexp = "\\+996[0-9]{9}") String phone, @Size(max = 2048) String whatsappLink, @Size(max = 2048) String telegramLink, @Size(max = 20) List<@Valid MediaRef> media) {}
    public record MediaRef(@NotNull UUID mediaId) {}
    public record Comment(@NotBlank @Size(max = 3000) String text, UUID parentCommentId) {}
    public record Chat(@NotNull UUID peerId, UUID productId) {}
    public record Message(@NotNull @Pattern(regexp = "TEXT|IMAGE|VIDEO") String type, @NotNull @Size(max = 5000) String content, @Size(max = 2048) String mediaUrl) {}
    public record Read(@NotNull @Size(min = 1, max = 100) List<@NotNull UUID> ids) {}
}
