package kr.kaist.buddies.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class PublicUrlBuilder {
    private static final String LOCAL_PUBLIC_BASE_URL = "https://localhost:8443";
    // Set this once to the Linux server address used by external devices.
    private static final String EXTERNAL_HTTPS_PUBLIC_BASE_URL = "https://110.76.94.211:8443";
    private static final String EXTERNAL_HTTP_PUBLIC_BASE_URL = "http://110.76.94.211:8080";

    private final String publicBaseUrl;

    public PublicUrlBuilder(
        @Value("${buddies.external-access:false}") boolean externalAccess,
        @Value("${buddies.http.enabled:false}") boolean httpEnabled
    ) {
        if (!externalAccess) {
            this.publicBaseUrl = trimTrailingSlash(LOCAL_PUBLIC_BASE_URL);
        } else {
            this.publicBaseUrl = trimTrailingSlash(httpEnabled ? EXTERNAL_HTTP_PUBLIC_BASE_URL : EXTERNAL_HTTPS_PUBLIC_BASE_URL);
        }
    }

    public String url(String path) {
        if (path == null || path.isBlank()) {
            return publicBaseUrl;
        }
        String normalizedPath = path.startsWith("/") ? path : "/" + path;
        return publicBaseUrl + normalizedPath;
    }

    private String trimTrailingSlash(String value) {
        String normalized = value == null || value.isBlank() ? LOCAL_PUBLIC_BASE_URL : value.trim();
        while (normalized.endsWith("/") && normalized.length() > 1) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        return normalized;
    }
}
