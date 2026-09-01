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

(add-to-list 'find-sibling-rules '("/\\([^/]+\\)\\.\\(\\(s[ac]\\|le\\)ss\\|styl\\)\\'" "\\1\\.css\\'"))
(add-to-list 'find-sibling-rules '("/\\([^/]+\\)\\.css\\'" "\\1\\.\\(\\(s[ac]\\|le\\)ss\\|styl\\)\\'"))

(use-package syntax
  :ensure nil
  :config
  (setq syntax-wholeline-max 1000))

(use-package text-mode
  :ensure nil
  :mode "/.gitignore\\'" "/INSTALL\\'" "/LICENSE\\'"
  :custom (text-mode-ispell-word-completion nil))

(use-package conf-mode
  :ensure nil
  :mode "\\.env\\..*\\'" "\\.env\\'")

(provide 'init-lang)
