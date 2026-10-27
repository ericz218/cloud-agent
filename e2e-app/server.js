import { createServer } from "node:http";
import { status } from "./app.js";

const port = Number(process.env.PORT ?? 10000);
createServer((req, res) => {
  if (req.url === "/healthz" || req.url === "/") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify(status()));
    return;
  }
  res.writeHead(404).end();
}).listen(port, () => console.log(`e2e-app listening on ${port}, commit=${process.env.RENDER_GIT_COMMIT ?? "local"}`));
