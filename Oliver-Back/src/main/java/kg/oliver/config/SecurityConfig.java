package kg.oliver.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import kg.oliver.api.Errors;
import kg.oliver.repository.Store;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.*;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.*;

@Configuration @EnableWebSecurity
public class SecurityConfig {
    @Bean PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
    @Bean SecretKeySpec jwtKey(@Value("${app.jwt-secret}") String secret) {
        if (secret.getBytes(StandardCharsets.UTF_8).length<32)throw new IllegalStateException("JWT_SECRET must contain at least 32 bytes");
        return new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }
    @Bean JwtEncoder encoder(SecretKeySpec key) {
        return new NimbusJwtEncoder(new com.nimbusds.jose.jwk.source.ImmutableSecret<>(key));
    }
    @Bean JwtDecoder decoder(SecretKeySpec key, Store db) {
        var decoder = NimbusJwtDecoder.withSecretKey(key).build();
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer("oliver"), jwt -> {
            try {
                var u = db.one("select token_version from users where id=?", UUID.fromString(jwt.getSubject()));
                if (((Number)u.get("tokenVersion")).longValue() == ((Number)jwt.getClaim("ver")).longValue())return OAuth2TokenValidatorResult.success();
            }
            catch (Exception ignored) {}
            return OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token"));
        }
        ));
        return decoder;
    }
    @Bean SecurityFilterChain chain(HttpSecurity http, ObjectMapper mapper) throws Exception {
        var converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> List.of(new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_" + jwt.getClaimAsString("role"))));
        return http.csrf(c -> c.disable()).cors(c -> {}
        ).sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS)) .authorizeHttpRequests(a -> a.requestMatchers("/api/v1/auth/**", "/actuator/health", "/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**", "/ws", "/ws/**").permitAll() .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/v1/products/me", "/api/v1/users/me", "/api/v1/users/me/**").authenticated() .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/v1/products/**", "/api/v1/categories", "/api/v1/regions/**", "/api/v1/users/*", "/api/v1/users/*/products").permitAll().anyRequest().authenticated()) .oauth2ResourceServer(o -> o.jwt(j -> j.jwtAuthenticationConverter(converter)).authenticationEntryPoint((r, s, e) -> {
            s.setStatus(401);
            s.setContentType("application/json");
            mapper.writeValue(s.getOutputStream(), Errors.body(401, "Требуется авторизация", r.getRequestURI()));
        }
        )) .exceptionHandling(e -> e.authenticationEntryPoint((r, s, x) -> {
            s.setStatus(401);
            s.setContentType("application/json");
            mapper.writeValue(s.getOutputStream(), Errors.body(401, "Требуется авторизация", r.getRequestURI()));
        }
        ).accessDeniedHandler((r, s, x) -> {
            s.setStatus(403);
            s.setContentType("application/json");
            mapper.writeValue(s.getOutputStream(), Errors.body(403, "Доступ запрещён", r.getRequestURI()));
        }
        )).build();
    }
    @Bean CorsConfigurationSource cors(@Value("${app.allowed-origins}") String origins) {
        var c = new CorsConfiguration();
        c.setAllowedOrigins(Arrays.asList(origins.split(",")));
        c.setAllowedMethods(List.of("GET", "POST", "PATCH", "DELETE", "OPTIONS"));
        c.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        var s = new UrlBasedCorsConfigurationSource();
        s.registerCorsConfiguration("/**", c);
        return s;
    }
}
