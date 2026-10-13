package kg.oliver.config;

import org.springframework.context.annotation.*;
import org.springframework.beans.factory.annotation.Value;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.auth.credentials.*;
import java.net.URI;

@Configuration
public class StorageConfig {
    @Bean S3Client s3(@Value("${app.s3.endpoint}") String endpoint, @Value("${app.s3.region}") String region, @Value("${app.s3.access-key}") String key, @Value("${app.s3.secret-key}") String secret) {
        return S3Client.builder().endpointOverride(URI.create(endpoint)).region(Region.of(region)).credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(key, secret))).forcePathStyle(true).build();
    }
}
