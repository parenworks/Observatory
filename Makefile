.PHONY: build run clean

SBCL := sbcl
PORT ?= 5222

build:
	$(SBCL) --non-interactive --load build.lisp

run: build
	./observatory

run-dev:
	$(SBCL) --non-interactive \
		--eval '(require :asdf)' \
		--eval '(ql:quickload :observatory)' \
		--eval '(observatory:start :port $(PORT))' \
		--eval '(loop (sleep 60))'

clean:
	rm -f observatory
	find . -name '*.fasl' -delete
