package com.example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;
import java.sql.*;
import java.util.*;

public class HelloHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    private static final String DB_HOST     = env("DB_HOST",     "database-edumgt.cg0ugoglztrn.ap-northeast-2.rds.amazonaws.com");
    private static final String DB_PORT     = env("DB_PORT",     "3306");
    private static final String DB_NAME     = env("DB_NAME",     "edumgt");
    private static final String DB_USER     = env("DB_USER",     "root");
    private static final String DB_PASSWORD = env("DB_PASSWORD", "12345678");

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static Connection sharedConn;

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> input, Context context) {
        // Support both REST API (v1: httpMethod) and Function URL / HTTP API (v2: requestContext.http.method)
        String method = (String) input.get("httpMethod");
        if (method == null) {
            Map<?, ?> rc = (Map<?, ?>) input.get("requestContext");
            if (rc != null) {
                Map<?, ?> http = (Map<?, ?>) rc.get("http");
                if (http != null) method = (String) http.get("method");
            }
        }

        String rawPath = (String) input.getOrDefault("rawPath", input.getOrDefault("path", "/"));

        // v1 REST API: pathParameters.id, v2/URL: extract from rawPath
        String userId = null;
        Map<?, ?> pathParams = (Map<?, ?>) input.get("pathParameters");
        if (pathParams != null && pathParams.get("id") != null) {
            userId = (String) pathParams.get("id");
        } else if (rawPath != null && rawPath.matches("/users/[^/]+")) {
            userId = rawPath.replaceFirst("^/users/", "");
        }

        String body = (String) input.get("body");

        try {
            if ("GET".equalsIgnoreCase(method) && userId == null)    return listUsers();
            if ("GET".equalsIgnoreCase(method))                      return getUser(userId);
            if ("POST".equalsIgnoreCase(method))                     return createUser(body);
            if ("PUT".equalsIgnoreCase(method) && userId != null)    return updateUser(userId, body);
            if ("DELETE".equalsIgnoreCase(method) && userId != null) return deleteUser(userId);
            if ("OPTIONS".equalsIgnoreCase(method))                  return response(200, "");
            return response(405, error("Method Not Allowed"));
        } catch (Exception e) {
            sharedConn = null;
            return response(500, error(e.getMessage()));
        }
    }

    // GET /users
    private Map<String, Object> listUsers() throws Exception {
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection c = getConnection();
             Statement st = c.createStatement();
             ResultSet rs = st.executeQuery(
                 "SELECT id, name, phone, email, created_at FROM users ORDER BY created_at DESC")) {
            while (rs.next()) list.add(toMap(rs));
        }
        return response(200, MAPPER.writeValueAsString(list));
    }

    // GET /users/{id}
    private Map<String, Object> getUser(String id) throws Exception {
        try (Connection c = getConnection();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT id, name, phone, email, created_at FROM users WHERE id = ?")) {
            ps.setString(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return response(200, MAPPER.writeValueAsString(toMap(rs)));
                return response(404, error("User not found"));
            }
        }
    }

    // POST /users  body: { "name", "password", "phone"?, "email"? }
    private Map<String, Object> createUser(String body) throws Exception {
        Map<?, ?> data = MAPPER.readValue(body, Map.class);
        String id = UUID.randomUUID().toString();
        try (Connection c = getConnection();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO users (id, name, password, phone, email) VALUES (?, ?, ?, ?, ?)")) {
            ps.setString(1, id);
            ps.setString(2, (String) data.get("name"));
            ps.setString(3, sha256((String) data.get("password")));
            ps.setString(4, (String) data.getOrDefault("phone", null));
            ps.setString(5, (String) data.getOrDefault("email", null));
            ps.executeUpdate();
        }
        return response(201, MAPPER.writeValueAsString(Map.of("id", id, "message", "User created")));
    }

    // PUT /users/{id}  body: { "name"?, "password"?, "phone"?, "email"? }
    private Map<String, Object> updateUser(String id, String body) throws Exception {
        Map<?, ?> data = MAPPER.readValue(body, Map.class);
        List<String> setClauses = new ArrayList<>();
        List<Object> values = new ArrayList<>();

        if (data.containsKey("name"))     { setClauses.add("name = ?");     values.add(data.get("name")); }
        if (data.containsKey("password")) { setClauses.add("password = ?"); values.add(sha256((String) data.get("password"))); }
        if (data.containsKey("phone"))    { setClauses.add("phone = ?");    values.add(data.get("phone")); }
        if (data.containsKey("email"))    { setClauses.add("email = ?");    values.add(data.get("email")); }

        if (setClauses.isEmpty()) return response(400, error("No fields to update"));

        values.add(id);
        String sql = "UPDATE users SET " + String.join(", ", setClauses) + " WHERE id = ?";
        try (Connection c = getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            for (int i = 0; i < values.size(); i++) ps.setObject(i + 1, values.get(i));
            if (ps.executeUpdate() == 0) return response(404, error("User not found"));
        }
        return response(200, MAPPER.writeValueAsString(Map.of("message", "User updated")));
    }

    // DELETE /users/{id}
    private Map<String, Object> deleteUser(String id) throws Exception {
        try (Connection c = getConnection();
             PreparedStatement ps = c.prepareStatement("DELETE FROM users WHERE id = ?")) {
            ps.setString(1, id);
            if (ps.executeUpdate() == 0) return response(404, error("User not found"));
        }
        return response(200, MAPPER.writeValueAsString(Map.of("message", "User deleted")));
    }

    // ── DB helpers ──────────────────────────────────────────────────────────

    private synchronized Connection getConnection() throws Exception {
        if (sharedConn != null && sharedConn.isValid(2)) return sharedConn;
        String trustStorePath = buildTrustStore();
        String url = String.format(
            "jdbc:mysql://%s:%s/%s?useSSL=true&requireSSL=true" +
            "&trustCertificateKeyStoreUrl=file://%s" +
            "&trustCertificateKeyStorePassword=changeit" +
            "&trustCertificateKeyStoreType=JKS" +
            "&serverTimezone=Asia/Seoul",
            DB_HOST, DB_PORT, DB_NAME, trustStorePath);
        sharedConn = DriverManager.getConnection(url, DB_USER, DB_PASSWORD);
        return sharedConn;
    }

    private String buildTrustStore() throws Exception {
        Path p = Path.of("/tmp/rds-truststore.jks");
        if (Files.exists(p)) return p.toString();
        KeyStore ks = KeyStore.getInstance("JKS");
        ks.load(null, null);
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        try (InputStream is = getClass().getResourceAsStream("/global-bundle.pem")) {
            Collection<? extends Certificate> certs = cf.generateCertificates(is);
            int i = 0;
            for (Certificate cert : certs) ks.setCertificateEntry("rds-ca-" + i++, cert);
        }
        try (OutputStream os = Files.newOutputStream(p)) {
            ks.store(os, "changeit".toCharArray());
        }
        return p.toString();
    }

    // ── Util ────────────────────────────────────────────────────────────────

    private Map<String, Object> toMap(ResultSet rs) throws SQLException {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id",         rs.getString("id"));
        m.put("name",       rs.getString("name"));
        m.put("phone",      rs.getString("phone"));
        m.put("email",      rs.getString("email"));
        m.put("created_at", rs.getString("created_at"));
        return m;
    }

    private String sha256(String plain) throws Exception {
        if (plain == null) return null;
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] hash = md.digest(plain.getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        for (byte b : hash) sb.append(String.format("%02x", b));
        return sb.toString();
    }

    private String error(String msg) {
        return "{\"error\":\"" + (msg == null ? "unknown" : msg.replace("\"", "'")) + "\"}";
    }

    private Map<String, Object> response(int status, String body) {
        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");
        headers.put("Access-Control-Allow-Origin", "*");
        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("statusCode", status);
        resp.put("headers", headers);
        resp.put("body", body);
        return resp;
    }

    private static String env(String key, String def) {
        String v = System.getenv(key);
        return (v != null && !v.isBlank()) ? v : def;
    }
}
