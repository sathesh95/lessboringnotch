# Tracker bridge

Connects the **Outsyd Task Tracker** (a claude.ai artifact) to boringNotch's **Tasks** tab.

```
Tracker page in the Claude app ──MCP (stdio)──▶ server.mjs ──HTTP 127.0.0.1:51789──▶ boringNotch
```

- The tracker page (owner only, inside the Claude desktop app) calls `push_snapshot` with your open tasks and the board list, and polls `get_changes` every 5 seconds for edits made in the notch. It applies them to the tracker's database and acknowledges them on the next push.
- boringNotch reads and edits tasks through the localhost API. Edits show in the notch straight away and reach the tracker on the next poll.
- State (last snapshot and unsynced notch edits) is kept in `~/Library/Application Support/TrackerBridge/state.json`, so nothing is lost if the bridge restarts.

## Setup

Registered once as a user-level MCP server, which the Claude app starts for you:

```bash
claude mcp add --scope user tracker_bridge -- /usr/local/bin/node /Users/nithin/Downloads/boringnotch/tools/tracker-bridge/server.mjs
```

The tracker page declares it as `host:tracker_bridge`. Sync runs while the tracker is open in the Claude app. The first time, the app may ask you to allow the page to use the bridge.

## Localhost API

Every request needs the header `x-tracker-bridge: 1`. Requests that carry an `Origin` header (i.e. from web pages) are refused.

| Method | Path | Body | Result |
| --- | --- | --- | --- |
| GET | `/v1/health` | | `{ok, version}` |
| GET | `/v1/tasks` | | `{connected, syncedAt, me, boards, statuses, priorities, tasks, pendingChanges}` |
| POST | `/v1/tasks` | `{title, board?, status?, priority?, due?}` | the new task |
| PATCH | `/v1/tasks/:id` | any of `title, status, priority, due, board` | the updated task |
| DELETE | `/v1/tasks/:id` | | `{ok: true}` |

`status` is one of `not_started, research, working, review, paused, stuck, complete`. `priority` is `critical, high, medium, low` or `""`. `due` is `YYYY-MM-DD` or `""`. `connected` is true when the tracker synced in the last two minutes.

```bash
curl -s -H 'x-tracker-bridge: 1' http://127.0.0.1:51789/v1/tasks
```

## Limits

- Only the tracker's owner can sync, and only from the Claude desktop app (host MCP servers are owner-only and app-only).
- The bridge runs while the Claude app is running. With several Claude sessions open, the first copy serves the port and the others forward to it; if it exits, the next call takes over.
- The notch shows tasks assigned to you that aren't complete.
