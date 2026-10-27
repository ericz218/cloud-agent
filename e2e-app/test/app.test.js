import test from "node:test";
import assert from "node:assert/strict";
import { status } from "../app.js";

test("status reports ok with a non-empty message", () => {
  const s = status();
  assert.equal(s.ok, true);
  assert.ok(s.message.length > 0);
});
