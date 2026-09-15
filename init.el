;;; -*- lexical-binding: t -*-
(put 'if-let 'byte-obsolete-info nil)
(put 'when-let 'byte-obsolete-info nil)
(set-default-toplevel-value 'lexical-binding t)

(setq cursor-type 'box
      visible-bell nil
      visible-cursor nil
      resize-mini-windows t
      delete-pair-push-mark t
      undo-limit (* 13 160000)
      undo-strong-limit (* 13 240000)
      undo-outer-limit (* 13 24000000)
      word-wrap-by-category t
      window-combination-resize t
      bidi-inhibit-bpa t
      bidi-display-reordering nil
      long-line-threshold 1000
      large-hscroll-threshold 1000
      default-process-coding-system
      (if (eq system-type 'windows-nt)
          `(utf-8-dos . ,locale-coding-system)
        '(utf-8-unix . utf-8-unix)))

(setq-default tab-width 2
              tab-always-indent 'complete
              fill-column 80
              truncate-lines t
              truncate-partial-width-windows nil)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)
(let ((file-name-handler-alist nil))
  (require 'init-font)
  (require 'init-base)
  (require 'init-advanced)
  (require 'init-theme)
  (require 'init-display)
  (require 'init-editor)
  (require 'init-debug)
  (require 'init-diagnostics)
  (require 'init-completion)
  (require 'init-navigation)
  (require 'init-lang)
  (require 'init-vc)
  (require 'init-www)
  (require 'init-utils)
  (require 'init-mode-line)
  (require 'init-terminal)
  (require 'init-keybind)
  (require 'init-word-move)
  (require 'init-context-menu)
  (require 'init-home))

(let ((hook (if (daemonp)
                'server-after-make-frame-hook
              'after-init-hook)))
  (add-hook hook #'nn-font-init -100)
  (add-hook hook #'nn-home-init -90)
  (add-hook hook #'nn-theme-init -90))

(when (daemonp)
  (require 'magit)
  (require 'gnus)
  (require 'corfu)
  (require 'multiple-cursors))
