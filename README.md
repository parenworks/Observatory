# Fluxion Observatory

**A live operations dashboard that monitors itself — built with [Fluxion](https://github.com/parenworks/Fluxion).**

Author: Glenn Thompson

## What is this?

Fluxion Observatory is a locally runnable operations control dashboard that demonstrates every major Fluxion capability — reactive cells, computed cells, bidirectional propagators, glitch-free transactions, server push, DOM morphing, CLOS components, `data-*` actions, sessions, validation, and routing — with zero application JavaScript.

The dashboard monitors the running Fluxion application and the Lisp image behind it. Fluxion is monitoring Fluxion.

> A Common Lisp reactive control panel where the server owns the world, Lattice computes the state, and the browser just reflects it.

## How it works

Observatory is a single-page application where **all state lives on the server** in Common Lisp. There is no client-side state and no application JavaScript.

### Architecture

```text
┌─────────────────────────────────────────────────┐
│                   Browser                       │
│  EventSource(/sse) ◄── SSE patches ──┐         │
│  DOM morphing applies patches        │         │
│  data-* attrs ──► POST /action/...   │         │
└──────────────────────────────────────┼─────────┘
                                       │
┌──────────────────────────────────────┼─────────┐
│               Fluxion Server         │         │
│                                      │         │
│  ┌──────────┐    ┌────────────┐      │         │
│  │Simulation│───►│World State │      │         │
│  │  Thread   │    │(CLOS objs) │      │         │
│  │ tick/2s   │    └─────┬──────┘      │         │
│  └──────────┘          │             │         │
│                        ▼             │         │
│  ┌─────────────────────────────┐     │         │
│  │   CLOS Components (×7)      │     │         │
│  │   render → HTML strings     ├─────┘         │
│  └──────────┬──────────────────┘               │
│             │                                   │
│  ┌──────────▼──────────────────┐               │
│  │  Lattice (Cells layer)      │               │
│  │  cells, computed, propagators│               │
│  └─────────────────────────────┘               │
└─────────────────────────────────────────────────┘
```

1. **Simulation thread** — A background thread ticks every 2 seconds, mutating a shared `world` object (service statuses, CPU/memory metrics, queue depths). This is plain CLOS — no framework magic.

2. **Components** — Each dashboard panel is a CLOS class inheriting from `fluxion.components:component`. Components implement a `render` method that reads from the world and returns an HTML string. Fluxion manages component identity, dirty tracking, and patch generation.

3. **SSE push** — After each tick, Observatory iterates every session and calls `push-component-patch` for each component. Fluxion diffs the new HTML against the cached version, and if it changed, sends a `patch-elements` SSE event. The browser's Fluxion client runtime morphs the DOM in place — no page reload, no focus loss.

4. **Actions** — Buttons and inputs use `data-on-click`, `data-on-change`, and `data-on-input` attributes. Clicks POST to `/action/{component-id}/{action-name}`, which Fluxion routes to the matching `defaction` method on the component. The action mutates state and returns patch events.

5. **Lattice** — The Capacity Planner uses Fluxion's reactive cell layer directly. Editable fields are backed by `make-cell`, derived values by `make-computed`. Changing any input recomputes dependents automatically. The Transaction Demo wraps multiple cell writes in `with-transaction` so the UI sees one atomic update.

6. **Sessions** — Each browser gets its own component instances (created by registered factories). Alert thresholds are per-session, so two browsers can have different warning levels. Fluxion manages session cookies, CSRF tokens, and idle expiry.

## Dashboard Panels

### 1. System Status Header

Overall status, health score, active alert count, SSE connection indicator, and live server clock. The overall status is **derived** from lower-level service states and resource metrics — not manually set.

### 2. Service Monitor

A table of simulated services (API Gateway, Worker Pool, Database, SSE Broker, Report Renderer) with live status, latency, and error rates updated by the background tick. Action buttons trigger restart sequences that flow through `:restarting` → `:healthy` with visible UI patching.

### 3. Resource Metrics

HTML/CSS progress bars for CPU load, memory usage, queue depth, open SSE connections, and request rate. Each metric is read from the world state. Thresholds drive colour changes (green → yellow → red) via pure functions.

### 4. Capacity Planner

Bidirectional propagators connect requests/sec, worker count, requests per worker, target CPU, and estimated queue delay. Edit any field and the others adjust. This is the Lattice showcase — `make-cell` for inputs, `make-computed` for derived values.

### 5. Alert Threshold Settings

Server-side form with live validation. Change a threshold and alerts update immediately via the next tick. DOM morphing preserves cursor position and focus while the rest of the page updates around it.

### 6. Activity Feed

A scrolling event log. Service state changes, threshold edits, restarts, and deployments all append entries. Updated every tick via SSE patch.

### 7. Transaction Demo

A "Simulate Deployment" button that spikes CPU, queue depth, and degrades all services in a single `with-transaction`. The dashboard shows only the final consistent state — never intermediate glitches.

## Fluxion Features Demonstrated

| Fluxion Feature | Where in Observatory |
| --- | --- |
| Server-side state | All service/metric/alert state lives in CL |
| SSE push | Background tick pushes patches to all sessions |
| CLOS components | Each panel is a `fluxion.components:component` subclass |
| `data-*` actions | Buttons and inputs trigger server-side `defaction` methods |
| DOM morphing | Tables, bars, and badges update without losing focus |
| Reactive cells | Capacity Planner inputs backed by `make-cell` |
| Computed cells | Per-worker rate, recommended workers, queue delay |
| Transactions | Deployment demo wraps multi-cell writes in `with-transaction` |
| Sessions | Each browser gets its own thresholds and component instances |
| Validation | Threshold form uses server-side range validation |

## Quick Start

### From the REPL

```lisp
(ql:quickload :observatory)
(observatory:start :port 5222)
;; Open http://localhost:5222
```

### Standalone binary

```sh
make clean && make   # builds ./observatory via SBCL
./observatory        # listens on $PORT or 5222
```

### Development mode (no binary)

```sh
make run-dev         # loads and starts in SBCL, port 5222
```

## Server Backend

Observatory runs on either **Hunchentoot** (default) or **Woo**:

```lisp
(observatory:start :port 5222 :server :hunchentoot)  ; thread-per-connection, no native deps
(observatory:start :port 5222 :server :woo)           ; async via libev, higher concurrency
```

Both backends support SSE streaming. Hunchentoot blocks one thread per SSE connection; Woo uses its async event loop. For local development either works fine. For higher connection counts, prefer Woo (requires `libev` installed on the system).

The standalone binary defaults to Hunchentoot. Override with the `PORT` environment variable:

```sh
PORT=8080 ./observatory
```

## Dependencies

- [Fluxion](https://github.com/parenworks/Fluxion) — the reactive web framework this app showcases
- SBCL (tested), should work on CCL and ECL
- Woo backend requires `libev` (`libev-dev` on Debian/Ubuntu, `libev` on Arch)

## Licence

MIT
