;;;; -*- encoding:utf-8 -*-
;;;; Fluxion Observatory - CLOS components
;;;;
;;;; Each dashboard panel is a Fluxion component (CLOS class + render method).
;;;; Components read from the global simulation world and render to HTML.
;;;; The framework handles patching, morphing, and SSE transport.

(in-package #:observatory.components)

;;; -------------------------------------------------------
;;; Helpers
;;; -------------------------------------------------------

(defun status-class (status)
  "Return a CSS class for a status keyword."
  (case status
    (:healthy    "status-healthy")
    (:degraded   "status-degraded")
    (:warning    "status-warning")
    (:critical   "status-critical")
    (:down       "status-down")
    (:restarting "status-restarting")
    (t           "status-unknown")))

(defun status-label (status)
  "Return a human label for a status keyword."
  (case status
    (:healthy    "Healthy")
    (:degraded   "Degraded")
    (:warning    "Warning")
    (:critical   "Critical")
    (:down       "Down")
    (:restarting "Restarting…")
    (t           "Unknown")))

(defun progress-bar (label value max-val &key unit (warning 70) (critical 90))
  "Render an HTML progress bar string."
  (let* ((pct (if (zerop max-val) 0 (min 100 (round (* 100 value) max-val))))
         (bar-class (cond ((>= pct critical) "bar-critical")
                          ((>= pct warning)  "bar-warning")
                          (t                 "bar-healthy"))))
    (spinneret:with-html-string
      (:div :class "metric-card"
        (:div :class "metric-header"
          (:span :class "metric-label" label)
          (:span :class "metric-value"
                 (if unit
                     (format nil "~A~A" value unit)
                     (format nil "~A" value))))
        (:div :class "metric-bar"
          (:div :class (format nil "metric-fill ~A" bar-class)
                :style (format nil "width:~D%" pct)))))))

;;; -------------------------------------------------------
;;; 1. Status Header
;;; -------------------------------------------------------

(defclass status-header (fluxion.components:component)
  ((thresholds :initarg :thresholds :accessor header-thresholds
               :initform (observatory.simulation:make-default-thresholds)))
  (:default-initargs :id "status-header"))

(defmethod fluxion.components:render ((c status-header))
  (let* ((w observatory.simulation:*world*)
         (health (observatory.simulation:compute-health-score w))
         (overall (observatory.simulation:compute-overall-status w))
         (alerts (observatory.simulation:compute-active-alerts (header-thresholds c) w))
         (time-str (observatory.simulation:format-time-now)))
    (spinneret:with-html-string
      (:div :id (fluxion.components:component-id c) :class "status-header"
        (:div :class "header-title"
          (:h1 "Fluxion Observatory"))
        (:div :class "header-metrics"
          (:div :class (format nil "header-badge ~A" (status-class overall))
            (:span :class "badge-label" "Status")
            (:span :class "badge-value" (status-label overall)))
          (:div :class "header-badge"
            (:span :class "badge-label" "Health")
            (:span :class (format nil "badge-value ~A"
                                  (cond ((>= health 80) "text-healthy")
                                        ((>= health 50) "text-warning")
                                        (t "text-critical")))
                   (format nil "~D%" health)))
          (:div :class "header-badge"
            (:span :class "badge-label" "Alerts")
            (:span :class (format nil "badge-value ~A"
                                  (if (zerop (length alerts)) "text-healthy" "text-warning"))
                   (format nil "~D" (length alerts))))
          (:div :class "header-badge"
            (:span :class "badge-label" "SSE")
            (:span :class "badge-value text-healthy" "Connected"))
          (:div :class "header-badge"
            (:span :class "badge-label" "Updated")
            (:span :class "badge-value clock-value" time-str)))))))

;;; -------------------------------------------------------
;;; 2. Service Monitor Table
;;; -------------------------------------------------------

(defclass service-table (fluxion.components:component)
  ()
  (:default-initargs :id "service-table"))

(defmethod fluxion.components:render ((c service-table))
  (let ((services (observatory.simulation:world-services observatory.simulation:*world*)))
    (spinneret:with-html-string
      (:div :id (fluxion.components:component-id c) :class "panel"
        (:h2 "Service Monitor")
        (:table :class "service-table"
          (:thead
            (:tr
              (:th "Service") (:th "Status") (:th "Latency") (:th "Error Rate") (:th "Actions")))
          (:tbody
            (dolist (svc services)
              (:tr
                (:td :class "svc-name" (observatory.simulation:service-display-name svc))
                (:td (:span :class (format nil "status-dot ~A"
                                           (status-class (observatory.simulation:service-status svc)))
                            (status-label (observatory.simulation:service-status svc))))
                (:td (if (eq (observatory.simulation:service-status svc) :down)
                         (:span :class "text-muted" "—")
                         (format nil "~Dms" (observatory.simulation:service-latency svc))))
                (:td (if (eq (observatory.simulation:service-status svc) :down)
                         (:span :class "text-muted" "—")
                         (format nil "~,1F%" (observatory.simulation:service-error-rate svc))))
                (:td
                  (case (observatory.simulation:service-status svc)
                    (:restarting
                     (:button :class "btn btn-disabled" :disabled t "Restarting…"))
                    (:down
                     (:button :class "btn btn-action"
                              :data-on-click "/action/service-table/restart"
                              :data-param-service (observatory.simulation:service-name svc)
                              "Start"))
                    (t
                     (:button :class "btn btn-action"
                              :data-on-click "/action/service-table/restart"
                              :data-param-service (observatory.simulation:service-name svc)
                              "Restart"))))))))))))

;;; -------------------------------------------------------
;;; 3. Resource Metric Cards
;;; -------------------------------------------------------

(defclass resource-cards (fluxion.components:component)
  ()
  (:default-initargs :id "resource-cards"))

(defmethod fluxion.components:render ((c resource-cards))
  (let ((w observatory.simulation:*world*))
    (spinneret:with-html-string
      (:div :id (fluxion.components:component-id c) :class "panel"
        (:h2 "Resources")
        (:div :class "metric-grid"
          (:raw (progress-bar "CPU Load"
                              (observatory.simulation:world-cpu w) 100
                              :unit "%"))
          (:raw (progress-bar "Memory"
                              (observatory.simulation:world-memory w) 100
                              :unit "%"))
          (:raw (progress-bar "Queue Depth"
                              (observatory.simulation:world-queue-depth w) 200
                              :unit " jobs" :warning 25 :critical 50))
          (:raw (progress-bar "Request Rate"
                              (observatory.simulation:world-request-rate w) 500
                              :unit "/s" :warning 60 :critical 80))
          (:raw (progress-bar "SSE Connections"
                              (observatory.simulation:world-sse-connections w) 50
                              :unit "" :warning 70 :critical 90)))))))

;;; -------------------------------------------------------
;;; 4. Capacity Planner (bidirectional propagators)
;;; -------------------------------------------------------

(defclass capacity-planner (fluxion.components:component)
  ((rps-cell         :accessor planner-rps-cell)
   (workers-cell     :accessor planner-workers-cell)
   (per-worker-cell  :accessor planner-per-worker-cell)
   (target-cpu-cell  :accessor planner-target-cpu-cell)
   (rec-workers-cell :accessor planner-rec-workers-cell)
   (delay-cell       :accessor planner-delay-cell)
   ;; Propagator refs (kept to avoid GC)
   (prop-forward     :accessor planner-prop-forward)
   (prop-reverse     :accessor planner-prop-reverse)
   (prop-recommend   :accessor planner-prop-recommend)
   (prop-delay       :accessor planner-prop-delay))
  (:default-initargs :id "capacity-planner"))

(defmethod initialize-instance :after ((cp capacity-planner) &key)
  ;; Base cells (user-editable)
  (let ((rps     (fluxion.cells:make-cell 1200 :name "rps"))
        (workers (fluxion.cells:make-cell 12   :name "workers"))
        (target  (fluxion.cells:make-cell 70   :name "target-cpu")))
    (setf (planner-rps-cell cp) rps
          (planner-workers-cell cp) workers
          (planner-target-cpu-cell cp) target)
    ;; Computed: requests per worker = rps / workers
    (setf (planner-per-worker-cell cp)
          (fluxion.cells:make-computed
           (lambda ()
             (let ((w (fluxion.cells:cell-value workers)))
               (if (zerop w) 0
                   (round (fluxion.cells:cell-value rps) w))))
           :name "per-worker"))
    ;; Computed: recommended workers = ceil(rps / (100 * target / 100))
    ;; i.e. how many workers to keep each at target% utilisation
    (setf (planner-rec-workers-cell cp)
          (fluxion.cells:make-computed
           (lambda ()
             (let ((t-cpu (fluxion.cells:cell-value target))
                   (r (fluxion.cells:cell-value rps)))
               (if (zerop t-cpu) 0
                   (ceiling r (max 1 (round (* 100 (/ t-cpu 100))))))))
           :name "rec-workers"))
    ;; Computed: estimated queue delay = f(rps, workers)
    (setf (planner-delay-cell cp)
          (fluxion.cells:make-computed
           (lambda ()
             (let* ((r (fluxion.cells:cell-value rps))
                    (w (max 1 (fluxion.cells:cell-value workers)))
                    (load-factor (/ r (* w 100.0))))
               (if (<= load-factor 1.0)
                   (round (* 10 load-factor))
                   (round (* 10 load-factor load-factor)))))
           :name "est-delay"))))

(defmethod fluxion.components:render ((cp capacity-planner))
  (let ((rps     (fluxion.cells:cell-value (planner-rps-cell cp)))
        (workers (fluxion.cells:cell-value (planner-workers-cell cp)))
        (per-w   (fluxion.cells:cell-value (planner-per-worker-cell cp)))
        (target  (fluxion.cells:cell-value (planner-target-cpu-cell cp)))
        (rec-w   (fluxion.cells:cell-value (planner-rec-workers-cell cp)))
        (delay   (fluxion.cells:cell-value (planner-delay-cell cp))))
    (spinneret:with-html-string
      (:div :id (fluxion.components:component-id cp) :class "panel"
        (:h2 "Capacity Planner")
        (:p :class "panel-subtitle" "Bidirectional constraints — edit any field")
        (:div :class "planner-grid"
          (:div :class "planner-field"
            (:label "Incoming req/s")
            (:input :type "number" :value (format nil "~D" rps)
                    :data-on-input "/action/capacity-planner/set-rps"
                    :class "planner-input"))
          (:div :class "planner-field"
            (:label "Workers")
            (:input :type "number" :value (format nil "~D" workers)
                    :data-on-input "/action/capacity-planner/set-workers"
                    :class "planner-input"))
          (:div :class "planner-field planner-derived"
            (:label "Req per worker")
            (:span :class "planner-value" (format nil "~D" per-w)))
          (:div :class "planner-field"
            (:label "Target CPU %")
            (:input :type "number" :value (format nil "~D" target)
                    :data-on-input "/action/capacity-planner/set-target-cpu"
                    :class "planner-input"
                    :min "1" :max "100"))
          (:div :class "planner-field planner-derived"
            (:label "Recommended workers")
            (:span :class "planner-value" (format nil "~D" rec-w)))
          (:div :class "planner-field planner-derived"
            (:label "Est. queue delay")
            (:span :class "planner-value" (format nil "~Dms" delay))))))))

;;; -------------------------------------------------------
;;; 5. Alert Threshold Settings
;;; -------------------------------------------------------

(defclass alert-settings (fluxion.components:component)
  ((thresholds :initarg :thresholds :accessor settings-thresholds
               :initform (observatory.simulation:make-default-thresholds)))
  (:default-initargs :id "alert-settings"))

(defun threshold-field (label value action &key (min-val 0) (max-val 100) unit)
  "Render a single threshold input."
  (spinneret:with-html-string
    (:div :class "threshold-field"
      (:label (if unit (format nil "~A (~A)" label unit) label))
      (:input :type "number"
              :value (format nil "~D" value)
              :data-on-change action
              :class "threshold-input"
              :min (format nil "~D" min-val)
              :max (format nil "~D" max-val)))))

(defmethod fluxion.components:render ((c alert-settings))
  (let ((th (settings-thresholds c)))
    (spinneret:with-html-string
      (:div :id (fluxion.components:component-id c) :class "panel"
        (:h2 "Alert Thresholds")
        (:p :class "panel-subtitle" "Changes take effect immediately")
        (:div :class "threshold-grid"
          (:raw (threshold-field "CPU warning"
                  (observatory.simulation:alert-thresholds-cpu-warning th)
                  "/action/alert-settings/set-cpu-warning" :unit "%"))
          (:raw (threshold-field "CPU critical"
                  (observatory.simulation:alert-thresholds-cpu-critical th)
                  "/action/alert-settings/set-cpu-critical" :unit "%"))
          (:raw (threshold-field "Queue warning"
                  (observatory.simulation:alert-thresholds-queue-warning th)
                  "/action/alert-settings/set-queue-warning" :max-val 200 :unit "jobs"))
          (:raw (threshold-field "Queue critical"
                  (observatory.simulation:alert-thresholds-queue-critical th)
                  "/action/alert-settings/set-queue-critical" :max-val 200 :unit "jobs"))
          (:raw (threshold-field "Latency warning"
                  (observatory.simulation:alert-thresholds-latency-warning th)
                  "/action/alert-settings/set-latency-warning" :max-val 1000 :unit "ms"))
          (:raw (threshold-field "Latency critical"
                  (observatory.simulation:alert-thresholds-latency-critical th)
                  "/action/alert-settings/set-latency-critical" :max-val 1000 :unit "ms")))
        (:div :id "threshold-errors")))))

;;; -------------------------------------------------------
;;; 6. Activity Feed
;;; -------------------------------------------------------

(defclass activity-feed (fluxion.components:component)
  ()
  (:default-initargs :id "activity-feed"))

(defmethod fluxion.components:render ((c activity-feed))
  (let ((log (observatory.simulation:world-activity-log observatory.simulation:*world*)))
    (spinneret:with-html-string
      (:div :id (fluxion.components:component-id c) :class "panel"
        (:h2 "Activity Feed")
        (:div :class "feed-list"
          (if log
              (dolist (entry (subseq log 0 (min 20 (length log))))
                (:div :class "feed-entry"
                  (:span :class "feed-time" (car entry))
                  (:span :class "feed-msg" (cdr entry))))
              (:p :class "text-muted" "No activity yet.")))))))

;;; -------------------------------------------------------
;;; 7. Transaction Demo
;;; -------------------------------------------------------

(defclass transaction-demo (fluxion.components:component)
  ()
  (:default-initargs :id "transaction-demo"))

(defmethod fluxion.components:render ((c transaction-demo))
  (spinneret:with-html-string
    (:div :id (fluxion.components:component-id c) :class "panel transaction-panel"
      (:h2 "Glitch-Free Transaction Demo")
      (:p :class "panel-subtitle"
          "This deployment changes multiple source cells at once. "
          "Lattice batches the propagation so derived dashboard values update once, "
          "with a consistent snapshot.")
      (:button :class "btn btn-deploy"
               :data-on-click "/action/transaction-demo/deploy"
               "Simulate Deployment"))))
