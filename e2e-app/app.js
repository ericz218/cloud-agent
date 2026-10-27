import { readFileSync } from "node:fs";

export function status() {
  return {
    ok: true,
    message: readFileSync(new URL("./message.txt", import.meta.url), "utf8").trim(),
    commit: process.env.RENDER_GIT_COMMIT ?? null,
  };
}
