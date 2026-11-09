// API mínima: GET /health consulta la base de datos y responde su estado.
const http = require("http");
const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.DB_HOST || "db",
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectionTimeoutMillis: 3000,
});

const send = (res, code, body) => {
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
};

http
  .createServer(async (req, res) => {
    if (req.url !== "/health") return send(res, 404, { error: "not found" });
    try {
      const { rows } = await pool.query("SELECT NOW() AS now");
      send(res, 200, { status: "ok", db: "up", time: rows[0].now });
    } catch (err) {
      send(res, 503, { status: "error", db: "down", detail: err.message });
    }
  })
  .listen(3000, () => console.log("backend escuchando en :3000"));
