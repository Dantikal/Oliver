package kg.oliver.auth;

import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import java.util.UUID;
import kg.oliver.api.ApiException;

public final class CurrentUser {
    public static UUID optional() {
        var a = SecurityContextHolder.getContext().getAuthentication();
        return a instanceof JwtAuthenticationToken jwt?UUID.fromString(jwt.getName()):null;
    }
    public static UUID id() {
        var id = optional();
        if (id == null)throw ApiException.unauthorized();
        return id;
    }
    public static boolean admin() {
        var a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getAuthorities().stream().anyMatch(r -> r.getAuthority().equals("ROLE_ADMIN"));
    }
}
