package kr.kaist.buddies.storage;

import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.HttpMethod;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.Storage.SignUrlOption;
import com.google.cloud.storage.StorageOptions;
import java.net.URL;
import java.time.Duration;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import kr.kaist.buddies.config.PublicUrlBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class ImageUploadUrlService {
    private final PublicUrlBuilder publicUrlBuilder;
    private final String bucketName;
    private final String gcsPublicBaseUrl;
    private final long signedUrlExpiresMinutes;
    private final Storage storage;

    public ImageUploadUrlService(
        PublicUrlBuilder publicUrlBuilder,
        @Value("${buddies.storage.gcs.bucket-name:}") String bucketName,
        @Value("${buddies.storage.gcs.public-base-url:}") String gcsPublicBaseUrl,
        @Value("${buddies.storage.gcs.signed-url-expires-minutes:15}") long signedUrlExpiresMinutes
    ) {
        this.publicUrlBuilder = publicUrlBuilder;
        this.bucketName = normalize(bucketName);
        this.gcsPublicBaseUrl = trimTrailingSlash(gcsPublicBaseUrl);
        this.signedUrlExpiresMinutes = signedUrlExpiresMinutes <= 0 ? 15 : signedUrlExpiresMinutes;
        this.storage = this.bucketName == null ? null : StorageOptions.getDefaultInstance().getService();
    }

    public ImageUploadUrl issue(String directory, String contentType) {
        String objectName = normalizeDirectory(directory) + "/" + UUID.randomUUID() + extensionFor(contentType);
        if (bucketName == null) {
            return new ImageUploadUrl(
                publicUrlBuilder.url("/uploads/" + objectName),
                publicUrlBuilder.url("/media/" + objectName)
            );
        }

        BlobInfo blobInfo = BlobInfo.newBuilder(bucketName, objectName)
            .setContentType(contentType)
            .build();
        URL signedUrl = storage.signUrl(
            blobInfo,
            signedUrlExpiresMinutes,
            TimeUnit.MINUTES,
            SignUrlOption.httpMethod(HttpMethod.PUT),
            SignUrlOption.withV4Signature(),
            SignUrlOption.withVirtualHostedStyle(),
            SignUrlOption.withExtHeaders(Map.of("Content-Type", contentType))
        );
        return new ImageUploadUrl(signedUrl.toString(), mediaUrl(objectName));
    }

    private String mediaUrl(String objectName) {
        if (gcsPublicBaseUrl != null) {
            return gcsPublicBaseUrl + "/" + objectName;
        }
        return "https://" + bucketHostName() + "/" + objectName;
    }

    private String bucketHostName() {
        return bucketName + ".storage.googleapis.com";
    }

    private String normalizeDirectory(String directory) {
        String normalized = normalize(directory);
        if (normalized == null) {
            return "images";
        }
        while (normalized.startsWith("/")) {
            normalized = normalized.substring(1);
        }
        while (normalized.endsWith("/") && normalized.length() > 1) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        return normalized.isBlank() ? "images" : normalized;
    }

    private String extensionFor(String contentType) {
        return switch (contentType.toLowerCase(Locale.ROOT)) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/gif" -> ".gif";
            case "image/webp" -> ".webp";
            default -> "";
        };
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private String trimTrailingSlash(String value) {
        String normalized = normalize(value);
        if (normalized == null) {
            return null;
        }
        while (normalized.endsWith("/") && normalized.length() > 1) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        return normalized;
    }

    public record ImageUploadUrl(String uploadUrl, String mediaUrl) {}
}
