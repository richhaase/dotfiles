(add-to-list 'load-path "~/src/clojure-mode")
(setq inferior-list-program "clj")
(require 'clojure-mode)
(setq auto-mode-alist
      (cons '("\\.clj$" . clojure-mode)
	    auto-mode-alist))

(add-hook 'clojure-mode-hook
	  '(lambda ()
	     (define-key clojure-mode-map "\C-c\C-e" 'lisp-eval-last-sexp)))