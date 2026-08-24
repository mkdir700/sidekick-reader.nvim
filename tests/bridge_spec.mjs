import assert from "node:assert/strict";
import { allocatePort, registrationPath, shouldEmit } from "../scripts/bridge.mjs";

const port = await allocatePort();
assert(port > 0 && port < 65536, "a usable loopback port should be allocated");
assert.equal(registrationPath("/tmp/hajimi", "%7"), "/tmp/hajimi/%7.json");
assert.equal(shouldEmit({ id: 2, result: { data: [{ id: "many-global-sessions" }] } }), false);
assert.equal(shouldEmit({ id: 3, result: { thread: { id: "active" } } }), true);
assert.equal(shouldEmit({ method: "item/agentMessage/delta", params: {} }), true);

console.log("bridge_spec: ok");
