package kr.kaist.buddies;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class BuddiesApplication {
    public static void main(String[] args) {
        SpringApplication.run(BuddiesApplication.class, args);
    }
}
