;;; -*- lexical-binding: t -*-
(defun nn-has-lsp ()
  (and (fboundp 'eglot-current-server)
       (eglot-current-server)))

(defun nn-convert-utf8 ()
  (interactive)
  (set-buffer-file-coding-system 'utf-8))

(defun nn-explorer-open ()
  (interactive)
  (shell-command "explorer ."))

(defun nn-live-server ()
  (interactive)
  (require 'live-server)
  (live-server-start))

(defun nn-context-menu (event)
  (interactive "e")
  (let ((menu
         (cond
          ((or (derived-mode-p 'dired-mode)
               (derived-mode-p 'speedbar-mode))
           nn-project-menu-items)
          ((or (derived-mode-p 'prog-mode)
               (derived-mode-p 'text-mode))
           nn-edit-menu-items)
          (t nn-leisure-menu-items))))
    (popup-menu menu event)))

(defconst nn-edit-menu-items
  '("NN Edit Menu"
    ["Comman Format" apheleia-format-buffer]
    ["Debug Code"    dape]
    ["Lsp Connect"   eglot]
    ["Lsp Shutdown"  eglot-shutdown]
    ["Lsp Format"    eglot-format-buffer :active (nn-has-lsp)]
    ["Lsp Log"       eglot-stderr-buffer :active (nn-has-lsp)]
    ("Code Actions"
     :active (nn-has-lsp)
     ["Quick Fix"        eglot-code-actions]
     ["Extract"          eglot-code-action-extract]
     ["Inline"           eglot-code-action-inline]
     ["Organize Imports" eglot-code-action-organize-imports]
     ["Rewrite"          eglot-code-action-rewrite])
    "--"
    ["Translate Word"    my-translate-word]
    ["Translate Region"  my-translate-region]
    ["Translate Bufefer" my-translate-buffer]
    "--"
    ["Indent Format"  indent-region]
    ["Spell Check"    ispell-buffer]
    ["Convert Utf8"   nn-convert-utf8]
    ["Align Region"   align-regexp]
    ["Regexp Builder" re-builder]
    ["Sort Lines"     sort-lines]))

(defconst nn-project-menu-items
  '("NN Project Menu"
    ["Create Tasg File" citre-create-tags-file]
    ["Update Tags File" citre-update-this-tags-file]
    ["On Live server"   nn-live-server]
    ["On Explorer Open" nn-explorer-open]
    ;; TODO
    ("C/C++ Module"
     ["New header File"     kill-buffer]
     ["New C++ Module File" kill-buffer]
     ["New C/C++ Project"   kill-buffer])
    ("Web Module"
     ["New HTML Project"  kill-buffer]
     ["New Vue Project"   kill-buffer]
     ["New React Project" kill-buffer])))

(defconst nn-leisure-menu-items
  '("NN Leisure Menu"
    ["telegram"  telega]
    ["Read Mail" gnus]
    ["Read Rss"  my-newsticker-show-news]
    ["Send Mail" compose-mail]
    "--"
    ["Translate Word"    my-translate-word]
    ["Translate Region"  my-translate-region]
    ["Translate Bufefer" my-translate-buffer]))

(with-eval-after-load 'speedbar
  (keymap-set speedbar-mode-map "<down-mouse-3>" nil))

(keymap-global-set "<mouse-3>" #'nn-context-menu)
(keymap-global-set "<left-margin> <mouse-3>" #'nn-context-menu)

(provide 'init-context-menu)
