;;;; -*- encoding:utf-8 -*-
;;;; Fluxion Observatory - Page rendering
;;;;
;;;; Assembles all components into the full dashboard page.

(in-package #:observatory.pages)

;;; -------------------------------------------------------
;;; Dashboard CSS (Catppuccin Mocha theme)
;;; -------------------------------------------------------

(defun dashboard-css ()
  "Return the dashboard stylesheet as a string."
  "
:root {
  --base: #1e1e2e; --mantle: #181825; --crust: #11111b;
  --surface0: #313244; --surface1: #45475a; --surface2: #585b70;
  --text: #cdd6f4; --subtext0: #a6adc8; --subtext1: #bac2de;
  --green: #a6e3a1; --yellow: #f9e2af; --red: #f38ba8;
  --blue: #89b4fa; --mauve: #cba6f7; --teal: #94e2d5;
  --peach: #fab387;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: 'Inter', system-ui, -apple-system, sans-serif;
  background: var(--base); color: var(--text);
  line-height: 1.5; padding: 1rem;
}

/* Layout */
.dashboard { max-width: 1200px; margin: 0 auto; display: flex; flex-direction: column; gap: 1rem; }
.dashboard-row { display: flex; gap: 1rem; }
.dashboard-row > * { flex: 1; min-width: 0; }
.dashboard-row.two-thirds > :first-child { flex: 2; }
.dashboard-row.two-thirds > :last-child { flex: 1; }

/* Status Header */
.status-header {
  background: var(--surface0); border: 1px solid var(--surface1); border-radius: 8px;
  padding: 1rem 1.5rem; display: flex; align-items: center; justify-content: space-between;
  flex-wrap: wrap; gap: 0.75rem;
}
.page-title { font-size: 1.6rem; color: var(--blue); font-weight: 700; margin-bottom: 0.75rem; }
.header-title h1 { font-size: 1.3rem; color: var(--blue); white-space: nowrap; }
.header-metrics { display: flex; gap: 1.25rem; flex-wrap: wrap; }
.header-badge { text-align: center; min-width: 5rem; }
.badge-label { display: block; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--subtext0); }
.badge-value { font-size: 1.1rem; font-weight: 700; }
.clock-value { font-family: 'JetBrains Mono', monospace; }

/* Panels */
.panel {
  background: var(--surface0); border: 1px solid var(--surface1); border-radius: 8px;
  padding: 1.25rem;
}
.panel h2 { font-size: 1rem; color: var(--subtext1); margin-bottom: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; font-weight: 600; }
.panel-subtitle { font-size: 0.8rem; color: var(--subtext0); margin-top: -0.5rem; margin-bottom: 0.75rem; }

/* Status colours */
.text-healthy  { color: var(--green); }
.text-warning  { color: var(--yellow); }
.text-critical { color: var(--red); }
.text-muted    { color: var(--surface2); }
.status-healthy    { color: var(--green); }
.status-degraded   { color: var(--yellow); }
.status-warning    { color: var(--yellow); }
.status-critical   { color: var(--red); }
.status-down       { color: var(--red); }
.status-restarting { color: var(--mauve); }

/* Status badge background variants */
.header-badge.status-healthy    { background: rgba(166,227,161,0.1); border-radius: 6px; padding: 0.3rem 0.6rem; }
.header-badge.status-degraded   { background: rgba(249,226,175,0.1); border-radius: 6px; padding: 0.3rem 0.6rem; }
.header-badge.status-critical   { background: rgba(243,139,168,0.1); border-radius: 6px; padding: 0.3rem 0.6rem; }

/* Service table */
.service-table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
.service-table th { text-align: left; padding: 0.4rem 0.6rem; color: var(--subtext0); border-bottom: 1px solid var(--surface1); font-weight: 500; }
.service-table td { padding: 0.5rem 0.6rem; border-bottom: 1px solid var(--surface1); }
.service-table tr:last-child td { border-bottom: none; }
.svc-name { font-weight: 600; }
.status-dot::before { content: ''; display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 0.4rem; background: currentColor; }

/* Buttons */
.btn {
  padding: 0.3rem 0.7rem; border: 1px solid var(--surface2); border-radius: 4px;
  background: var(--surface1); color: var(--text); cursor: pointer; font-size: 0.8rem;
  transition: background 0.15s;
}
.btn:hover { background: var(--surface2); }
.btn-disabled { opacity: 0.5; cursor: not-allowed; }
.btn-action { border-color: var(--blue); color: var(--blue); }
.btn-action:hover { background: rgba(137,180,250,0.15); }
.btn-deploy {
  padding: 0.6rem 1.5rem; font-size: 1rem; font-weight: 600;
  border: 2px solid var(--peach); color: var(--peach); background: transparent;
  border-radius: 6px; cursor: pointer; transition: all 0.2s;
}
.btn-deploy:hover { background: rgba(250,179,135,0.15); }

/* Metric cards / progress bars */
.metric-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
.metric-card { background: var(--mantle); border-radius: 6px; padding: 0.6rem 0.8rem; }
.metric-header { display: flex; justify-content: space-between; margin-bottom: 0.3rem; }
.metric-label { font-size: 0.8rem; color: var(--subtext0); }
.metric-value { font-size: 0.8rem; font-weight: 600; font-family: 'JetBrains Mono', monospace; }
.metric-bar { height: 12px; background: var(--surface1); border-radius: 4px; overflow: hidden; }
.metric-fill { height: 100%; border-radius: 4px; transition: width 0.3s ease; min-width: 2px; }
.bar-healthy  { background: var(--green); }
.bar-warning  { background: var(--yellow); }
.bar-critical { background: var(--red); }

/* Capacity planner */
.planner-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 0.75rem; }
.planner-field label { display: block; font-size: 0.8rem; color: var(--subtext0); margin-bottom: 0.2rem; }
.planner-input {
  width: 100%; padding: 0.4rem 0.6rem; font-size: 1rem;
  background: var(--mantle); border: 1px solid var(--surface1); border-radius: 4px;
  color: var(--text); font-family: 'JetBrains Mono', monospace;
}
.planner-input:focus { outline: none; border-color: var(--blue); }
.planner-derived { background: var(--mantle); border-radius: 6px; padding: 0.6rem 0.8rem; }
.planner-value { font-size: 1.2rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--teal); }

/* Alert thresholds */
.threshold-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
.threshold-field label { display: block; font-size: 0.8rem; color: var(--subtext0); margin-bottom: 0.2rem; }
.threshold-input {
  width: 100%; padding: 0.4rem 0.6rem; font-size: 0.95rem;
  background: var(--mantle); border: 1px solid var(--surface1); border-radius: 4px;
  color: var(--text); font-family: 'JetBrains Mono', monospace;
}
.threshold-input:focus { outline: none; border-color: var(--yellow); }

/* Activity feed */
.feed-list { max-height: 260px; overflow-y: auto; }
.feed-entry { display: flex; gap: 0.6rem; padding: 0.3rem 0; font-size: 0.8rem; border-bottom: 1px solid var(--surface1); }
.feed-entry:last-child { border-bottom: none; }
.feed-time { font-family: 'JetBrains Mono', monospace; color: var(--subtext0); white-space: nowrap; }
.feed-msg { color: var(--subtext1); }

/* Transaction panel */
.transaction-panel { text-align: center; }
.transaction-panel h2 { text-align: left; }
.transaction-panel .panel-subtitle { text-align: left; }

/* Responsive */
@media (max-width: 800px) {
  .dashboard-row { flex-direction: column; }
  .planner-grid { grid-template-columns: 1fr 1fr; }
  .metric-grid { grid-template-columns: 1fr; }
}
")

;;; -------------------------------------------------------
;;; Page assembly
;;; -------------------------------------------------------

(defun render-dashboard-page (&key status-header service-table resource-cards
                                   capacity-planner alert-settings activity-feed
                                   transaction-demo csrf-token)
  "Render the full Observatory dashboard page."
  (fluxion.render:render-page
   :title "Fluxion Observatory"
   :csrf-token csrf-token
   :head-html (format nil "<style>~A</style>
<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">
<link href=\"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;700&display=swap\" rel=\"stylesheet\">"
                      (dashboard-css))
   :body-html
   (concatenate 'string
    "<div class=\"dashboard\">"
    "<h1 class=\"page-title\">Fluxion Observatory</h1>"
    ;; Row 1: Status header (full width)
    (fluxion.components:render status-header)
    ;; Row 2: Service table (2/3) + Resources (1/3)
    "<div class=\"dashboard-row two-thirds\">"
    (fluxion.components:render service-table)
    (fluxion.components:render resource-cards)
    "</div>"
    ;; Row 3: Capacity planner (2/3) + Alert thresholds (1/3)
    "<div class=\"dashboard-row two-thirds\">"
    (fluxion.components:render capacity-planner)
    (fluxion.components:render alert-settings)
    "</div>"
    ;; Row 4: Activity feed (2/3) + Transaction demo (1/3)
    "<div class=\"dashboard-row two-thirds\">"
    (fluxion.components:render activity-feed)
    (fluxion.components:render transaction-demo)
    "</div>"
    "</div>")))
