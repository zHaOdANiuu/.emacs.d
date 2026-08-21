;;; -*- lexical-binding: t -*-
(require 'treesit)
(require 'lang-cc)
(require 'lang-elisp)
(require 'lang-javascript)
(require 'lang-web)
(require 'lang-shell)
(require 'lang-org)
(require 'lang-markdown)
(require 'lang-json)
(require 'lang-yaml)

(use-package syntax
  :ensure nil
  :config
  (setq syntax-wholeline-max 1000))

(use-package text-mode
  :ensure nil
  :mode ("/.gitignore\\'" "/INSTALL\\'" "/LICENSE\\'")
  :custom (text-mode-ispell-word-completion nil))

(use-package conf-mode
  :ensure nil
  :mode ("\\.env\\..*\\'" "\\.env\\'")
  :init
  (add-to-list 'auto-mode-alist '("\\.env\\'" . conf-mode)))

(provide 'init-lang)
