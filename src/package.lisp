;;;; -*- encoding:utf-8 -*-
;;;; Fluxion Observatory - Package definitions

(defpackage #:observatory.simulation
  (:use #:cl)
  (:local-nicknames (#:bt #:bordeaux-threads))
  (:export
   ;; World
   #:*world*
   #:world
   #:make-world
   #:world-services
   #:world-cpu
   #:world-memory
   #:world-queue-depth
   #:world-request-rate
   #:world-sse-connections
   #:world-activity-log
   #:world-lock
   ;; Services
   #:service
   #:service-name
   #:service-display-name
   #:service-status
   #:service-latency
   #:service-error-rate
   #:service-restart-at
   ;; Alert thresholds (per-session)
   #:alert-thresholds
   #:make-default-thresholds
   #:make-alert-thresholds
   #:alert-thresholds-cpu-warning
   #:alert-thresholds-cpu-critical
   #:alert-thresholds-queue-warning
   #:alert-thresholds-queue-critical
   #:alert-thresholds-latency-warning
   #:alert-thresholds-latency-critical
   ;; Derived state
   #:compute-health-score
   #:compute-overall-status
   #:compute-active-alerts
   #:compute-resource-status
   ;; Simulation control
   #:init-world
   #:tick-world
   #:restart-service
   #:simulate-deployment
   #:add-activity
   #:format-time-now))

(defpackage #:observatory.components
  (:use #:cl)
  (:export
   ;; Components
   #:status-header
   #:service-table
   #:resource-cards
   #:capacity-planner
   #:alert-settings
   #:activity-feed
   #:transaction-demo
   ;; Shared threshold accessors
   #:header-thresholds
   #:settings-thresholds
   ;; Capacity planner accessors
   #:planner-rps-cell
   #:planner-workers-cell
   #:planner-per-worker-cell
   #:planner-target-cpu-cell
   #:planner-rec-workers-cell
   #:planner-delay-cell))

(defpackage #:observatory.actions
  (:use #:cl))

(defpackage #:observatory.pages
  (:use #:cl)
  (:export #:render-dashboard-page))

(defpackage #:observatory
  (:use #:cl)
  (:export #:start
           #:stop
           #:*app*))
