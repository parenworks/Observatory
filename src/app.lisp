;;;; -*- encoding:utf-8 -*-
;;;; Fluxion Observatory - Application setup
;;;;
;;;; Wires up the Fluxion app, registers components, starts background
;;;; threads for simulation ticking and dashboard pushing.

(in-package #:observatory)

;;; -------------------------------------------------------
;;; Application state
;;; -------------------------------------------------------

(defvar *app* nil "The running Fluxion application instance.")
(defvar *tick-thread* nil "Background thread that ticks the simulation.")

;;; -------------------------------------------------------
;;; Component names (used for factory registration)
;;; -------------------------------------------------------

(defparameter *component-ids*
  '("status-header" "service-table" "resource-cards"
    "capacity-planner" "alert-settings" "activity-feed"
    "transaction-demo"))

;;; -------------------------------------------------------
;;; Background simulation thread
;;; -------------------------------------------------------

(defun push-all-components (app)
  "Re-render and push-patch every component for every session."
  (bordeaux-threads:with-lock-held ((fluxion.server:app-session-lock app))
    (maphash
     (lambda (sid session)
       (declare (ignore sid))
       (dolist (cid *component-ids*)
         (handler-case
             (let ((comp (fluxion.server:session-component session cid)))
               (when comp
                 (fluxion.server:push-component-patch session comp)))
           (error (e)
             (format *error-output*
                     "~&Observatory push error [~A]: ~A~%" cid e)))))
     (fluxion.server:app-sessions app))))

(defun update-sse-connection-count (app)
  "Sync the world's SSE connection count with the actual app sessions."
  (when observatory.simulation:*world*
    (setf (observatory.simulation:world-sse-connections
           observatory.simulation:*world*)
          (fluxion.server:app-sse-connection-count app))))

(defun start-tick-thread (app)
  "Start the background thread that ticks the simulation every 2 seconds."
  (when (and *tick-thread* (bordeaux-threads:thread-alive-p *tick-thread*))
    (bordeaux-threads:destroy-thread *tick-thread*))
  (setf *tick-thread*
        (bordeaux-threads:make-thread
         (lambda ()
           (loop
             (sleep 2)
             (unless (fluxion.server:app-handler app)
               (return))
             (handler-case
                 (progn
                   (observatory.simulation:tick-world)
                   (update-sse-connection-count app)
                   (push-all-components app))
               (error (e)
                 (format *error-output*
                         "~&Observatory tick error: ~A~%" e)))))
         :name "observatory-tick")))

;;; -------------------------------------------------------
;;; Page handler
;;; -------------------------------------------------------

(defun ensure-shared-thresholds (session)
  "Ensure the status-header and alert-settings share the same thresholds object."
  (let ((header   (fluxion.server:session-component session "status-header"))
        (settings (fluxion.server:session-component session "alert-settings")))
    (when (and header settings)
      (setf (observatory.components:header-thresholds header)
            (observatory.components:settings-thresholds settings)))))

(defun dashboard-handler (app session env)
  "Render the full dashboard page for this session."
  (declare (ignore app env))
  (ensure-shared-thresholds session)
  (list 200
        '(:content-type "text/html")
        (list (observatory.pages:render-dashboard-page
               :status-header    (fluxion.server:session-component session "status-header")
               :service-table    (fluxion.server:session-component session "service-table")
               :resource-cards   (fluxion.server:session-component session "resource-cards")
               :capacity-planner (fluxion.server:session-component session "capacity-planner")
               :alert-settings   (fluxion.server:session-component session "alert-settings")
               :activity-feed    (fluxion.server:session-component session "activity-feed")
               :transaction-demo (fluxion.server:session-component session "transaction-demo")
               :csrf-token       (fluxion.server:session-csrf-token session)))))

;;; -------------------------------------------------------
;;; Start / Stop
;;; -------------------------------------------------------

(defun start (&key (port 5222) (server :hunchentoot))
  "Start Fluxion Observatory."
  (when *app*
    (stop))

  ;; Initialise the simulated world
  (observatory.simulation:init-world)

  ;; Create the Fluxion app
  (setf *app* (fluxion.server:make-fluxion-app
               :port port
               :server server
               :static-dir (asdf:system-relative-pathname "fluxion" "static/")))

  ;; Register component factories (one instance per session)
  (fluxion.server:register-component-factory *app* "status-header"
    (lambda () (make-instance 'observatory.components:status-header)))
  (fluxion.server:register-component-factory *app* "service-table"
    (lambda () (make-instance 'observatory.components:service-table)))
  (fluxion.server:register-component-factory *app* "resource-cards"
    (lambda () (make-instance 'observatory.components:resource-cards)))
  (fluxion.server:register-component-factory *app* "capacity-planner"
    (lambda () (make-instance 'observatory.components:capacity-planner)))
  (fluxion.server:register-component-factory *app* "alert-settings"
    (lambda () (make-instance 'observatory.components:alert-settings)))
  (fluxion.server:register-component-factory *app* "activity-feed"
    (lambda () (make-instance 'observatory.components:activity-feed)))
  (fluxion.server:register-component-factory *app* "transaction-demo"
    (lambda () (make-instance 'observatory.components:transaction-demo)))

  ;; Build the Parenscript client runtime
  (fluxion.client:build-client)

  ;; Start the server
  (fluxion.server:start *app* #'dashboard-handler :port port :server server)

  ;; Start the simulation ticker
  (start-tick-thread *app*)

  (format t "~%~%  Fluxion Observatory running at http://localhost:~D~%~%" port)
  *app*)

(defun stop ()
  "Stop Fluxion Observatory."
  (when *tick-thread*
    (ignore-errors
     (when (bordeaux-threads:thread-alive-p *tick-thread*)
       (bordeaux-threads:destroy-thread *tick-thread*)))
    (setf *tick-thread* nil))
  (when *app*
    (ignore-errors (fluxion.server:stop *app*))
    (setf *app* nil))
  (format t "Observatory stopped.~%"))
