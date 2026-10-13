package kg.oliver.service;

import kg.oliver.api.*;
import kg.oliver.auth.*;
import kg.oliver.repository.Store;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service
public class CatalogService {
    private final Store db;
    public CatalogService(Store db) {
        this.db = db;
    }
    public Map<String, Object> me() {
        return AuthService.profile(db.one("select * from users where id=?", CurrentUser.id()));
    }
    public Map<String, Object> publicUser(UUID id) {
        return db.one("select id,full_name,avatar_url from users where id=?", id);
    }
    @Transactional public Object profile(Requests.Profile r) {
        if (r.fullName() != null) {
            if (r.fullName().isBlank())throw ApiException.bad("Имя не может быть пустым");
            db.update("update users set full_name=? where id=?", r.fullName().trim(), CurrentUser.id());
        }
        if (r.avatarUrl() != null) {
            ownedMedia(r.avatarUrl(), "IMAGE");
            db.update("update users set avatar_url=? where id=?", r.avatarUrl(), CurrentUser.id());
        }
        return me();
    }
    public List<Map<String, Object>> categories() {
        var all = db.list("select id,name,parent_id from categories order by id");
        return children(all, null);
    }
    private List<Map<String, Object>> children(List<Map<String, Object>> all, Object parent) {
        var out = new ArrayList<Map<String, Object>>();
        for (var c:all)if(Objects.equals(c.get("parentId"), parent)) {
            var m = new LinkedHashMap<String, Object>();
            m.put("id", c.get("id"));
            m.put("name", c.get("name"));
            m.put("children", children(all, c.get("id")));
            out.add(m);
        }
        return out;
    }
    public Object regions() {
        return db.list("select id,name from regions order by id");
    }
    public Object cities(long region) {
        db.one("select id from regions where id=?", region);
        return db.list("select id,name from cities where region_id=? order by name", region);
    }
    public static void pagination(int page, int size) {
        if (page<0 || page>1000000 || size<1 || size>100)throw ApiException.bad("page: 0..1000000, size: 1..100");
    }
    public Map<String, Object> page(String from, List<Object> args, int page, int size, String order) {
        pagination(page, size);
        long total = db.count("select count(*) " + from, args.toArray());
        var a = new ArrayList<>(args);
        a.add(size);
        a.add((long)page*size);
        var items = db.list("select p.* " + from + " order by " + order + " limit ? offset ?", a.toArray());
        for (var p:items)enrich(p);
        return Map.of("items", items, "total", total, "page", page, "size", size);
    }
    public Object products(String q, Long category, Long region, Long city, String currency, java.math.BigDecimal min, java.math.BigDecimal max, int page, int size, String sort, UUID owner, boolean favorites) {
        if (q != null && q.length()>200)throw ApiException.bad("Слишком длинный поисковый запрос");
        if (min != null && min.signum()<0 || max != null && max.signum()<0 || min != null && max != null && min.compareTo(max)>0)throw ApiException.bad("Неверный диапазон цены");
        if (currency != null && !List.of("KGS", "USD", "EUR", "RUB", "KZT").contains(currency))throw ApiException.bad("Неизвестная валюта");
        var sql = new StringBuilder("from products p where 1=1");
        var args = new ArrayList<Object>();
        if (q != null && !q.isBlank()) {
            sql.append(" and (lower(p.title) like ? escape '!' or lower(p.description) like ? escape '!')");
            String term = "%" + q.toLowerCase(Locale.ROOT).replace("!", "!!").replace("%", "!%").replace("_", "!_") + "%";
            args.add(term);
            args.add(term);
        }
        if (category != null) {
            sql.append(" and p.category_id in (with recursive tree(id) as (select id from categories where id=? union all select c.id from categories c join tree t on c.parent_id=t.id) select id from tree)");
            args.add(category);
        }
        add(sql, args, "p.region_id", region);
        add(sql, args, "p.city_id", city);
        add(sql, args, "p.currency", currency);
        if (min != null) {
            sql.append(" and p.price>=?");
            args.add(min);
        }
        if (max != null) {
            sql.append(" and p.price<=?");
            args.add(max);
        }
        add(sql, args, "p.user_id", owner);
        if (favorites) {
            sql.append(" and exists(select 1 from favorites f where f.product_id=p.id and f.user_id=?)");
            args.add(CurrentUser.id());
        }
        String order = switch(sort) {
            case "createdAt,desc", "newest" -> "p.created_at desc,p.id";
            case "createdAt,asc" -> "p.created_at asc,p.id";
            case "price,asc" -> "p.price asc,p.id";
            case "price,desc" -> "p.price desc,p.id";
            default -> throw ApiException.bad("sort: createdAt,desc | createdAt,asc | price,asc | price,desc");
        };
        return page(sql.toString(), args, page, size, order);
    }
    private void add(StringBuilder s, List<Object>a, String column, Object v) {
        if (v != null) {
            s.append(" and ").append(column).append("=?");
            a.add(v);
        }
    }
    public Map<String, Object> product(UUID id) {
        return enrich(db.one("select * from products where id=?", id));
    }
    private Map<String, Object> enrich(Map<String, Object> p) {
        UUID id = (UUID)p.get("id");
        p.put("media", db.list("select id as media_id,url,type,size from media where product_id=? order by id", id));
        p.put("seller", publicUser((UUID)p.get("userId")));
        p.put("category", db.one("select id,name from categories where id=?", p.get("categoryId")));
        p.put("region", db.one("select id,name from regions where id=?", p.get("regionId")));
        p.put("city", db.one("select id,name from cities where id=?", p.get("cityId")));
        p.put("likesCount", db.count("select count(*) from favorites where product_id=?", id));
        UUID viewer = CurrentUser.optional();
        p.put("isFavorite", viewer != null && db.count("select count(*) from favorites where product_id=? and user_id=?", id, viewer)>0);
        return p;
    }
    @Transactional public Object create(Requests.Product r) {
        links(r.whatsappLink(), r.telegramLink());
        UUID id = UUID.randomUUID();
        db.update("insert into products(id,user_id,title,description,category_id,price,currency,region_id,city_id,phone,whatsapp_link,telegram_link) values(?,?,?,?,?,?,?,?,?,?,?,?)", id, CurrentUser.id(), r.title().trim(), r.description(), r.categoryId(), r.price(), r.currency(), r.regionId(), r.cityId(), r.phone(), r.whatsappLink(), r.telegramLink());
        attach(id, r.media());
        return product(id);
    }
    @Transactional public Object patch(UUID id, Requests.ProductPatch r) {
        var p = ownedProduct(id);
        links(r.whatsappLink(), r.telegramLink());
        String[] columns = {
            "title", "description", "category_id", "price", "currency", "region_id", "city_id", "phone", "whatsapp_link", "telegram_link"
        };
        Object[] values = {
            r.title(), r.description(), r.categoryId(), r.price(), r.currency(), r.regionId(), r.cityId(), r.phone(), r.whatsappLink(), r.telegramLink()
        };
        var set = new ArrayList<String>();
        var args = new ArrayList<Object>();
        for (int i = 0; i<columns.length; i++)if(values[i] != null) {
            if ((i == 0 || i == 1) && values[i].toString().isBlank())throw ApiException.bad("Название и описание не могут быть пустыми");
            set.add(columns[i] + "=?");
            args.add(values[i]);
        }
        if (!set.isEmpty()) {
            args.add(id);
            db.update("update products set " + String.join(",", set) + ",updated_at=CURRENT_TIMESTAMP where id=?", args.toArray());
        }
        if (r.media() != null) {
            db.update("update media set product_id=null where product_id=?", id);
            attach(id, r.media());
        }
        return product(id);
    }
    @Transactional public void delete(UUID id) {
        ownedProduct(id);
        db.update("delete from products where id=?", id);
    }
    public Map<String, Object> ownedProduct(UUID id) {
        var p = db.one("select * from products where id=? for update", id);
        if (!p.get("userId").equals(CurrentUser.id()) && !CurrentUser.admin())throw ApiException.forbidden();
        return p;
    }
    private void attach(UUID product, List<Requests.MediaRef> media) {
        if (media == null)return;
        for (var ref:media) {
            var m = db.one("select * from media where id=? for update", ref.mediaId());
            if (!m.get("userId").equals(CurrentUser.id()) || m.get("productId") != null && !m.get("productId").equals(product))throw ApiException.forbidden();
            db.update("update media set product_id=? where id=?", product, ref.mediaId());
        }
    }
    public void ownedMedia(String url, String type) {
        if (db.count("select count(*) from media where url=? and user_id=? and type=?", url, CurrentUser.id(), type) == 0)throw ApiException.bad("Используйте файл, загруженный вашим пользователем");
    }
    private void links(String wa, String tg) {
        if (wa != null && !wa.isEmpty() && !wa.matches("https://(wa\\.me|api\\.whatsapp\\.com)/[^\\s]*"))throw ApiException.bad("Неверная ссылка WhatsApp");
        if (tg != null && !tg.isEmpty() && !tg.matches("https://t\\.me/[^\\s]*"))throw ApiException.bad("Неверная ссылка Telegram");
    }
    @Transactional public void favorite(UUID product, boolean add) {
        var p = db.one("select user_id from products where id=? for update", product);
        UUID user = CurrentUser.id();
        if (add) {
            if (db.count("select count(*) from favorites where product_id=? and user_id=?", product, user) == 0) {
                db.update("insert into favorites(user_id,product_id) values(?,?)", user, product);
                if (!p.get("userId").equals(user))db.update("insert into notifications(id,user_id,actor_id,type,product_id) values(?,?,?,?,?)", UUID.randomUUID(), p.get("userId"), user, "PRODUCT_LIKE", product);
            }
        }
        else db.update("delete from favorites where product_id=? and user_id=?", product, user);
    }
    public Object favoriteCount() {
        return Map.of("count", db.count("select count(*) from favorites where user_id=?", CurrentUser.id()));
    }
}
