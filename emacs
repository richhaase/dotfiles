;;; The SBCL binary and command-line arguments
(setq inferior-lisp-program "/usr/local/bin/sbcl --noinform")

;;; Zenburn color theme
(add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
(load-theme 'zenburn t)

;;; Set default window size 140X40
(set-frame-height (selected-frame) 40)
(set-frame-width (selected-frame) 140)