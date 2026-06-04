FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/buddies-backend-0.1.0-SNAPSHOT.jar app.jar
RUN mkdir -p /app/ssl && \
    keytool -genkeypair \
      -alias buddies-local \
      -keyalg RSA \
      -keysize 2048 \
      -storetype PKCS12 \
      -keystore /app/ssl/dev-ssl.p12 \
      -storepass buddies-local-ssl \
      -keypass buddies-local-ssl \
      -validity 3650 \
      -dname "CN=110.76.94.211, OU=Development, O=Buddies, L=Daejeon, ST=Daejeon, C=KR" \
      -ext "SAN=dns:localhost,ip:127.0.0.1,ip:110.76.94.211"
EXPOSE 8443
ENTRYPOINT ["java", "-jar", "app.jar"]

