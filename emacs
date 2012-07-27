;; Set window size
(set-frame-height (selected-frame) 50)
(set-frame-width (selected-frame) 160)

;; autoload ruby-mode
(autoload 'ruby-mode "ruby-mode" "Major mode for ruby files" t)
(add-to-list 'auto-mode-alist '("\\.rb$" . ruby-mode))
(add-to-list 'interpreter-mode-alist '("ruby" . ruby-mode))