package kg.oliver.api;

import org.springframework.http.HttpStatus;

public class ApiException extends RuntimeException {
    public final HttpStatus status;
    public ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }
    public static ApiException bad(String m) {
        return new ApiException(HttpStatus.BAD_REQUEST, m);
    }
    public static ApiException missing() {
        return new ApiException(HttpStatus.NOT_FOUND, "Объект не найден");
    }
    public static ApiException forbidden() {
        return new ApiException(HttpStatus.FORBIDDEN, "Доступ запрещён");
    }
    public static ApiException unauthorized() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "Неверные или истёкшие учётные данные");
    }
}
