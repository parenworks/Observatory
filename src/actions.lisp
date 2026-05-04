;;;; -*- encoding:utf-8 -*-
;;;; Fluxion Observatory - Action handlers
;;;;
;;;; Actions are triggered by data-on-click and data-on-change attributes.
;;;; Each one mutates state and returns nil (auto-patch) or a list of events.

(in-package #:observatory.actions)

;;; -------------------------------------------------------
;;; Helpers
;;; -------------------------------------------------------

(defun parse-int (str)
  "Safely parse an integer from STR. Returns NIL on failure."
  (when (and str (stringp str) (> (length str) 0))
    (handler-case (parse-integer str :junk-allowed t)
      (error () nil))))

;;; -------------------------------------------------------
;;; Service actions
;;; -------------------------------------------------------

(fluxion.components:defaction observatory.components:service-table :restart (c params)
  (let ((svc-name (cdr (assoc :service params))))
    (when svc-name
      (observatory.simulation:restart-service svc-name)))
  nil)

;;; -------------------------------------------------------
;;; Capacity planner actions
;;; -------------------------------------------------------

(fluxion.components:defaction observatory.components:capacity-planner :set-rps (cp params)
  (let ((v (parse-int (cdr (assoc :value params)))))
    (when (and v (plusp v))
      (setf (fluxion.cells:cell-value
             (observatory.components:planner-rps-cell cp)) v)))
  nil)

(fluxion.components:defaction observatory.components:capacity-planner :set-workers (cp params)
  (let ((v (parse-int (cdr (assoc :value params)))))
    (when (and v (plusp v))
      (setf (fluxion.cells:cell-value
             (observatory.components:planner-workers-cell cp)) v)))
  nil)

(fluxion.components:defaction observatory.components:capacity-planner :set-target-cpu (cp params)
  (let ((v (parse-int (cdr (assoc :value params)))))
    (when (and v (> v 0) (<= v 100))
      (setf (fluxion.cells:cell-value
             (observatory.components:planner-target-cpu-cell cp)) v)))
  nil)

;;; -------------------------------------------------------
;;; Alert threshold actions
;;; -------------------------------------------------------

(defmacro def-threshold-action (action-name accessor)
  `(fluxion.components:defaction observatory.components:alert-settings ,action-name (c params)
     (let ((v (parse-int (cdr (assoc :value params)))))
       (when (and v (>= v 0))
         (setf (,accessor (observatory.components:settings-thresholds c)) v)
         (observatory.simulation:add-activity
          (format nil "Threshold ~A changed to ~D"
                  ,(string-downcase (symbol-name action-name)) v))))
     nil))

(def-threshold-action :set-cpu-warning
  observatory.simulation:alert-thresholds-cpu-warning)
(def-threshold-action :set-cpu-critical
  observatory.simulation:alert-thresholds-cpu-critical)
(def-threshold-action :set-queue-warning
  observatory.simulation:alert-thresholds-queue-warning)
(def-threshold-action :set-queue-critical
  observatory.simulation:alert-thresholds-queue-critical)
(def-threshold-action :set-latency-warning
  observatory.simulation:alert-thresholds-latency-warning)
(def-threshold-action :set-latency-critical
  observatory.simulation:alert-thresholds-latency-critical)

;;; -------------------------------------------------------
;;; Transaction demo action
;;; -------------------------------------------------------

(fluxion.components:defaction observatory.components:transaction-demo :deploy (c)
  (observatory.simulation:simulate-deployment)
  nil)
