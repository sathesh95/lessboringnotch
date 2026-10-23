#!/usr/bin/env node
//
// Tracker bridge
//
// Connects the "Outsyd Task Tracker" claude.ai artifact to boringNotch.
//
//   tracker page (in the Claude app) --MCP stdio--> this process --HTTP 127.0.0.1--> boringNotch
//
// The tracker page pushes a snapshot of the owner's open tasks with `push_snapshot`
// and collects edits made in the notch with `get_changes`. boringNotch reads and
// edits tasks through the localhost API below. No dependencies: Node 18+.
//
// Several Claude sessions may each start a copy of this server. The first one to
// bind the port owns the state; the others forward their tool calls to it.
//

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";

const PORT = Number(process.env.TRACKER_BRIDGE_PORT || 51789);
const HOST = "127.0.0.1";
const STATE_DIR = process.env.TRACKER_BRIDGE_STATE_DIR || path.join(os.homedir(), "Library", "Application Support", "TrackerBridge");
const STATE_FILE = path.join(STATE_DIR, "state.json");
const HEADER = "x-tracker-bridge";
const VERSION = "1.0.0";

const STATUSES = [
  { key: "not_started", label: "Not started" },
  { key: "research", label: "Research" },
  { key: "working", label: "Working on it" },
  { key: "review", label: "Review" },
  { key: "paused", label: "Paused" },
  { key: "stuck", label: "Stuck" },
  { key: "complete", label: "Complete" },
];
const PRIORITIES = [
  { key: "critical", label: "Critical" },
  { key: "high", label: "High" },
  { key: "medium", label: "Medium" },
  { key: "low", label: "Low" },
];
const STATUS_KEYS = new Set(STATUSES.map(s => s.key));
const PRIORITY_KEYS = new Set(["", ...PRIORITIES.map(p => p.key)]);
const EDITABLE = ["title", "status", "priority", "due", "board"];

const log = (...a) => process.stderr.write(`[tracker-bridge] ${a.join(" ")}\n`);

/* ---------------- state (owner role only) ---------------- */

let state = { snapshot: { me: null, boards: [], tasks: [], syncedAt: 0 }, changes: [] };

function loadState() {
  try {
    const s = JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
    if (s && s.snapshot && Array.isArray(s.changes)) state = s;
  } catch {}
}
function saveState() {
  try {
    fs.mkdirSync(STATE_DIR, { recursive: true });
    const tmp = STATE_FILE + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(state));
    fs.renameSync(tmp, STATE_FILE);
  } catch (e) {
    log("could not save state:", e.message);
  }
}

const newId = prefix => prefix + crypto.randomBytes(12).toString("base64url").replace(/[^A-Za-z0-9]/g, "").slice(0, 16);

function cleanTask(t) {
  return {
    id: String(t.id),
    title: String(t.title ?? ""),
    board: String(t.board ?? ""),
    status: STATUS_KEYS.has(t.status) ? t.status : "not_started",
    priority: PRIORITY_KEYS.has(t.priority) ? t.priority : "",
    due: typeof t.due === "string" && /^\d{4}-\d{2}-\d{2}$/.test(t.due) ? t.due : "",
  };
}

// Validates notch edits. Returns [fields, error].
function validateFields(input, { requireTitle }) {
  const out = {};
  if (!input || typeof input !== "object") return [null, "Body must be a JSON object."];
  for (const k of EDITABLE) {
    if (!(k in input)) continue;
    const v = input[k];
    if (k === "title") {
      if (typeof v !== "string" || !v.trim() || v.length > 300) return [null, "title must be 1-300 characters."];
      out.title = v.trim();
    } else if (k === "status") {
      if (!STATUS_KEYS.has(v)) return [null, `status must be one of: ${[...STATUS_KEYS].join(", ")}.`];
      out.status = v;
    } else if (k === "priority") {
      if (!PRIORITY_KEYS.has(v)) return [null, "priority must be critical, high, medium, low or empty."];
      out.priority = v;
    } else if (k === "due") {
      if (v !== "" && !(typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v))) return [null, "due must be YYYY-MM-DD or empty."];
      out.due = v;
    } else if (k === "board") {
      if (!state.snapshot.boards.some(b => b.id === v)) return [null, "board must be the id of an existing board."];
      out.board = v;
    }
  }
  if (requireTitle && !out.title) return [null, "title is required."];
  return [out, null];
}

// The snapshot with the notch's not-yet-synced edits applied on top.
function view() {
  const tasks = state.snapshot.tasks.map(t => ({ ...t, pending: false }));
  for (const c of state.changes) {
    const i = tasks.findIndex(t => t.id === c.id);
    if (c.op === "create" && i < 0) tasks.push({ ...cleanTask({ id: c.id, ...c.fields }), pending: true });
    else if (c.op === "update" && i >= 0) tasks[i] = { ...tasks[i], ...c.fields, pending: true };
    else if (c.op === "delete" && i >= 0) tasks.splice(i, 1);
  }
  const syncedAt = state.snapshot.syncedAt || 0;
  return {
    connected: Date.now() - syncedAt < 2 * 60 * 1000,
    syncedAt,
    me: state.snapshot.me,
    boards: state.snapshot.boards,
    statuses: STATUSES,
    priorities: PRIORITIES,
    tasks,
    pendingChanges: state.changes.length,
  };
}

function queueChange(change) {
  // Fold edits into a pending create or update for the same task, so the queue stays short.
  const prev = state.changes.find(c => c.id === change.id && (c.op === "create" || c.op === "update"));
  if (change.op === "update" && prev) {
    prev.fields = { ...prev.fields, ...change.fields };
    prev.at = Date.now();
    prev.cid = newId("c"); // a new cid so an older ack can't drop the merged edit
  } else if (change.op === "delete" && prev && prev.op === "create") {
    state.changes = state.changes.filter(c => c !== prev);
  } else {
    if (change.op === "delete") state.changes = state.changes.filter(c => c.id !== change.id);
    state.changes.push({ cid: newId("c"), at: Date.now(), ...change });
  }
  saveState();
}

/* ---------------- operations shared by MCP and HTTP ---------------- */

function opPushSnapshot(input) {
  const boards = Array.isArray(input?.boards)
    ? input.boards.map(b => ({ id: String(b.id), name: String(b.name ?? ""), color: Number.isInteger(b.color) ? b.color : 0 }))
    : [];
  const tasks = Array.isArray(input?.tasks) ? input.tasks.map(cleanTask) : [];
  const acked = new Set(Array.isArray(input?.acked) ? input.acked.map(String) : []);
  state.snapshot = { me: input?.me ?? null, boards, tasks, syncedAt: Date.now() };
  state.changes = state.changes.filter(c => !acked.has(c.cid));
  saveState();
  return { ok: true, tasks: tasks.length, pendingChanges: state.changes.length };
}

function opGetChanges() {
  return { changes: state.changes };
}

/* ---------------- HTTP server ---------------- */

function send(res, code, body) {
  res.writeHead(code, { "content-type": "application/json", "cache-control": "no-store" });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", chunk => {
      data += chunk;
      if (data.length > 2_000_000) { reject(new Error("too large")); req.destroy(); }
    });
    req.on("end", () => {
      if (!data) return resolve({});
      try { resolve(JSON.parse(data)); } catch { reject(new Error("bad json")); }
    });
    req.on("error", reject);
  });
}

async function handle(req, res) {
  // Browsers always send Origin on cross-site requests and can't add our header without a
  // preflight we never answer, so web pages can't drive this API.
  if (req.headers.origin || req.headers[HEADER] !== "1") {
    return send(res, 403, { error: `Send the header "${HEADER}: 1" from a local app.` });
  }
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  const parts = url.pathname.split("/").filter(Boolean);
  let body = {};
  if (req.method === "POST" || req.method === "PATCH") {
    try { body = await readBody(req); } catch { return send(res, 400, { error: "Body must be valid JSON." }); }
  }

  // Internal routes used by secondary bridge processes.
  if (parts[0] === "internal") {
    if (req.method === "POST" && parts[1] === "push") return send(res, 200, opPushSnapshot(body));
    if (req.method === "GET" && parts[1] === "changes") return send(res, 200, opGetChanges());
    return send(res, 404, { error: "Not found." });
  }

  if (parts[0] !== "v1") return send(res, 404, { error: "Not found. Try GET /v1/tasks." });

  if (parts[1] === "health" && req.method === "GET") return send(res, 200, { ok: true, version: VERSION });

  if (parts[1] === "tasks" && parts.length === 2) {
    if (req.method === "GET") return send(res, 200, view());
    if (req.method === "POST") {
      const [fields, err] = validateFields(body, { requireTitle: true });
      if (err) return send(res, 400, { error: err });
      if (!fields.board) {
        if (!state.snapshot.boards.length) return send(res, 409, { error: "No boards yet. Create one in the tracker first." });
        fields.board = state.snapshot.boards[0].id;
      }
      const id = newId("n");
      queueChange({ op: "create", id, fields: { status: "not_started", priority: "", due: "", ...fields } });
      return send(res, 201, view().tasks.find(t => t.id === id));
    }
  }

  if (parts[1] === "tasks" && parts.length === 3) {
    const id = parts[2];
    const known = view().tasks.some(t => t.id === id);
    if (!known) return send(res, 404, { error: "No open task of yours has that id." });
    if (req.method === "PATCH") {
      const [fields, err] = validateFields(body, { requireTitle: false });
      if (err) return send(res, 400, { error: err });
      if (!Object.keys(fields).length) return send(res, 400, { error: `Send at least one of: ${EDITABLE.join(", ")}.` });
      queueChange({ op: "update", id, fields });
      return send(res, 200, view().tasks.find(t => t.id === id));
    }
    if (req.method === "DELETE") {
      queueChange({ op: "delete", id });
      return send(res, 200, { ok: true });
    }
  }

  return send(res, 405, { error: "Method not allowed." });
}

/* ---------------- owner / proxy role ---------------- */

let role = null; // "owner" | "proxy"

function tryListen() {
  return new Promise(resolve => {
    const server = http.createServer((req, res) => {
      handle(req, res).catch(e => send(res, 500, { error: e.message }));
    });
    server.once("error", err => resolve(err.code === "EADDRINUSE" ? "proxy" : (log("listen failed:", err.message), "proxy")));
    server.listen(PORT, HOST, () => {
      server.unref?.();
      loadState();
      log(`serving http://${HOST}:${PORT}/v1/tasks`);
      resolve("owner");
    });
  });
}

async function forward(method, route, body) {
  const res = await fetch(`http://${HOST}:${PORT}${route}`, {
    method,
    headers: { "content-type": "application/json", [HEADER]: "1" },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`bridge owner answered ${res.status}`);
  return res.json();
}

async function run(local, method, route, body) {
  if (!role) role = await tryListen();
  if (role === "owner") return local();
  try {
    return await forward(method, route, body);
  } catch {
    // The owning process went away: take over.
    role = await tryListen();
    if (role === "owner") return local();
    return forward(method, route, body);
  }
}

/* ---------------- MCP over stdio ---------------- */

const TOOLS = [
  {
    name: "push_snapshot",
    description:
      "Replace the bridge's copy of the tracker owner's open tasks and the board list, and acknowledge notch edits the tracker has applied. Called by the Outsyd Task Tracker page.",
    inputSchema: {
      type: "object",
      properties: {
        me: { type: ["string", "null"], description: "The tracker owner's user id." },
        boards: {
          type: "array",
          items: {
            type: "object",
            properties: { id: { type: "string" }, name: { type: "string" }, color: { type: "integer" } },
            required: ["id", "name"],
          },
        },
        tasks: {
          type: "array",
          items: {
            type: "object",
            properties: {
              id: { type: "string" }, title: { type: "string" }, board: { type: "string" },
              status: { type: "string" }, priority: { type: "string" }, due: { type: "string" },
            },
            required: ["id", "title"],
          },
        },
        acked: { type: "array", items: { type: "string" }, description: "cids of changes from get_changes that were applied." },
      },
      required: ["boards", "tasks"],
    },
    annotations: { title: "Push tracker tasks to the notch", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  {
    name: "get_changes",
    description:
      "List edits made in boringNotch (create, update, delete) that the tracker has not applied yet. Each has a cid to acknowledge through push_snapshot.",
    inputSchema: { type: "object", properties: {} },
    annotations: { title: "Read notch edits", readOnlyHint: true, openWorldHint: false },
  },
];

function reply(id, result) {
  process.stdout.write(JSON.stringify({ jsonrpc: "2.0", id, result }) + "\n");
}
function replyError(id, code, message) {
  process.stdout.write(JSON.stringify({ jsonrpc: "2.0", id, error: { code, message } }) + "\n");
}

async function onMessage(msg) {
  const { id, method, params } = msg;
  if (method === "initialize") {
    return reply(id, {
      protocolVersion: params?.protocolVersion || "2025-06-18",
      capabilities: { tools: {} },
      serverInfo: { name: "tracker_bridge", version: VERSION },
    });
  }
  if (method === "ping") return reply(id, {});
  if (method === "tools/list") return reply(id, { tools: TOOLS });
  if (method === "tools/call") {
    const name = params?.name;
    const args = params?.arguments || {};
    try {
      let out;
      if (name === "push_snapshot") out = await run(() => opPushSnapshot(args), "POST", "/internal/push", args);
      else if (name === "get_changes") out = await run(() => opGetChanges(), "GET", "/internal/changes");
      else return replyError(id, -32602, `Unknown tool: ${name}`);
      return reply(id, { content: [{ type: "text", text: JSON.stringify(out) }], structuredContent: out });
    } catch (e) {
      return reply(id, { content: [{ type: "text", text: `Bridge error: ${e.message}` }], isError: true });
    }
  }
  if (id !== undefined && id !== null) replyError(id, -32601, `Method not found: ${method}`);
}

let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => {
  buffer += chunk;
  let nl;
  while ((nl = buffer.indexOf("\n")) >= 0) {
    const line = buffer.slice(0, nl).trim();
    buffer = buffer.slice(nl + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { log("ignoring non-JSON input"); continue; }
    onMessage(msg).catch(e => log("handler error:", e.message));
  }
});
process.stdin.on("end", () => process.exit(0));

// Start serving straight away so boringNotch can connect even before the tracker syncs.
run(() => null, "GET", "/v1/health").catch(() => {});
