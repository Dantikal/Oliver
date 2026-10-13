package kg.oliver.auth;

import java.time.Duration;

public interface EphemeralStore {
    void put(String key, String value, Duration ttl);
    String get(String key);
    String take(String key);
    boolean replace(String key, String expected, String value, Duration ttl);
    boolean consume(String key, String expected);
    long increment(String key, Duration ttl);
    void delete(String key);
}
