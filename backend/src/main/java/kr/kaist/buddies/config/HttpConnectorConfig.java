package kr.kaist.buddies.config;

import org.apache.catalina.connector.Connector;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
import org.springframework.boot.web.servlet.server.ServletWebServerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class HttpConnectorConfig {
    @Bean
    ServletWebServerFactory servletWebServerFactory(
        @Value("${buddies.http.enabled:false}") boolean httpEnabled,
        @Value("${buddies.http.port:8080}") int httpPort
    ) {
        TomcatServletWebServerFactory factory = new TomcatServletWebServerFactory();
        if (httpEnabled) {
            Connector connector = new Connector("org.apache.coyote.http11.Http11NioProtocol");
            connector.setScheme("http");
            connector.setPort(httpPort);
            connector.setSecure(false);
            factory.addAdditionalTomcatConnectors(connector);
        }
        return factory;
    }
}
