CREATE TABLE users (
 id UUID PRIMARY KEY, email VARCHAR(254) NOT NULL UNIQUE, phone VARCHAR(20) NOT NULL UNIQUE,
 full_name VARCHAR(120) NOT NULL, password_hash VARCHAR(100) NOT NULL, avatar_url VARCHAR(2048),
 role VARCHAR(10) NOT NULL DEFAULT 'USER' CHECK(role IN ('USER','ADMIN')), token_version INT NOT NULL DEFAULT 0,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE categories(id BIGINT PRIMARY KEY, name VARCHAR(120) NOT NULL, parent_id BIGINT REFERENCES categories(id));
CREATE TABLE regions(id BIGINT PRIMARY KEY, name VARCHAR(120) NOT NULL);
CREATE TABLE cities(id BIGINT PRIMARY KEY, region_id BIGINT NOT NULL REFERENCES regions(id), name VARCHAR(120) NOT NULL, UNIQUE(id, region_id));
CREATE TABLE products (
 id UUID PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id), title VARCHAR(200) NOT NULL,
 description TEXT NOT NULL, category_id BIGINT NOT NULL REFERENCES categories(id), price NUMERIC(14,2) NOT NULL CHECK(price>=0),
 currency VARCHAR(3) NOT NULL CHECK(currency IN ('KGS','USD','EUR','RUB','KZT')),
 region_id BIGINT NOT NULL REFERENCES regions(id), city_id BIGINT NOT NULL,
 phone VARCHAR(20) NOT NULL, whatsapp_link VARCHAR(2048), telegram_link VARCHAR(2048),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(city_id,region_id) REFERENCES cities(id,region_id)
);
CREATE INDEX products_filters_idx ON products(category_id,region_id,city_id,price);
CREATE INDEX products_owner_idx ON products(user_id,created_at);
CREATE TABLE media(id UUID PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id), product_id UUID REFERENCES products(id) ON DELETE CASCADE,
 url VARCHAR(2048) NOT NULL UNIQUE, type VARCHAR(10) NOT NULL, size BIGINT NOT NULL, object_key VARCHAR(255) NOT NULL);
CREATE TABLE favorites(user_id UUID REFERENCES users(id), product_id UUID REFERENCES products(id) ON DELETE CASCADE,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(user_id,product_id));
CREATE TABLE comments(id UUID PRIMARY KEY, product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id), text VARCHAR(3000) NOT NULL, parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX comments_product_idx ON comments(product_id,created_at);
CREATE TABLE comment_likes(user_id UUID REFERENCES users(id), comment_id UUID REFERENCES comments(id) ON DELETE CASCADE, PRIMARY KEY(user_id,comment_id));
CREATE TABLE chats(id UUID PRIMARY KEY, user_a UUID NOT NULL REFERENCES users(id), user_b UUID NOT NULL REFERENCES users(id),
 product_id UUID REFERENCES products(id) ON DELETE SET NULL, updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CHECK(user_a<>user_b), UNIQUE(user_a,user_b));
CREATE TABLE messages(id UUID PRIMARY KEY, chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id), type VARCHAR(10) NOT NULL CHECK(type IN ('TEXT','IMAGE','VIDEO')),
 content VARCHAR(5000) NOT NULL, media_url VARCHAR(2048), is_read BOOLEAN NOT NULL DEFAULT FALSE,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX messages_chat_idx ON messages(chat_id,created_at);
CREATE INDEX messages_unread_idx ON messages(user_id,is_read);
CREATE TABLE notifications(id UUID PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id), actor_id UUID REFERENCES users(id),
 type VARCHAR(20) NOT NULL, product_id UUID REFERENCES products(id) ON DELETE CASCADE,
 is_read BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX notifications_user_idx ON notifications(user_id,is_read,created_at);
