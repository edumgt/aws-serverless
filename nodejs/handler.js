const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const mysql = require("mysql2/promise");

const DB_HOST = process.env.DB_HOST || "database-edumgt.cg0ugoglztrn.ap-northeast-2.rds.amazonaws.com";
const DB_PORT = Number(process.env.DB_PORT || "3306");
const DB_NAME = process.env.DB_NAME || "edumgt";
const DB_USER = process.env.DB_USER || "root";
const DB_PASSWORD = process.env.DB_PASSWORD || "123456";
const DB_SSL_CA = process.env.DB_SSL_CA || path.resolve(__dirname, "../global-bundle.pem");

let pool;

module.exports.usersApi = async (event) => {
  const method = getMethod(event);
  const rawPath = getRawPath(event);
  const userId = extractUserId(rawPath);

  try {
    if (method === "OPTIONS") {
      return response(200, {});
    }

    if (method === "GET" && !userId) {
      return listUsers();
    }

    if (method === "GET" && userId) {
      return getUser(userId);
    }

    if (method === "POST" && isUsersCollectionPath(rawPath)) {
      return createUser(parseJsonBody(event));
    }

    if (method === "PUT" && userId) {
      return updateUser(userId, parseJsonBody(event));
    }

    if (method === "DELETE" && userId) {
      return deleteUser(userId);
    }

    return response(405, { error: "Method Not Allowed" });
  } catch (error) {
    const statusCode = error.statusCode || 500;
    return response(statusCode, { error: error.message || "Internal Server Error" });
  }
};

async function listUsers() {
  const conn = await getPool();
  const [rows] = await conn.query(
    "SELECT id, name, phone, email, created_at, updated_at FROM users ORDER BY created_at DESC"
  );
  return response(200, rows);
}

async function getUser(id) {
  const conn = await getPool();
  const [rows] = await conn.execute(
    "SELECT id, name, phone, email, created_at, updated_at FROM users WHERE id = ?",
    [id]
  );

  if (rows.length === 0) {
    throw createError(404, "User not found");
  }

  return response(200, rows[0]);
}

async function createUser(data) {
  validateRequiredFields(data, ["name", "password"]);

  const id = crypto.randomUUID();
  const conn = await getPool();

  await conn.execute(
    "INSERT INTO users (id, name, password, phone, email) VALUES (?, ?, ?, ?, ?)",
    [
      id,
      data.name,
      sha256(data.password),
      normalizeNullable(data.phone),
      normalizeNullable(data.email),
    ]
  );

  return response(201, {
    id,
    message: "User created",
  });
}

async function updateUser(id, data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw createError(400, "Request body must be a JSON object");
  }

  const fields = [];
  const values = [];

  if (Object.prototype.hasOwnProperty.call(data, "name")) {
    fields.push("name = ?");
    values.push(data.name);
  }

  if (Object.prototype.hasOwnProperty.call(data, "password")) {
    fields.push("password = ?");
    values.push(sha256(data.password));
  }

  if (Object.prototype.hasOwnProperty.call(data, "phone")) {
    fields.push("phone = ?");
    values.push(normalizeNullable(data.phone));
  }

  if (Object.prototype.hasOwnProperty.call(data, "email")) {
    fields.push("email = ?");
    values.push(normalizeNullable(data.email));
  }

  if (fields.length === 0) {
    throw createError(400, "No fields to update");
  }

  values.push(id);

  const conn = await getPool();
  const [result] = await conn.execute(
    `UPDATE users SET ${fields.join(", ")} WHERE id = ?`,
    values
  );

  if (result.affectedRows === 0) {
    throw createError(404, "User not found");
  }

  return response(200, { message: "User updated" });
}

async function deleteUser(id) {
  const conn = await getPool();
  const [result] = await conn.execute("DELETE FROM users WHERE id = ?", [id]);

  if (result.affectedRows === 0) {
    throw createError(404, "User not found");
  }

  return response(200, { message: "User deleted" });
}

async function getPool() {
  if (!pool) {
    const sslCa = fs.readFileSync(DB_SSL_CA, "utf8");
    pool = mysql.createPool({
      host: DB_HOST,
      port: DB_PORT,
      user: DB_USER,
      password: DB_PASSWORD,
      database: DB_NAME,
      waitForConnections: true,
      connectionLimit: 5,
      queueLimit: 0,
      ssl: {
        ca: sslCa,
        rejectUnauthorized: true,
        minVersion: "TLSv1.2",
        servername: DB_HOST,
      },
    });
  }

  return pool;
}

function parseJsonBody(event) {
  if (!event || event.body == null || event.body === "") {
    throw createError(400, "Request body is required");
  }

  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body, "base64").toString("utf8")
    : event.body;

  try {
    const parsed = JSON.parse(rawBody);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("JSON body must be an object");
    }
    return parsed;
  } catch (error) {
    throw createError(400, "Invalid JSON body");
  }
}

function validateRequiredFields(data, requiredFields) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw createError(400, "Request body must be a JSON object");
  }

  for (const field of requiredFields) {
    if (typeof data[field] !== "string" || data[field].trim() === "") {
      throw createError(400, `${field} is required`);
    }
  }
}

function normalizeNullable(value) {
  if (value == null || value === "") {
    return null;
  }
  return value;
}

function sha256(value) {
  return crypto.createHash("sha256").update(String(value), "utf8").digest("hex");
}

function getMethod(event) {
  return (
    event?.requestContext?.http?.method ||
    event?.httpMethod ||
    "GET"
  ).toUpperCase();
}

function getRawPath(event) {
  return event?.rawPath || event?.path || "/";
}

function isUsersCollectionPath(rawPath) {
  return /\/users\/?$/.test(rawPath);
}

function extractUserId(rawPath) {
  const match = rawPath.match(/\/users\/([^/]+)\/?$/);
  return match ? decodeURIComponent(match[1]) : null;
}

function createError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    },
    body: JSON.stringify(body),
  };
}
