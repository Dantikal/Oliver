package kg.oliver.repository;

import kg.oliver.api.ApiException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.*;

@Repository
public class Store {
    private final JdbcTemplate jdbc;
    public Store(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }
    public int update(String sql, Object...args) {
        return jdbc.update(sql, args);
    }
    public List<Map<String, Object>> list(String sql, Object...args) {
        return jdbc.query(sql, (rs, n) -> {
            var m = new LinkedHashMap<String, Object>();
            var md = rs.getMetaData();
            for (int i = 1; i <= md.getColumnCount(); i++) {
                String key = md.getColumnLabel(i).toLowerCase(Locale.ROOT);
                var b = new StringBuilder();
                boolean upper = false;
                for (char c:key.toCharArray()) {
                    if (c == '_') {
                        upper = true;
                    }
                    else {
                        b.append(upper?Character.toUpperCase(c):c);
                        upper = false;
                    }
                }
                Object value = rs.getObject(i);
                if (value instanceof java.sql.Timestamp t)value = t.toInstant().toString();
                if (value instanceof java.time.OffsetDateTime t)value = t.toInstant().toString();
                m.put(b.toString(), value);
            }
            return m;
        }
        , args);
    }
    public Map<String, Object> one(String sql, Object...args) {
        return list(sql, args).stream().findFirst().orElseThrow(ApiException::missing);
    }
    public Optional<Map<String, Object>> optional(String sql, Object...args) {
        return list(sql, args).stream().findFirst();
    }
    public long count(String sql, Object...args) {
        return jdbc.queryForObject(sql, Long.class, args);
    }
}
