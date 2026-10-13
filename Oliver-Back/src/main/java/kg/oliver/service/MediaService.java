package kg.oliver.service;

import kg.oliver.api.*;
import kg.oliver.auth.CurrentUser;
import kg.oliver.repository.Store;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.core.sync.RequestBody;
import java.util.*;
import java.io.*;

@Service
public class MediaService {
    private final Store db;
    private final CatalogService catalog;
    private final S3Client s3;
    private final String bucket, publicUrl;
    public MediaService(Store db, CatalogService catalog, S3Client s3, @Value("${app.s3.bucket}") String bucket, @Value("${app.s3.public-url}") String publicUrl) {
        this.db = db;
        this.catalog = catalog;
        this.s3 = s3;
        this.bucket = bucket;
        this.publicUrl = publicUrl.replaceAll("/$", "");
    }
    @Transactional public Map<String, Object> upload(MultipartFile file, UUID product, boolean avatar)throws IOException {
        if (file.isEmpty() || file.getSize()>50L*1024*1024)throw ApiException.bad("Размер файла: от 1 байта до 50 MB");
        if (product != null) {
            catalog.ownedProduct(product);
            if (db.count("select count(*) from media where product_id=?", product) >= 20)throw ApiException.bad("Не более 20 файлов на товар");
        }
        byte[] header;
        try(var input = file.getInputStream()) {
            header = input.readNBytes(32);
        }
        String mime = detect(header);
        if (mime == null)throw ApiException.bad("Поддерживаются JPEG, PNG, WebP и MP4");
        boolean image = mime.startsWith("image/");
        if (avatar && (!image || file.getSize()>5L*1024*1024))throw ApiException.bad("Аватар: изображение до 5 MB");
        UUID id = UUID.randomUUID();
        String extension = switch(mime) {
            case "image/jpeg" -> "jpg";
            case "image/png" -> "png";
            case "image/webp" -> "webp";
            default -> "mp4";
        };
        String key = CurrentUser.id() + "/" + id + "." + extension;
        String url = publicUrl + "/" + key;
        try(InputStream input = file.getInputStream()) {
            s3.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType(mime).contentDisposition("inline").build(), RequestBody.fromInputStream(input, file.getSize()));
        }
        org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(new org.springframework.transaction.support.TransactionSynchronization() {
            public void afterCompletion(int status) {
                if (status != STATUS_COMMITTED) {
                    try {
                        s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
                    }
                    catch (Exception ignored) {}
                }
            }
        }
        );
        db.update("insert into media(id,user_id,product_id,url,type,size,object_key) values(?,?,?,?,?,?,?)", id, CurrentUser.id(), product, url, image?"IMAGE":"VIDEO", file.getSize(), key);
        if (avatar)db.update("update users set avatar_url=? where id=?", url, CurrentUser.id());
        var response = new LinkedHashMap<String, Object>();
        response.put("mediaId", id);
        response.put("url", url);
        response.put("type", image?"IMAGE":"VIDEO");
        response.put("size", file.getSize());
        return response;
    }
    static String detect(byte[] b) {
        if (b.length >= 3 && (b[0]&255) == 255 && (b[1]&255) == 216 && (b[2]&255) == 255)return "image/jpeg";
        if (b.length >= 8 && Arrays.equals(Arrays.copyOf(b, 8), new byte[] {
            (byte)137, 80, 78, 71, 13, 10, 26, 10
        }
        ))return "image/png";
        if (b.length >= 12 && ascii(b, 0, 4).equals("RIFF") && ascii(b, 8, 12).equals("WEBP"))return "image/webp";
        if (b.length >= 12 && ascii(b, 4, 8).equals("ftyp") && List.of("isom", "iso2", "mp41", "mp42", "avc1", "M4V ").contains(ascii(b, 8, 12)))return "video/mp4";
        return null;
    }
    private static String ascii(byte[] b, int a, int z) {
        return new String(Arrays.copyOfRange(b, a, z), java.nio.charset.StandardCharsets.US_ASCII);
    }
}
