package kg.oliver.api;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/** Public API DTOs: database-only fields never enter the response contract. */
public final class Responses {
    private static final ObjectMapper MAPPER = new ObjectMapper() .findAndRegisterModules() .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
    private Responses() {}
    public record Error(String timestamp, int status, String error, String message, String path) {}

    public record User(UUID id, String email, String phone, String fullName, String avatarUrl, String role) {}
    public record PublicUser(UUID id, String fullName, String avatarUrl) {}
    public record Registration(UUID userId, String message) {}
    public record Login(boolean requires2fa, UUID sessionId) {}
    public record Tokens(String accessToken, String refreshToken) {}
    public record SessionTokens(String accessToken, String refreshToken, User user) {}
    public record Info(String message) {}
    public record Count(long count) {}
    public record Likes(long likesCount) {}
    public record ChatId(UUID chatId) {}
    public record Avatar(String avatarUrl) {}
    public record Lookup(long id, String name) {}
    public record Category(long id, String name, List<Category> children) {}
    public record Media(UUID mediaId, String url, String type, long size) {}
    public record Product(UUID id, UUID userId, String title, String description, long categoryId, BigDecimal price, String currency, long regionId, long cityId, String phone, String whatsappLink, String telegramLink, String createdAt, String updatedAt, List<Media> media, PublicUser seller, Lookup category, Lookup region, Lookup city, long likesCount, boolean isFavorite) {}
    public record Page<T>(List<T> items, long total, int page, int size) {}
    public record Comment(UUID id, UUID productId, UUID userId, String fullName, String avatarUrl, String text, UUID parentCommentId, long likesCount, boolean isLiked, String createdAt, List<Comment> replies) {}
    public record Message(UUID id, UUID chatId, UUID userId, String type, String content, String mediaUrl, boolean isRead, String createdAt) {}
    public record Chat(UUID chatId, PublicUser peer, Message lastMessage, long unreadCount, String updatedAt) {}
    public record Notification(UUID id, UUID userId, UUID actorId, String type, UUID productId, boolean isRead, String createdAt) {}
    public record Counters(long unreadMessages, long newLikes, long unreadNotifications) {}
    public static <T> T dto(Object source, Class<T> type) {
        return MAPPER.convertValue(source, type);
    }
    public static <T> List<T> list(Object source, Class<T> type) {
        return MAPPER.convertValue(source, MAPPER.getTypeFactory().constructCollectionType(List.class, type));
    }
    public static <T> Page<T> page(Object source, Class<T> type) {
        return MAPPER.convertValue(source, MAPPER.getTypeFactory().constructParametricType(Page.class, type));
    }
}
