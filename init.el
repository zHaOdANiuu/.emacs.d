;;; -*- lexical-binding: t -*-
(put 'if-let 'byte-obsolete-info nil)
(put 'when-let 'byte-obsolete-info nil)
(set-default-toplevel-value 'lexical-binding t)

(setq cursor-type 'box
      visible-bell nil
      visible-cursor nil
      resize-mini-windows t
      long-line-threshold 1000
      large-hscroll-threshold 1000
      bidi-display-reordering 'left-to-right
      bidi-paragraph-direction 'left-to-right
      undo-limit (* 13 160000)
      undo-strong-limit (* 13 240000)
      undo-outer-limit (* 13 24000000)
      delete-pair-push-mark t
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
(let ((file-name-handler-alist nil))
  (require 'nn-world-theme)
  (require 'init-def)
  (load custom-file)
  (require 'init-font)
  (require 'init-base)
  (require 'init-advanced)
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
