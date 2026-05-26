package kr.kaist.buddies.auth;

import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class PasswordResetPageController {
    @GetMapping(value = "/password-reset", produces = MediaType.TEXT_HTML_VALUE)
    @ResponseBody
    public String passwordResetPage() {
        return """
            <!doctype html>
            <html lang="ko">
              <head>
                <meta charset="utf-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1" />
                <title>Buddies Password Reset</title>
              </head>
              <body>
                <main>
                  <h1>비밀번호 재설정</h1>
                  <form id="resetForm">
                    <label>
                      Reset token
                      <input id="token" name="token" required />
                    </label>
                    <br />
                    <label>
                      새 비밀번호
                      <input id="newPassword" name="newPassword" type="password" required />
                    </label>
                    <br />
                    <label>
                      새 비밀번호 확인
                      <input id="newPasswordConfirm" name="newPasswordConfirm" type="password" required />
                    </label>
                    <br />
                    <button type="submit">비밀번호 변경</button>
                  </form>
                  <pre id="result"></pre>
                </main>
                <script>
                  const tokenInput = document.getElementById("token");
                  const result = document.getElementById("result");
                  tokenInput.value = new URLSearchParams(location.search).get("token") ?? "";

                  document.getElementById("resetForm").addEventListener("submit", async (event) => {
                    event.preventDefault();
                    const response = await fetch("/auth/password-reset/confirm", {
                      method: "POST",
                      headers: {
                        "Accept": "application/json",
                        "Content-Type": "application/json"
                      },
                      body: JSON.stringify({
                        token: tokenInput.value.trim(),
                        newPassword: document.getElementById("newPassword").value,
                        newPasswordConfirm: document.getElementById("newPasswordConfirm").value
                      })
                    });
                    const text = await response.text();
                    result.textContent = `${response.status} ${response.statusText}\\n${text}`;
                  });
                </script>
              </body>
            </html>
            """;
    }
}
