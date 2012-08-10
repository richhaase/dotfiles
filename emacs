;; Set window size
(set-frame-height (selected-frame) 50)
(set-frame-width (selected-frame) 160)

;; autoload ruby-mode
(autoload 'ruby-mode "ruby-mode" "Major mode for ruby files" t)
(add-to-list 'auto-mode-alist '("\\.rb$" . ruby-mode))
(add-to-list 'interpreter-mode-alist '("ruby" . ruby-mode))

;;; This was installed by package-install.el.
;;; This provides support for the package system and
;;; interfacing with ELPA, the package archive.
;;; Move this code earlier if you want to reference
;;; packages in your .emacs.
(when
    (load
     (expand-file-name "~/.emacs.d/elpa/package.el"))
  (package-initialize))

;; makes clojure-mode work
(add-to-list 'load-path "~/.emacs.d/")
(require 'clojure-mode)

;; makes clojure-mode work better
(setq inferior-lisp-program "/Users/rdh/.bin/lein repl")

(defun na-load-buffer ()
  (interactive)
  (point-to-register 5)
  (mark-whole-buffer)
  (lisp-eval-region (point) (mark) nil)
  (jump-to-register 5))

(add-hook 'clojure-mode-hook
          '(lambda ()
             (define-key clojure-mode-map 
               "\e\C-x" 'lisp-eval-defun)
             (define-key clojure-mode-map 
               "\C-x\C-e" 'lisp-eval-last-sexp)
             (define-key clojure-mode-map 
               "\C-c\C-e" 'lisp-eval-last-sexp)
             (define-key clojure-mode-map 
               "\C-c\C-r" 'lisp-eval-region)
             (define-key clojure-mode-map 
               "\C-c\C-l" 'na-load-buffer)
             (define-key clojure-mode-map 
               "\C-c\C-z" 'run-lisp)))