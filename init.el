;;; -*- lexical-binding: t -*-
(require 'package)
(setq package-install-upgrade-built-in nil
      package-check-signature nil
      package-archives
      '(("melpa-cn" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
        ("gnu-cn"   . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")))
(package-initialize)

(require 'use-package)
(setq use-package-always-ensure t
      use-package-always-defer t
      use-package-expand-minimally t
      use-package-enable-imenu-support t)

(push (expand-file-name "lisp/" user-emacs-directory) load-path)
(push (expand-file-name "lisp/lang" user-emacs-directory) load-path)
(dolist (entry (directory-files-and-attributes
                (expand-file-name "extension" user-emacs-directory) t "\\`[^.]"))
  (when (eq t (cadr entry))
    (push (car entry) load-path)))

(require 'cl-lib)
(require 'init-def)
(require 'init-font)
(require 'init-base)
(require 'init-advanced)
(require 'init-editor)
(require 'init-lang)
(require 'init-debug)
(require 'init-diagnostics)
(require 'init-completion)
(require 'init-navigation)
(require 'init-vc)
(require 'init-www)
(require 'init-utils)
(require 'init-display)
(require 'init-mode-line)
(require 'init-terminal)
(require 'init-keybind)
(require 'init-word-move)
(require 'init-context-menu)
(require 'init-home)
(require 'nn-world-theme)
(setq custom-file "~/.emacs.d/custom.el")
(load custom-file)
