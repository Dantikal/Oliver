package kg.oliver.service;

import kg.oliver.api.*;
import kg.oliver.auth.CurrentUser;
import kg.oliver.repository.Store;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service
public class CommunityService {
    private final Store db;
    public CommunityService(Store db) {
        this.db = db;
    }
    public Object comments(UUID product, int page, int size) {
        CatalogService.pagination(page, size);
        db.one("select id from products where id=?", product);
        var items = db.list("select id from comments where product_id=? and parent_comment_id is null order by created_at,id limit ? offset ?", product, size, (long)page*size).stream().map(c -> comment((UUID)c.get("id"))).toList();
        return Map.of("items", items, "total", db.count("select count(*) from comments where product_id=? and parent_comment_id is null", product), "page", page, "size", size);
    }
    public Map<String, Object> comment(UUID id) {
        var c = db.one("select c.*,u.full_name,u.avatar_url from comments c join users u on u.id=c.user_id where c.id=?", id);
        c.put("likesCount", db.count("select count(*) from comment_likes where comment_id=?", id));
        UUID user = CurrentUser.optional();
        c.put("isLiked", user != null && db.count("select count(*) from comment_likes where comment_id=? and user_id=?", id, user)>0);
        c.put("replies", db.list("select id from comments where parent_comment_id=? order by created_at,id", id).stream().map(r -> comment((UUID)r.get("id"))).toList());
        return c;
    }
    @Transactional public Object add(UUID product, Requests.Comment r) {
        db.one("select id from products where id=?", product);
        if (r.parentCommentId() != null) {
            var parent = db.one("select product_id,parent_comment_id from comments where id=? for update", r.parentCommentId());
            if (!parent.get("productId").equals(product))throw ApiException.bad("Комментарий относится к другому товару");
            if (parent.get("parentCommentId") != null)throw ApiException.bad("Ответы разрешены только на основной комментарий");
        }
        UUID id = UUID.randomUUID();
        db.update("insert into comments(id,product_id,user_id,text,parent_comment_id) values(?,?,?,?,?)", id, product, CurrentUser.id(), r.text(), r.parentCommentId());
        return comment(id);
    }
    @Transactional public void delete(UUID id) {
        var c = db.one("select user_id from comments where id=? for update", id);
        if (!c.get("userId").equals(CurrentUser.id()) && !CurrentUser.admin())throw ApiException.forbidden();
        db.update("delete from comments where id=?", id);
    }
    @Transactional public Object like(UUID id, boolean add) {
        db.one("select id from comments where id=? for update", id);
        UUID user = CurrentUser.id();
        if (add) {
            if (db.count("select count(*) from comment_likes where comment_id=? and user_id=?", id, user) == 0)db.update("insert into comment_likes(user_id,comment_id) values(?,?)", user, id);
        }
        else db.update("delete from comment_likes where comment_id=? and user_id=?", id, user);
        return Map.of("likesCount", db.count("select count(*) from comment_likes where comment_id=?", id));
    }
    public Object notifications(int page, int size) {
        CatalogService.pagination(page, size);
        return Map.of("items", db.list("select * from notifications where user_id=? order by created_at desc,id limit ? offset ?", CurrentUser.id(), size, (long)page*size), "total", db.count("select count(*) from notifications where user_id=?", CurrentUser.id()), "page", page, "size", size);
    }
    public Object counters() {
        UUID id = CurrentUser.id();
        return Map.of("unreadMessages", db.count("select count(*) from messages m join chats c on c.id=m.chat_id where (c.user_a=? or c.user_b=?) and m.user_id<>? and m.is_read=false", id, id, id), "newLikes", db.count("select count(*) from notifications where user_id=? and type='PRODUCT_LIKE' and is_read=false", id), "unreadNotifications", db.count("select count(*) from notifications where user_id=? and is_read=false", id));
    }
    @Transactional public void read(Requests.Read r) {
        for (UUID id:r.ids())db.update("update notifications set is_read=true where id=? and user_id=?", id, CurrentUser.id());
    }
}
