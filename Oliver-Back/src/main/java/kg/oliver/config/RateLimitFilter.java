package kg.oliver.config;

import kg.oliver.auth.EphemeralStore;
import kg.oliver.auth.AuthService;
import kg.oliver.api.Errors;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.time.Duration;

@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private final EphemeralStore cache;
    private final ObjectMapper json;
    public RateLimitFilter(EphemeralStore cache, ObjectMapper json) {
        this.cache = cache;
        this.json = json;
    }
    protected boolean shouldNotFilter(HttpServletRequest r) {
        return !r.getRequestURI().startsWith("/api/");
    }
    protected void doFilterInternal(HttpServletRequest r, HttpServletResponse s, FilterChain chain)throws ServletException, IOException {
        int status = 0;
        String message = "";
        try {
            boolean auth = r.getRequestURI().startsWith("/api/v1/auth/");
            long n = cache.increment("http:" + (auth?"auth:":"api:") + AuthService.hash(r.getRemoteAddr()), Duration.ofMinutes(1));
            if (n>(auth?30:180)) {
                status = 429;
                message = "Слишком много запросов";
            }
        }
        catch (RuntimeException e) {
            status = 503;
            message = "Сервис временно недоступен";
        }
        if (status != 0) {
            s.setStatus(status);
            s.setContentType("application/json");
            if (status == 429)s.setHeader("Retry-After", "60");
            json.writeValue(s.getOutputStream(), Errors.body(status, message, r.getRequestURI()));
            return;
        }
        chain.doFilter(r, s);
    }
}
