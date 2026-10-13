package kg.oliver.api;

import jakarta.servlet.http.*;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.*;
import org.springframework.dao.*;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.security.access.AccessDeniedException;
import org.slf4j.*;
import java.time.Instant;
import java.util.Map;

@RestControllerAdvice
public class Errors {
    private static final Logger log = LoggerFactory.getLogger(Errors.class);
    public static Map<String, Object> body(int status, String message, String path) {
        return Map.of("timestamp", Instant.now().toString(), "status", status, "error", HttpStatus.valueOf(status).getReasonPhrase(), "message", message, "path", path);
    }
    @ExceptionHandler(ApiException.class) ResponseEntity<?> api(ApiException e, HttpServletRequest r) {
        return response(e.status.value(), e.getMessage(), r);
    }
    @ExceptionHandler( {
        MethodArgumentNotValidException.class, ConstraintViolationException.class, HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class, MissingServletRequestParameterException.class, MissingServletRequestPartException.class
    }
    ) ResponseEntity<?> validation(Exception e, HttpServletRequest r) {
        return response(400, "Проверьте формат и обязательные поля запроса", r);
    }
    @ExceptionHandler(DataIntegrityViolationException.class) ResponseEntity<?> conflict(Exception e, HttpServletRequest r) {
        return response(409, "Конфликт данных или недопустимая ссылка на объект", r);
    }
    @ExceptionHandler(AccessDeniedException.class) ResponseEntity<?> denied(Exception e, HttpServletRequest r) {
        return response(403, "Доступ запрещён", r);
    }
    @ExceptionHandler(MaxUploadSizeExceededException.class) ResponseEntity<?> large(Exception e, HttpServletRequest r) {
        return response(413, "Файл слишком большой", r);
    }
    @ExceptionHandler(org.springframework.web.servlet.resource.NoResourceFoundException.class) ResponseEntity<?> missing(Exception e, HttpServletRequest r) {
        return response(404, "Маршрут не найден", r);
    }
    @ExceptionHandler(org.springframework.web.HttpRequestMethodNotSupportedException.class) ResponseEntity<?> method(Exception e, HttpServletRequest r) {
        return response(405, "Метод не поддерживается", r);
    }
    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotSupportedException.class)
    ResponseEntity<?> unsupported(Exception e, HttpServletRequest r) {
        return response(415, "Неподдерживаемый Content-Type", r);
    }
    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotAcceptableException.class)
    ResponseEntity<?> unacceptable(Exception e, HttpServletRequest r) {
        return response(406, "Неподдерживаемый формат ответа", r);
    }
    @ExceptionHandler({org.springframework.mail.MailException.class,
            org.springframework.data.redis.RedisConnectionFailureException.class,
            org.springframework.dao.DataAccessResourceFailureException.class,
            software.amazon.awssdk.core.exception.SdkException.class})
    ResponseEntity<?> unavailable(Exception e, HttpServletRequest r) {
        log.error("External service unavailable for {}", r.getRequestURI(), e);
        return response(503, "Сервис временно недоступен", r);
    }
    @ExceptionHandler(Exception.class) ResponseEntity<?> unknown(Exception e, HttpServletRequest r) {
        log.error("Request failed {}", r.getRequestURI(), e);
        return response(500, "Внутренняя ошибка сервера", r);
    }
    private ResponseEntity<?> response(int s, String m, HttpServletRequest r) {
        return ResponseEntity.status(s).body(body(s, m, r.getRequestURI()));
    }
}
