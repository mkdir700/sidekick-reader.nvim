#!/usr/bin/env node

import { spawn } from "node:child_process";
import { mkdir, rename, rm, writeFile } from "node:fs/promises";
import net from "node:net";
import path from "node:path";

export function allocatePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close((error) => {
        if (error) reject(error);
        else resolve(address.port);
      });
    });
  });
}

export function registrationPath(dir, pane) {
  return path.join(dir, `${pane}.json`);
}

export function shouldEmit(message) {
  return Boolean(message.method || message.result?.thread);
}

function waitForReady(url, child) {
  const readyUrl = url.replace(/^ws:/, "http:") + "/readyz";
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const check = async () => {
      if (child.exitCode !== null) return reject(new Error("Codex App Server stopped before becoming ready"));
      try {
        const response = await fetch(readyUrl);
        if (response.ok) return resolve();
      } catch {}
      if (Date.now() - started > 10000) return reject(new Error("Timed out waiting for Codex App Server"));
      setTimeout(check, 50);
    };
    check();
  });
}

async function launch(args) {
  const registryDir = process.env.SIDEKICK_READER_REGISTRY_DIR;
  const pane = process.env.TMUX_PANE;
  if (!registryDir || !pane) throw new Error("Sidekick Reader launcher requires SIDEKICK_READER_REGISTRY_DIR and TMUX_PANE");

  await mkdir(registryDir, { recursive: true });
  const port = await allocatePort();
  const url = `ws://127.0.0.1:${port}`;
  const codex = process.env.SIDEKICK_READER_CODEX_BIN || "codex";
  const server = spawn(codex, ["app-server", "--listen", url], { stdio: "ignore" });
  const file = registrationPath(registryDir, pane);
  const temporary = `${file}.${process.pid}.tmp`;

  const cleanup = async () => {
    server.kill("SIGTERM");
    await rm(file, { force: true });
  };
  for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
    process.on(signal, () => cleanup().finally(() => process.exit(128)));
  }

  try {
    await waitForReady(url, server);
    await writeFile(temporary, JSON.stringify({ pane, url, pid: process.pid, serverPid: server.pid }) + "\n", "utf8");
    await rename(temporary, file);
    const tui = spawn(codex, ["--remote", url, ...args], { stdio: "inherit" });
    const code = await new Promise((resolve) => tui.once("exit", (status) => resolve(status ?? 1)));
    await cleanup();
    process.exit(code);
  } catch (error) {
    await cleanup();
    throw error;
  }
}

function observe(url) {
  const socket = new WebSocket(url);
  let nextId = 2;
  let threadId;

  const request = (method, params) => {
    const id = nextId++;
    socket.send(JSON.stringify({ id, method, params: params || {} }));
    return id;
  };
  const resume = (id) => {
    if (threadId || !id) return;
    threadId = id;
    request("thread/resume", { threadId: id });
  };

  socket.addEventListener("open", () => {
    socket.send(JSON.stringify({
      id: 1,
      method: "initialize",
      params: { clientInfo: { name: "sidekick-reader.nvim", version: "0.1.0" } },
    }));
  });
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id === 1) {
      socket.send(JSON.stringify({ method: "initialized", params: {} }));
      request("thread/list", { limit: 20 });
    } else if (message.result?.data) {
      const loaded = message.result.data.filter((thread) => thread.status?.type !== "notLoaded");
      if (loaded.length === 1) resume(loaded[0].id);
    } else if (message.method === "thread/started") {
      resume(message.params?.thread?.id);
    }
    if (shouldEmit(message)) process.stdout.write(JSON.stringify(message) + "\n");
  });
  socket.addEventListener("error", () => process.exit(1));
  socket.addEventListener("close", () => process.exit(0));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [command, ...args] = process.argv.slice(2);
  if (command === "launch") await launch(args);
  else if (command === "observe" && args[0]) observe(args[0]);
  else {
    console.error("Usage: bridge.mjs launch [codex args...] | observe <ws-url>");
    process.exit(2);
  }
}
