;;; -*- lexical-binding: t -*-
(set-default-coding-systems 'utf-8-unix)
(set-locale-environment "en_US.UTF-8")
(set-charset-priority 'unicode)
(if (eq system-type 'windows-nt)
    (progn
      (set-clipboard-coding-system 'utf-16-le)
      (setq default-process-coding-system `(utf-8-dos . ,locale-coding-system)
            process-coding-system-alist
            '(("[pP][lL][iI][nN][kK]" utf-8-dos . gbk-dos)
              ("[cC][mM][dD][pP][rR][oO][xX][yY]" utf-8-dos . gbk-dos))))
  (set-clipboard-coding-system 'utf-8-unix)
  (setq default-process-coding-system '(utf-8-unix . utf-8-unix)))

(setq cursor-type 'box
      visible-bell nil
      visible-cursor nil
      adaptive-fill-regexp "[ t]+|[ t]*([0-9]+.|*+)[ t]*"
      adaptive-fill-first-line-regexp "^* *$"
      bidi-inhibit-bpa t
      bidi-display-reordering 'left-to-right
      bidi-paragraph-direction 'left-to-right
      long-line-threshold 1000
      large-hscroll-threshold 1000
      undo-limit (* 13 160000)
      undo-strong-limit (* 13 240000)
      undo-outer-limit (* 13 24000000)
      sentence-end-double-space nil
      delete-pair-push-mark t)

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
  (when (display-graphic-p)
    (require 'init-font))
  (require 'init-base)
  (require 'init-advanced)
  (require 'init-display)
  (require 'init-editor)
  (require 'init-lang)
  (require 'init-debug)
  (require 'init-diagnostics)
  (require 'init-completion)
  (require 'init-navigation)
  (require 'init-vc)
  (require 'init-www)
  (require 'init-utils)
  (require 'init-mode-line)
  (require 'init-terminal)
  (require 'init-keybind)
  (require 'init-word-move)
  (require 'init-context-menu)
  (require 'init-home))
