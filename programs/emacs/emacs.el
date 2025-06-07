(eval-when-compile
  (require 'use-package))

(use-package bind-key
  :config
  (add-to-list 'same-window-buffer-names "*Personal Keybindings*"))

;; Theme
(use-package gruvbox-theme
  :config
  (load-theme 'gruvbox-dark-hard t))

(setq-default indent-tabs-mode nil)
(setq make-backup-files nil)

(use-package powerline
  :config
  (powerline-default-theme))

(use-package wgrep)

(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status))

(line-number-mode 1) ; Show line number in the mode-line.

(use-package eglot
  :config
  (setq eglot-sync-connect nil) ; Asynchronously establish the connection.
  (add-to-list 'eglot-ignored-server-capabilities :inlayHintProvider) ; Eliminate noisy hints.
  )

(use-package vertico
  :hook (after-init . vertico-mode))

(use-package marginalia
  :hook (after-init . marginalia-mode))

(use-package ethan-wspace
  :hook (after-init . global-ethan-wspace-mode)
  :config
  (setq mode-require-final-newline nil)) ; Don't automatically add final newlines.


;; Company mode is a standard completion package that works well with lsp-mode.
(use-package company
  :ensure t
  :config
  ;; Optionally enable completion-as-you-type behavior.
  (setq company-idle-delay 0)
  (setq company-minimum-prefix-length 1))

(use-package highlight-parentheses
  :config
  (add-hook 'prog-mode-hook #'highlight-parentheses-mode))

;; direnv
(use-package direnv
  :init
  (add-hook 'prog-mode-hook #'direnv-update-environment)
  :config
  (direnv-mode))

(use-package which-key
  :config  
  (which-key-mode))

(use-package dockerfile-mode
  :mode "Dockerfile\\'"
  :interpreter "docker")  

(use-package yaml-mode
  :ensure t
  :mode ("\\.ya?ml\\'" . yaml-mode))

(use-package markdown-mode
  :ensure t
  :mode ("README\\.md\\'" . gfm-mode)
  :init (setq markdown-command "multimarkdown")
  :bind (:map markdown-mode-map
         ("C-c C-e" . markdown-do)))

(use-package nix-mode)

(use-package go-mode
  :ensure t
  :init
  (add-hook 'before-save-hook 'gofmt-before-save)
  (add-hook 'go-mode-hook 'whitespace-mode)
  (add-hook 'go-mode-hook
            '(lambda ()
               (setq-local tab-width 2
                           indent-tabs-mode 1
                           whitespace-style '(face trailing lines-char empty space-before-tab space-after-tab))
               ;; HACK: `whitespace-style' is global, and setting locally doesn't take
               ;; effect for some reason until `whitespace-mode' is restarted
               ;; https://emacs.stackexchange.com/questions/54212/whitespace-mode-settings-on-per-major-mode-basis
               (whitespace-mode 0)
               (whitespace-mode 1)))
  :mode ("\\.go\\'" . go-mode))

(use-package terraform-mode
  :ensure t
  :init
  (add-hook 'terraform-mode-hook #'terraform-format-on-save-mode)
  :mode ("\\.tf\\'" . terraform-mode))

(use-package copilot
  :vc (:url "https://github.com/copilot-emacs/copilot.el")
  :init
  (defun turn-on-copilot-mode ()
    (interactive)
    (copilot-mode 1))

  ;; [global-copilot-mode uses entire system memory · Issue #226 · copilot-emacs/copilot.el](https://github.com/copilot-emacs/copilot.el/issues/226)
  :hook ((text-mode-hook prog-mode-hook) . turn-on-copilot-mode)

  :config
  (add-to-list 'copilot-indentation-alist '(prog-mode 2))
  (add-to-list 'copilot-indentation-alist '(org-mode 2))
  (add-to-list 'copilot-indentation-alist '(go-mode 2))
  (add-to-list 'copilot-indentation-alist '(text-mode 2))
  (add-to-list 'copilot-indentation-alist '(emacs-lisp-mode 2))

  ;;:defer t
  ;;:hook (add-hook 'prog-mode-hook 'copilot-mode))
  :bind (:map copilot-completion-map
            ("<tab>" . 'copilot-accept-completion)
            ("TAB" . 'copilot-accept-completion)
            ("C-TAB" . 'copilot-accept-completion-by-word)
            ("C-<tab>" . 'copilot-accept-completion-by-word)
            ("C-n" . 'copilot-next-completion)
            ("C-p" . 'copilot-previous-completion)))

  ;;:vc (:url "https://github.com/copilot-emacs/copilot.el"
  ;;          :rev :newest
  ;;          :branch "main"))

  ;;:straight (:host github :repo "copilot-emacs/copilot.el" :files ("*.el"))
  ;;:ensure t
