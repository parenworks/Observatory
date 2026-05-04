;;;; -*- encoding:utf-8 -*-
;;;; Build script for Fluxion Observatory standalone executable

(require :asdf)

;;; Load the system
(ql:quickload :observatory)

;;; Pre-build the Parenscript client runtime so it's baked into the image
(fluxion.client:build-client)

;;; Define the toplevel entry point
(defun observatory-main ()
  "Entry point for the standalone executable."
  (let ((port (or (ignore-errors
                    (parse-integer (uiop:getenv "PORT")))
                  5222)))
    (format t "~&Starting Fluxion Observatory on port ~D...~%" port)
    (observatory:start :port port)
    ;; Keep the main thread alive
    (handler-case
        (loop (sleep 60))
      (condition ()
        (format t "~&Shutting down...~%")
        (sb-ext:exit :code 0 :abort t)))))

;;; Save the executable
(sb-ext:save-lisp-and-die
 "observatory"
 :toplevel #'observatory-main
 :executable t
 :compression t)
