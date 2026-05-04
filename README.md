# Fluxion Observatory

**A live operations dashboard that monitors itself — built with [Fluxion](https://github.com/parenworks/Fluxion).**

Author: Glenn Thompson

## What is this?

Fluxion Observatory is a locally runnable operations control dashboard that demonstrates every major Fluxion capability: reactive cells, computed cells, bidirectional propagators, glitch-free transactions, server push, DOM morphing, CLOS components, `data-*` actions, sessions, validation, and routing — with zero application JavaScript.

The dashboard monitors the running Fluxion application and the Lisp image behind it. Fluxion is monitoring Fluxion.

> A Common Lisp reactive control panel where the server owns the world, Lattice computes the state, and the browser just reflects it.

## Dashboard Panels

### 1. System Status Header

Overall status, health score, active alert count, SSE connection indicator, and live server clock. The overall status is derived from lower-level cells — not manually set.

### 2. Service Monitor

A table of simulated services (API Gateway, Worker Pool, Database, SSE Broker, Report Renderer) with live status, latency, and error rates updated by a background thread. Action buttons trigger restart sequences that flow through multiple states with visible UI patching.

### 3. Resource Metrics

HTML/CSS progress bars for CPU load, memory usage, queue depth, open SSE connections, and request rate. Each metric is a cell. Derived cells compute status levels (healthy / warning / critical).

### 4. Capacity Planner

Bidirectional propagators connect requests/sec, worker count, requests per worker, target CPU, and estimated queue delay. Edit any field and the others adjust. This is the Lattice showcase.

### 5. Alert Threshold Settings

Server-side form with live validation. Change a threshold and alerts update immediately. DOM morphing preserves cursor position while typing.

### 6. Activity Feed

A scrolling event feed using SSE append events. Service state changes, threshold edits, restarts, and connections all appear here in real time.

### 7. Transaction Demo

A "Simulate Deployment" button that updates multiple source cells in a single `with-transaction`. The dashboard shows only the final consistent state — never intermediate glitches.

## Fluxion Features Demonstrated

| Fluxion Feature | Demo Behaviour |
| --- | --- |
| Server-side state | All service/job/alert state lives in CL |
| SSE push | Services change status without page refresh |
| CLOS components | Each panel is a component |
| `data-*` actions | Buttons and forms trigger server actions |
| DOM morphing | Tables and cards update without losing focus |
| Lattice cells | Raw state held in cells |
| Computed cells | Health score, alert count, overall status |
| Propagators | Capacity planner bidirectional constraints |
| Transactions | Batch deployment updates are glitch-free |
| Sessions | Each browser gets its own filters/views |
| Validation | Settings form with server-side validation |

## Quick Start

```lisp
(ql:quickload :observatory)
(observatory:start :port 5222)
;; Open http://localhost:5222
```

## Dependencies

- [Fluxion](https://github.com/parenworks/Fluxion) — the framework this app showcases
- SBCL (tested), should work on CCL and ECL

## Licence

MIT
