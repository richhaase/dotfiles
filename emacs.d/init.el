(add-to-list 'load-path (expand-file-name "~/.emacs.d/"))

;; Clojure paredit hook
(add-hook 'clojure-mode-hook
	  (lambda ()
	    (paredit-mode 1)
	    ;; Get syntax highlighting in a REPL
	    (add-hook 'slime-repl-mode-hook
                      (defun clojure-mode-slime-font-lock ()
                        (let (font-lock-mode)
                          (clojure-mode-font-lock-setup))))))

;; marmalade package repo
(require 'package)
(add-to-list 'package-archives
	     '("maramalade" . "http://marmalade-repo.org/packages/"))
(package-initialize)


