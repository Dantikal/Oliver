package kg.oliver.api;

import jakarta.validation.Valid;
import kg.oliver.auth.AuthService;
import org.springframework.web.bind.annotation.*;

@io.swagger.v3.oas.annotations.security.SecurityRequirements
@RestController @RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService auth;
    public AuthController(AuthService auth) {
        this.auth = auth;
    }
    @PostMapping("/register") @ResponseStatus(org.springframework.http.HttpStatus.CREATED) public Responses.Registration register(@Valid @RequestBody Requests.Register r) {
        return Responses.dto(auth.register(r), Responses.Registration.class);
    }
    @PostMapping("/login") public Responses.Login login(@Valid @RequestBody Requests.Login r) {
        return Responses.dto(auth.login(r), Responses.Login.class);
    }
    @PostMapping("/verify-2fa") public Responses.SessionTokens verify(@Valid @RequestBody Requests.Verify r) {
        return Responses.dto(auth.verify(r), Responses.SessionTokens.class);
    }
    @PostMapping("/resend-2fa") public Responses.Info resend(@Valid @RequestBody Requests.Session r) {
        return Responses.dto(auth.resend(r), Responses.Info.class);
    }
    @PostMapping("/refresh") public Responses.Tokens refresh(@Valid @RequestBody Requests.Refresh r) {
        return Responses.dto(auth.refresh(r), Responses.Tokens.class);
    }
    @PostMapping("/logout") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT) public void logout(@Valid @RequestBody Requests.Refresh r) {
        auth.logout(r);
    }
    @PostMapping("/forgot-password") public Responses.Info forgot(@Valid @RequestBody Requests.Forgot r) {
        return Responses.dto(auth.forgot(r), Responses.Info.class);
    }
    @PostMapping("/reset-password") public Responses.Info reset(@Valid @RequestBody Requests.Reset r) {
        return Responses.dto(auth.reset(r), Responses.Info.class);
    }
}
