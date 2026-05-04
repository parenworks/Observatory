;;;; -*- encoding:utf-8 -*-
;;;; Fluxion Observatory - Simulated world model
;;;;
;;;; The "world" is the server-owned state that the dashboard observes.
;;;; A background thread mutates it; Fluxion pushes patches to browsers.

(in-package #:observatory.simulation)

;;; -------------------------------------------------------
;;; Time formatting
;;; -------------------------------------------------------

(defun format-time-now ()
  "Return current time as HH:MM:SS string."
  (multiple-value-bind (s min h) (get-decoded-time)
    (format nil "~2,'0D:~2,'0D:~2,'0D" h min s)))

;;; -------------------------------------------------------
;;; Service model
;;; -------------------------------------------------------

(defclass service ()
  ((name         :initarg :name         :accessor service-name
                 :type string :documentation "Machine-readable identifier.")
   (display-name :initarg :display-name :accessor service-display-name
                 :type string :documentation "Human-readable name.")
   (status       :initarg :status       :accessor service-status
                 :initform :healthy :type keyword
                 :documentation "One of :healthy :degraded :down :restarting")
   (latency      :initarg :latency      :accessor service-latency
                 :initform 0 :type number
                 :documentation "Simulated latency in ms.")
   (error-rate   :initarg :error-rate   :accessor service-error-rate
                 :initform 0.0 :type number
                 :documentation "Simulated error rate as percentage.")
   (restart-at   :initarg :restart-at   :accessor service-restart-at
                 :initform nil
                 :documentation "Universal time when restart began, or NIL.")))

(defmethod print-object ((s service) stream)
  (print-unreadable-object (s stream :type t)
    (format stream "~A ~A" (service-name s) (service-status s))))

(defun make-service (name display-name &key (status :healthy) (latency 0) (error-rate 0.0))
  (make-instance 'service
    :name name :display-name display-name
    :status status :latency latency :error-rate error-rate))

;;; -------------------------------------------------------
;;; Alert thresholds (per-session)
;;; -------------------------------------------------------

(defstruct alert-thresholds
  (cpu-warning      75  :type number)
  (cpu-critical     90  :type number)
  (queue-warning    50  :type number)
  (queue-critical   100 :type number)
  (latency-warning  150 :type number)
  (latency-critical 300 :type number))

(defun make-default-thresholds ()
  (make-alert-thresholds))

;;; -------------------------------------------------------
;;; World state
;;; -------------------------------------------------------

(defclass world ()
  ((services        :accessor world-services
                    :documentation "List of service objects.")
   (cpu             :initform 45  :accessor world-cpu :type number)
   (memory          :initform 38  :accessor world-memory :type number)
   (queue-depth     :initform 12  :accessor world-queue-depth :type number)
   (request-rate    :initform 84  :accessor world-request-rate :type number)
   (sse-connections :initform 0   :accessor world-sse-connections :type number)
   (activity-log    :initform nil :accessor world-activity-log
                    :documentation "List of (timestamp . message) cons cells, newest first.")
   (lock            :initform (bt:make-lock "observatory-world")
                    :accessor world-lock)))

(defvar *world* nil "The global simulation world.")

(defun init-world ()
  "Create and install the global world with initial services."
  (let ((w (make-instance 'world)))
    (setf (world-services w)
          (list (make-service "api-gateway"      "API Gateway"      :latency 42  :error-rate 0.1)
                (make-service "worker-pool"       "Worker Pool"      :latency 180 :error-rate 2.4
                                                                    :status :degraded)
                (make-service "database"          "Database"         :latency 12  :error-rate 0.0)
                (make-service "sse-broker"        "SSE Broker"       :latency 18  :error-rate 0.0)
                (make-service "report-renderer"   "Report Renderer"  :latency 0   :error-rate 0.0
                                                                    :status :down)))
    (setf (world-activity-log w)
          (list (cons (format-time-now) "Observatory started")
                (cons (format-time-now) "Worker Pool reporting elevated latency")
                (cons (format-time-now) "Report Renderer is down")))
    (setf *world* w)
    w))

;;; -------------------------------------------------------
;;; Derived state functions
;;; -------------------------------------------------------

(defun find-service (name &optional (w *world*))
  "Find a service by its machine name."
  (find name (world-services w) :key #'service-name :test #'string=))

(defun compute-health-score (&optional (w *world*))
  "Compute a 0-100 health score from service statuses and resource metrics."
  (let* ((services (world-services w))
         (total (length services))
         (healthy-count (count :healthy services :key #'service-status))
         (degraded-count (count :degraded services :key #'service-status))
         (service-score (if (zerop total) 100
                            (round (* 100 (/ (+ healthy-count (* 0.5 degraded-count)) total)))))
         (cpu-penalty (max 0 (- (world-cpu w) 80)))
         (mem-penalty (max 0 (- (world-memory w) 85))))
    (max 0 (min 100 (- service-score cpu-penalty mem-penalty)))))

(defun compute-overall-status (&optional (w *world*))
  "Derive overall status from services. Returns :critical :degraded or :healthy."
  (let ((services (world-services w)))
    (cond
      ((some (lambda (s) (eq (service-status s) :down)) services) :critical)
      ((some (lambda (s) (member (service-status s) '(:degraded :restarting))) services) :degraded)
      ((> (world-cpu w) 90) :critical)
      ((> (world-cpu w) 75) :degraded)
      (t :healthy))))

(defun compute-active-alerts (thresholds &optional (w *world*))
  "Return a list of alert strings given THRESHOLDS and world state W."
  (let ((alerts nil))
    (when (>= (world-cpu w) (alert-thresholds-cpu-critical thresholds))
      (push (format nil "CPU critical: ~D%" (world-cpu w)) alerts))
    (when (and (< (world-cpu w) (alert-thresholds-cpu-critical thresholds))
               (>= (world-cpu w) (alert-thresholds-cpu-warning thresholds)))
      (push (format nil "CPU warning: ~D%" (world-cpu w)) alerts))
    (when (>= (world-queue-depth w) (alert-thresholds-queue-critical thresholds))
      (push (format nil "Queue critical: ~D jobs" (world-queue-depth w)) alerts))
    (when (and (< (world-queue-depth w) (alert-thresholds-queue-critical thresholds))
               (>= (world-queue-depth w) (alert-thresholds-queue-warning thresholds)))
      (push (format nil "Queue warning: ~D jobs" (world-queue-depth w)) alerts))
    (dolist (svc (world-services w))
      (when (and (> (service-latency svc) 0)
                 (>= (service-latency svc) (alert-thresholds-latency-critical thresholds)))
        (push (format nil "~A latency critical: ~Dms"
                      (service-display-name svc) (service-latency svc)) alerts))
      (when (and (> (service-latency svc) 0)
                 (< (service-latency svc) (alert-thresholds-latency-critical thresholds))
                 (>= (service-latency svc) (alert-thresholds-latency-warning thresholds)))
        (push (format nil "~A latency warning: ~Dms"
                      (service-display-name svc) (service-latency svc)) alerts))
      (when (eq (service-status svc) :down)
        (push (format nil "~A is DOWN" (service-display-name svc)) alerts)))
    (nreverse alerts)))

(defun compute-resource-status (value warning critical)
  "Return :healthy :warning or :critical based on VALUE against thresholds."
  (cond
    ((>= value critical) :critical)
    ((>= value warning) :warning)
    (t :healthy)))

;;; -------------------------------------------------------
;;; Activity log
;;; -------------------------------------------------------

(defun add-activity (message &optional (w *world*))
  "Prepend a timestamped message to the activity log. Keeps last 50."
  (push (cons (format-time-now) message) (world-activity-log w))
  (when (> (length (world-activity-log w)) 50)
    (setf (world-activity-log w)
          (subseq (world-activity-log w) 0 50))))

;;; -------------------------------------------------------
;;; Simulation mutations
;;; -------------------------------------------------------

(defun jitter (base amplitude)
  "Return BASE +/- random AMPLITUDE."
  (+ base (- (random (* 2 amplitude)) amplitude)))

(defun clamp (val lo hi)
  (min hi (max lo val)))

(defun tick-world (&optional (w *world*))
  "Advance the simulation by one tick. Mutates service metrics and resources."
  (bt:with-lock-held ((world-lock w))
    ;; Drift resource metrics
    (setf (world-cpu w)
          (clamp (round (jitter (world-cpu w) 5)) 5 99))
    (setf (world-memory w)
          (clamp (round (jitter (world-memory w) 3)) 10 95))
    (setf (world-queue-depth w)
          (clamp (round (jitter (world-queue-depth w) 8)) 0 200))
    (setf (world-request-rate w)
          (clamp (round (jitter (world-request-rate w) 12)) 10 500))
    ;; Drift service metrics for non-down services
    (dolist (svc (world-services w))
      (case (service-status svc)
        (:healthy
         (setf (service-latency svc)
               (clamp (round (jitter (service-latency svc) 8)) 1 300))
         (setf (service-error-rate svc)
               (clamp (/ (round (* 10 (jitter (service-error-rate svc) 0.3))) 10.0)
                      0.0 10.0)))
        (:degraded
         (setf (service-latency svc)
               (clamp (round (jitter (service-latency svc) 20)) 50 500))
         (setf (service-error-rate svc)
               (clamp (/ (round (* 10 (jitter (service-error-rate svc) 0.8))) 10.0)
                      0.5 15.0)))
        (:down
         (setf (service-latency svc) 0)
         (setf (service-error-rate svc) 0.0))
        (:restarting
         ;; Recover after 3+ seconds
         (when (and (service-restart-at svc)
                    (>= (- (get-universal-time) (service-restart-at svc)) 3))
           (setf (service-status svc) :healthy)
           (setf (service-restart-at svc) nil)
           (setf (service-latency svc) (+ 5 (random 30)))
           (setf (service-error-rate svc) (/ (random 5) 10.0))
           (add-activity (format nil "~A is now healthy" (service-display-name svc)) w)))))))

(defun restart-service (service-name &optional (w *world*))
  "Begin a restart sequence for the named service. Returns T if found.
Does nothing if the service is already restarting."
  (let ((svc (find-service service-name w)))
    (when (and svc (not (eq (service-status svc) :restarting)))
      (bt:with-lock-held ((world-lock w))
        (setf (service-status svc) :restarting)
        (setf (service-restart-at svc) (get-universal-time))
        (setf (service-latency svc) 0)
        (setf (service-error-rate svc) 0.0))
      (add-activity (format nil "~A restart initiated" (service-display-name svc)) w)
      ;; Recovery is handled by tick-world after 3+ seconds
      t)))

(defun simulate-deployment (&optional (w *world*))
  "Simulate a deployment that changes multiple metrics atomically.
Returns after all mutations are applied."
  (bt:with-lock-held ((world-lock w))
    ;; Spike CPU and queue
    (setf (world-cpu w) (clamp (+ (world-cpu w) 25) 50 98))
    (setf (world-queue-depth w) (clamp (+ (world-queue-depth w) 40) 20 180))
    (setf (world-request-rate w) (clamp (+ (world-request-rate w) 60) 50 450))
    ;; All services briefly degrade
    (dolist (svc (world-services w))
      (when (eq (service-status svc) :healthy)
        (setf (service-status svc) :degraded)
        (setf (service-latency svc) (+ (service-latency svc) 80))))
    (add-activity "Deployment started: all services transitioning" w))
  ;; Recover after a delay
  (bt:make-thread
   (lambda ()
     (sleep 4)
     (bt:with-lock-held ((world-lock w))
       (dolist (svc (world-services w))
         (when (eq (service-status svc) :degraded)
           (setf (service-status svc) :healthy)
           (setf (service-latency svc) (+ 5 (random 30)))
           (setf (service-error-rate svc) (/ (random 5) 10.0))))
       (setf (world-cpu w) (clamp (- (world-cpu w) 20) 15 70))
       (setf (world-queue-depth w) (clamp (- (world-queue-depth w) 35) 5 40))
       (add-activity "Deployment complete: services recovered" w)))
   :name "deployment-recovery"))
