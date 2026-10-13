package kg.oliver.auth;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;
import java.time.Duration;
import java.util.List;

@Component
public class RedisEphemeralStore implements EphemeralStore {
    private final StringRedisTemplate redis;
    public RedisEphemeralStore(StringRedisTemplate redis) {
        this.redis = redis;
    }
    public void put(String k, String v, Duration t) {
        redis.opsForValue().set(k, v, t);
    }
    public String get(String k) {
        return redis.opsForValue().get(k);
    }
    public String take(String k) {
        return redis.opsForValue().getAndDelete(k);
    }
    public void delete(String k) {
        redis.delete(k);
    }
    public boolean replace(String k, String expected, String value, Duration ttl) {
        return run("if redis.call('GET',KEYS[1]) == ARGV[1] then redis.call('SET',KEYS[1],ARGV[2],'EX',ARGV[3]); return 1 end; return 0", k, expected, value, Long.toString(ttl.toSeconds())) == 1;
    }
    public boolean consume(String k, String expected) {
        return run("if redis.call('GET',KEYS[1]) == ARGV[1] then return redis.call('DEL',KEYS[1]) end; return 0", k, expected) == 1;
    }
    public long increment(String k, Duration ttl) {
        return run("local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n", k, Long.toString(ttl.toSeconds()));
    }
    private long run(String script, String key, String...args) {
        return redis.execute(new DefaultRedisScript<>(script, Long.class), List.of(key), (Object[])args);
    }
}
