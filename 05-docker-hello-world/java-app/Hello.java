import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class Hello {

    private static final int PORT = 8080;

    private static final String PAGE = """
            <!DOCTYPE html>
            <html lang="en">
              <head>
                <meta charset="utf-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1" />
                <title>Hello World - Java</title>
                <style>
                  body { margin: 0; min-height: 100vh; display: grid; place-items: center;
                         background: #0f172a; color: #e2e8f0;
                         font-family: system-ui, -apple-system, sans-serif; }
                  .card { background: #1e293b; border: 1px solid #334155; border-radius: 14px;
                          padding: 2.5rem 3.5rem; text-align: center; }
                  h1 { margin: 0 0 0.6rem; font-size: 2.6rem; }
                  p { margin: 0; color: #94a3b8; font-family: ui-monospace, monospace; }
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>Hello World</h1>
                  <p>java-app &middot; eclipse-temurin:21</p>
                </div>
              </body>
            </html>
            """;

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", PORT), 0);

        server.createContext("/", exchange -> {
            byte[] body = PAGE.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(body);
            }
        });

        server.start();
        System.out.println("java-app listening on port " + PORT);
    }
}
