;; Keybindings
;; (global-set-key (kbd "C-x g") 'magit-status)

;; (server-start)

;; Theme
(load-theme 'gruvbox-dark-medium t)
(setq make-backup-files nil)

(use-package powerline
  :config
  (powerline-default-theme))

(use-package wgrep)

(use-package magit
  :bind ("C-x g" . magit-status))

;;; linum
(use-package linum
  :config
  (add-hook 'prog-mode-hook 'linum-mode)
  (setq linum-format "%4d "))

(use-package highlight-parentheses
  :config
  (add-hook 'prog-mode-hook #'highlight-parentheses-mode))

;; (defun my-change-window-divider ()
;;   (let ((display-table (or buffer-display-table standard-display-table)))
;;     (set-display-table-slot display-table 5 ?│)
;;     (set-window-display-table (selected-window) display-table)))

;; (add-hook 'window-configuration-change-hook 'my-change-window-divider)

(use-package whitespace-cleanup-mode
  :config
  (global-whitespace-cleanup-mode))

(use-package lsp-mode
  :ensure t
  :commands (lsp lsp-deferred)
  :hook (go-mode . lsp-deferred))

(use-package go-mode
  :init
  (add-hook 'go-mode-hook
            (lambda ()
              (setq tab-width 2))))

;; Set up before-save hooks to format buffer and add/delete imports.
;; Make sure you don't have other gofmt/goimports hooks enabled.
(defun lsp-go-install-save-hooks ()
  (add-hook 'before-save-hook #'lsp-format-buffer t t)
  (add-hook 'before-save-hook #'lsp-organize-imports t t))
(add-hook 'go-mode-hook #'lsp-go-install-save-hooks)

;; Optional - provides fancier overlays.
(use-package lsp-ui
  :ensure t
  :config
  (setq lsp-eldoc-enable-hover nil)
  :commands lsp-ui-mode)

;; Company mode is a standard completion package that works well with lsp-mode.
(use-package company
  :ensure t
  :config
  ;; Optionally enable completion-as-you-type behavior.
  (setq company-idle-delay 0)
  (setq company-minimum-prefix-length 1))

;; direnv
(use-package direnv
  :init
  (add-hook 'prog-mode-hook #'direnv-update-environment)
  :config
  (direnv-mode))

(use-package projectile
  :config
  (projectile-mode +1))

(use-package which-key
  :config  
  (which-key-mode))

(use-package dockerfile-mode
  :mode "Dockerfile\\'"
  :interpreter "docker")  

(use-package yaml-mode
  :ensure t
  :mode ("\\.ya?ml\\'" . yaml-mode))
