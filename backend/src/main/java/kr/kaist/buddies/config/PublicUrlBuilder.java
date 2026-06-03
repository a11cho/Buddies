package kr.kaist.buddies.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class PublicUrlBuilder {
    private final String publicBaseUrl;

    public PublicUrlBuilder(@Value("${buddies.public-base-url}") String publicBaseUrl) {
        this.publicBaseUrl = trimTrailingSlash(publicBaseUrl);
    }

    public String url(String path) {
        if (path == null || path.isBlank()) {
            return publicBaseUrl;
        }
        String normalizedPath = path.startsWith("/") ? path : "/" + path;
        return publicBaseUrl + normalizedPath;
    }

    private String trimTrailingSlash(String value) {
        String normalized = value == null || value.isBlank() ? "https://localhost:8443" : value.trim();
        while (normalized.endsWith("/") && normalized.length() > 1) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        return normalized;
    }
}
