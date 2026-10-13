package kg.oliver.auth;

import kg.oliver.api.*;
import kg.oliver.repository.Store;
import kg.oliver.service.MailService;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
import java.time.*;
import java.security.*;
import java.nio.charset.StandardCharsets;

@Service
public class AuthService {
    private final Store db;
    private final EphemeralStore cache;
    private final MailService mail;
    private final PasswordEncoder passwords;
    private final JwtEncoder jwt;
    private final long accessTtl, refreshTtl;
    private final String resetUrl;
    private final SecureRandom random = new SecureRandom();
    private final String dummy;
    public AuthService(Store db, EphemeralStore cache, MailService mail, PasswordEncoder passwords, JwtEncoder jwt, @Value("${app.access-ttl-seconds}") long accessTtl, @Value("${app.refresh-ttl-seconds}") long refreshTtl, @Value("${app.reset-url}") String resetUrl) {
        this.db = db;
        this.cache = cache;
        this.mail = mail;
        this.passwords = passwords;
        this.jwt = jwt;
        this.accessTtl = accessTtl;
        this.refreshTtl = refreshTtl;
        this.resetUrl = resetUrl;
        dummy = passwords.encode(UUID.randomUUID().toString());
    }
    @Transactional public Map<String, Object> register(Requests.Register r) {
        checkPassword(r.password());
        if (!r.password().equals(r.confirmPassword()))throw ApiException.bad("Пароли не совпадают");
        UUID id = UUID.randomUUID();
        db.update("insert into users(id,email,phone,full_name,password_hash) values(?,?,?,?,?)", id, r.email().trim().toLowerCase(Locale.ROOT), r.phone(), r.fullName().trim(), passwords.encode(r.password()));
        return Map.of("userId", id, "message", "Регистрация завершена");
    }
    public Map<String, Object> login(Requests.Login r) {
        String email = r.email().trim().toLowerCase(Locale.ROOT);
        limit("login:" + hash(email), 10, Duration.ofMinutes(15));
        var u = db.optional("select * from users where email=?", email);
        String stored = u.map(x -> x.get("passwordHash").toString()).orElse(dummy);
        if (!passwords.matches(r.password(), stored) || u.isEmpty())throw ApiException.unauthorized();
        UUID session = UUID.randomUUID();
        String code = code();
        cache.put("2fa:" + session, u.get().get("id") + "|" + u.get().get("tokenVersion") + "|" + hash(code), Duration.ofMinutes(5));
        cache.put("limit:resend:" + session, "1", Duration.ofSeconds(60));
        try {
            mail.send(email, "Oliver: код входа", "Код: " + code + ". Действует 5 минут.");
        }
        catch (RuntimeException e) {
            cache.delete("2fa:" + session);
            throw e;
        }
        return Map.of("requires2fa", true, "sessionId", session);
    }
    @Transactional public Map<String, Object> verify(Requests.Verify r) {
        String key = "2fa:" + r.sessionId();
        String state = cache.get(key);
        if (state == null)throw ApiException.unauthorized();
        if (cache.increment("attempts:" + r.sessionId(), Duration.ofMinutes(30))>5) {
            cache.delete(key);
            throw ApiException.unauthorized();
        }
        String[] parts = state.split("\\|");
        if (!MessageDigest.isEqual(parts[2].getBytes(StandardCharsets.UTF_8), hash(r.code()).getBytes(StandardCharsets.UTF_8)))throw ApiException.unauthorized();
        if (!cache.consume(key, state))throw ApiException.unauthorized();
        var u = locked(UUID.fromString(parts[0]));
        checkVersion(u, parts[1]);
        var result = tokens(u);
        result.put("user", profile(u));
        return result;
    }
    public Map<String, String> resend(Requests.Session r) {
        String key = "2fa:" + r.sessionId();
        String state = cache.get(key);
        if (state == null)throw ApiException.unauthorized();
        limit("resend:" + r.sessionId(), 1, Duration.ofSeconds(60));
        limit("resend-total:" + r.sessionId(), 5, Duration.ofMinutes(30));
        String[] parts = state.split("\\|");
        var u = db.one("select * from users where id=?", UUID.fromString(parts[0]));
        checkVersion(u, parts[1]);
        String code = code();
        String updated = parts[0] + "|" + parts[1] + "|" + hash(code);
        if (!cache.replace(key, state, updated, Duration.ofMinutes(5)))throw ApiException.unauthorized();
        mail.send(u.get("email").toString(), "Oliver: код входа", "Код: " + code + ". Действует 5 минут.");
        return Map.of("message", "Код отправлен");
    }
    @Transactional public Map<String, Object> refresh(Requests.Refresh r) {
        String value = cache.take("refresh:" + hash(r.refreshToken()));
        if (value == null)throw ApiException.unauthorized();
        String[] parts = value.split("\\|");
        var u = locked(UUID.fromString(parts[0]));
        checkVersion(u, parts[1]);
        return tokens(u);
    }
    public void logout(Requests.Refresh r) {
        cache.delete("refresh:" + hash(r.refreshToken()));
    }
    public Map<String, String> forgot(Requests.Forgot r) {
        String email = r.email().trim().toLowerCase(Locale.ROOT);
        limit("reset:" + hash(email), 3, Duration.ofMinutes(15));
        db.optional("select id,token_version from users where email=?", email).ifPresent(u -> {
            String token = token();
            cache.put("reset-token:" + hash(token), u.get("id") + "|" + u.get("tokenVersion"), Duration.ofMinutes(15));
            mail.send(email, "Oliver: сброс пароля", resetUrl + "?token=" + token);
        }
        );
        return Map.of("message", "Если адрес зарегистрирован, письмо отправлено");
    }
    @Transactional public Map<String, String> reset(Requests.Reset r) {
        checkPassword(r.newPassword());
        String state = cache.take("reset-token:" + hash(r.token()));
        if (state == null)throw ApiException.unauthorized();
        String[] parts = state.split("\\|");
        var u = locked(UUID.fromString(parts[0]));
        checkVersion(u, parts[1]);
        db.update("update users set password_hash=?,token_version=token_version+1 where id=?", passwords.encode(r.newPassword()), u.get("id"));
        return Map.of("message", "Пароль изменён");
    }
    public void limit(String key, long max, Duration ttl) {
        if (cache.increment("limit:" + key, ttl)>max)throw new ApiException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS, "Слишком много запросов");
    }
    private Map<String, Object> locked(UUID id) {
        return db.one("select * from users where id=? for update", id);
    }
    private void checkVersion(Map<String, Object> u, String v) {
        if (!u.get("tokenVersion").toString().equals(v))throw ApiException.unauthorized();
    }
    private Map<String, Object> tokens(Map<String, Object> u) {
        Instant now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("oliver").subject(u.get("id").toString()).issuedAt(now).expiresAt(now.plusSeconds(accessTtl)).claim("role", u.get("role")).claim("ver", ((Number)u.get("tokenVersion")).longValue()).build();
        String access = jwt.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
        String refresh = token();
        cache.put("refresh:" + hash(refresh), u.get("id") + "|" + u.get("tokenVersion"), Duration.ofSeconds(refreshTtl));
        var result = new LinkedHashMap<String, Object>();
        result.put("accessToken", access);
        result.put("refreshToken", refresh);
        return result;
    }
    public static Map<String, Object> profile(Map<String, Object> u) {
        var out = new LinkedHashMap<String, Object>();
        for (String k:List.of("id", "email", "phone", "fullName", "avatarUrl", "role"))out.put(k, u.get(k));
        return out;
    }
    private String code() {
        return String.format(Locale.ROOT, "%06d", random.nextInt(1000000));
    }
    private String token() {
        byte[] b = new byte[32];
        random.nextBytes(b);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }
    public static String hash(String s) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
    private void checkPassword(String p) {
        if (p.getBytes(StandardCharsets.UTF_8).length>72)throw ApiException.bad("Пароль должен быть не длиннее 72 байт UTF-8");
    }
}
