;;;; -*- encoding:utf-8 -*-
;;;; Fluxion Observatory - A live operations dashboard built with Fluxion

(defsystem "observatory"
  :name "Fluxion Observatory"
  :version "0.1.0"
  :author "Glenn Thompson"
  :licence "MIT"
  :description "A live operations dashboard showcasing Fluxion's reactive architecture."
  :depends-on ("fluxion" "fluxion/client" "alexandria" "bordeaux-threads")
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "simulation")
     (:file "components")
     (:file "actions")
     (:file "pages")
     (:file "app")))))
