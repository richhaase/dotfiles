(require 'package)
(add-to-list 'package-archives
             '("marmalade" . "http://marmalade-repo.org/packages/"))
(package-initialize)

(when (not (package-installed-p 'clojure-mode))
  (package-refresh-contents)
  (package-install 'clojure-mode))

(when (not (package-installed-p 'paredit))
  (package-refresh-contents)
  (package-install 'paredit))

(when (not (package-installed-p 'nrepl))
  (package-refresh-contents)
  (package-install 'nrepl))

;; paraedit hook for clojure-mode
(add-hook 'clojure-mode-hook 'paraedit)

;; enable eldoc in clojure buffers
(add-hook 'nrepl-interaction-mode-hook
  'nrepl-turn-on-eldoc-mode)

;; hide nrepl buffers
(setq nrepl-hide-special-buffers t)

;; disable error buffer outside of nrepl
(setq nrepl-popup-stacktraces nil)

;; paraedit hook for nrepl
(add-hook 'nrepl-mode-hook 'paredit-mode)

;; dark color scheme
(load-file "~/.emacs.d/themes/dark-emacs-theme.el")
(when (window-system) 
  (load-theme 'dark-emacs))
