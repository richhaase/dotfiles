;; The SBCL binary and command-line arguments
(setq inferior-lisp-program "/opt/local/bin/clj")

;; (add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
;; (load-theme 'solarized-light t)

;; Set default window size 
;; (set-frame-height (selected-frame) 50)
;; (set-frame-width (selected-frame) 150)

;; Haskell mode
(load "~/.emacs.d/haskell-mode/haskell-site-file")
(add-hook 'haskell-mode-hook 'turn-on-haskell-doc-mode)
(add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)
;;(add-hook 'haskell-mode-hook 'turn-on-haskell-indent)
;;(add-hook 'haskell-mode-hook 'turn-on-haskell-simple-indent)
