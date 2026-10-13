package kg.oliver.service;

import kg.oliver.api.*;
import kg.oliver.auth.CurrentUser;
import kg.oliver.repository.Store;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service
public class ChatService {
    private final Store db;
    private final ChatEvents events;
    private final CatalogService catalog;
    public ChatService(Store db, ChatEvents events, CatalogService catalog) {
        this.db = db;
        this.events = events;
        this.catalog = catalog;
    }
    public Map<String, Object> member(UUID chat, UUID user) {
        var c = db.one("select * from chats where id=?", chat);
        if (!c.get("userA").equals(user) && !c.get("userB").equals(user))throw ApiException.forbidden();
        return c;
    }
    public Object list() {
        UUID user = CurrentUser.id();
        var chats = db.list("select * from chats where user_a=? or user_b=? order by updated_at desc,id", user, user);
        return chats.stream().map(c -> {
            UUID id = (UUID)c.get("id");
            UUID peer = (UUID)(c.get("userA").equals(user)?c.get("userB"):c.get("userA"));
            var out = new LinkedHashMap<String, Object>();
            out.put("chatId", id);
            out.put("peer", catalog.publicUser(peer));
            out.put("lastMessage", db.optional("select * from messages where chat_id=? order by created_at desc,id desc limit 1", id).orElse(null));
            out.put("unreadCount", db.count("select count(*) from messages where chat_id=? and user_id<>? and is_read=false", id, user));
            out.put("updatedAt", c.get("updatedAt"));
            return out;
        }
        ).toList();
    }
    @Transactional public Object create(Requests.Chat r) {
        UUID me = CurrentUser.id();
        if (me.equals(r.peerId()))throw ApiException.bad("Нельзя создать чат с собой");
        UUID a = me.toString().compareTo(r.peerId().toString())<0?me:r.peerId();
        UUID b = a.equals(me)?r.peerId():me;
        // Lock both users in a fixed order: makes concurrent creation idempotent across replicas.
        db.one("select id from users where id=? for update", a);
        db.one("select id from users where id=? for update", b);
        if (r.productId() != null) {
            var p = db.one("select user_id from products where id=?", r.productId());
            if (!p.get("userId").equals(r.peerId()))throw ApiException.bad("Товар должен принадлежать собеседнику");
        }
        var existing = db.optional("select id from chats where user_a=? and user_b=?", a, b);
        if (existing.isPresent())return Map.of("chatId", existing.get().get("id"));
        UUID id = UUID.randomUUID();
        db.update("insert into chats(id,user_a,user_b,product_id) values(?,?,?,?)", id, a, b, r.productId());
        return Map.of("chatId", id);
    }
    public Object messages(UUID chat, int page, int size) {
        member(chat, CurrentUser.id());
        CatalogService.pagination(page, size);
        return Map.of("items", db.list("select * from messages where chat_id=? order by created_at desc,id desc limit ? offset ?", chat, size, (long)page*size), "total", db.count("select count(*) from messages where chat_id=?", chat), "page", page, "size", size);
    }
    @Transactional public Object send(UUID chat, UUID user, Requests.Message r) {
        member(chat, user);
        db.one("select id from chats where id=? for update", chat);
        if (r.type().equals("TEXT")) {
            if (r.content().isBlank() || r.mediaUrl() != null)throw ApiException.bad("Текстовое сообщение должно содержать текст без mediaUrl");
        }
        else {
            if (r.mediaUrl() == null || db.count("select count(*) from media where url=? and user_id=? and type=?", r.mediaUrl(), user, r.type()) == 0)throw ApiException.bad("Медиа должно быть загружено отправителем");
        }
        UUID id = UUID.randomUUID();
        db.update("insert into messages(id,chat_id,user_id,type,content,media_url) values(?,?,?,?,?,?)", id, chat, user, r.type(), r.content(), r.mediaUrl());
        db.update("update chats set updated_at=CURRENT_TIMESTAMP where id=?", chat);
        var m = db.one("select * from messages where id=?", id);
        events.publish(chat, Map.of("type", "MESSAGE", "message", m));
        return m;
    }
    @Transactional public void read(UUID chat, UUID user) {
        member(chat, user);
        db.one("select id from chats where id=? for update", chat);
        db.update("update messages set is_read=true where chat_id=? and user_id<>? and is_read=false", chat, user);
        events.publish(chat, Map.of("type", "READ", "userId", user));
    }
    public void typing(UUID chat, UUID user) {
        member(chat, user);
        events.publish(chat, Map.of("type", "TYPING", "userId", user));
    }
}
