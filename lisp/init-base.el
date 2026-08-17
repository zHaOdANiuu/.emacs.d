;;; -*- lexical-binding: t -*-
(use-package simple
  :ensure nil
  :custom
  (global-visual-line-mode 1)
  (use-short-answers t)
  (use-dialog-box nil)
  (use-file-dialog nil)
  (indent-tabs-mode nil)
  (idle-update-delay 0.5)
  (read-process-output-max (* 4 1024 1024))
  (process-adaptive-read-buffering nil)
  (kill-whole-line t)
  (kill-do-not-save-duplicates t)
  (track-eol t)
  (undo-limit (* 13 160000))
  (undo-strong-limit (* 13 240000))
  (undo-outer-limit (* 13 24000000))
  (visible-bell nil)
  (visible-cursor nil)
  (ring-bell-function #'ignore)
  (redisplay-skip-fontification-on-input t)
  (read-extended-command-predicate #'command-completion-default-include-p)
  (completion-show-help nil)
  (next-error-highlight t)
  (next-error-highlight-no-select t))

(use-package repeat
  :ensure nil
  :init (repeat-mode 1)
  :custom (repeat-echo-mode-line t))

(use-package autorevert
  :ensure nil
  :custom
  (global-auto-revert-mode 1)
  (global-auto-revert-non-file-buffers t)
  (auto-revert-remote-files nil)
  (auto-revert-verbose t)
  (auto-revert-avoid-polling t))

(use-package files
  :ensure nil
  :custom
  (make-backup-files t)
  (backup-directory-alist `(("." . ,(expand-file-name "backup" nn-directory))))
  (auto-save-list-file-prefix (expand-file-name "auto-save-list/.saves-" nn-directory))
  (auto-save-file-name-transforms
   `(("\\`/[^/]*:\\([^/]*/\\)*\\([^/]*\\)\\'"
      ,(expand-file-name "autosave/tramp-\\2-" nn-directory) sha1)
     ("\\`/\\([^/]+/\\)*\\([^/]+\\)\\'"
      ,(expand-file-name "autosave/\\2-" nn-directory) sha1)))
  (auto-mode-case-fold nil)
  (auto-save-default nil)
  (delete-old-versions t)
  (delete-by-moving-to-trash t)
  (create-lockfiles nil)
  (confirm-kill-processes nil)
  (confirm-nonexistent-file-or-buffer nil)
  (kept-new-versions 3)
  (kept-old-versions 2)
  (version-control t)
  (backup-by-copying t)
  (find-file-visit-truename t)
  (find-file-suppress-same-file-warnings t)
  (require-final-newline t))

(use-package mule
  :ensure nil
  :custom
  (locale-coding-system 'utf-8-unix)
  (default-buffer-file-coding-system 'utf-8-unix)
  (default-process-coding-system '(utf-8-unix . utf-8-unix))
  :config
  (prefer-coding-system 'utf-8-unix)
  (set-language-environment "UTF-8")
  (set-default-coding-systems 'utf-8-unix)
  (set-keyboard-coding-system 'utf-8-unix)
  (set-terminal-coding-system 'utf-8-unix)
  (set-file-name-coding-system 'utf-8-unix)
  (set-selection-coding-system 'utf-8-unix)
  (when (eq system-type 'windows-nt)
    (set-selection-coding-system 'utf-16le-dos)
    (when-let* ((coding
                 (pcase (w32-get-console-codepage)
                   (65001 'utf-8-dos)
                   (936 'gbk-dos)
                   (_ nil))))
      (setq process-coding-system-alist
            `(("[pP][lL][iI][nN][kK]" . #1=(,coding . ,coding))
              ("[cC][mM][dD][pP][rR][oO][xX][yY]" . #1#)))
      (setq default-process-coding-system
            `(,coding . ,coding)))))

(use-package uniquify
  :ensure nil
  :custom
  (uniquify-buffer-name-style 'forward)
  (uniquify-strip-common-suffix t)
  (uniquify-after-kill-buffer-p t)
  ;; EMACS-31 keep this one, delete the one above
  (uniquify-after-kill-buffer-flag t))

(use-package ls-lisp
  :ensure nil
  :config
  (if (executable-find "ls")
      (setq ls-lisp-use-insert-directory-program t)
    (setq ls-lisp-emulation 'UNIX
          ls-lisp-use-string-collate nil
          ls-lisp-use-localized-time-format t
          ls-lisp-support-symlinks t
          ls-lisp-dirs-first t
          ls-lisp-verbosity '(links uid modes))
    (define-advice ls-lisp-format-file-size (:around (orig-fn file-size human-readable) my-format)
      "Use right-aligned human-readable format when HUMAN-READABLE is non-nil."
      (if human-readable
          (format " %4s" (file-size-human-readable file-size))
        (funcall orig-fn file-size human-readable)))))

(use-package recentf
  :ensure nil
  :init (recentf-mode 1)
  :hook (dired-mode-hook . my-recentf-add-dired-directory-h)
  :custom
  (recentf-save-file (expand-file-name "recentf.eld" nn-directory))
  (recentf-max-saved-items 5)
  (recentf-auto-cleanup t)
  (recentf-auto-save-timer nil)
  (recentf-exclude
   '("\\.?cache" ".cask" "url" "COMMIT_EDITMSG\\'" "bookmarks"
     "\\.\\(?:gz\\|gif\\|svg\\|png\\|jpe?g\\|bmp\\|xpm\\)$"
     "\\.?ido\\.last$" "\\.revive$" "/G?TAGS$" "/.elfeed/"
     "^/tmp/" "^/var/folders/.+$" "^/ssh:" "/persp-confs/"
     (lambda (file) (file-in-directory-p file package-user-dir))))
  :config
  (add-to-list 'recentf-keep '(derived-mode-p . dired-mode))
  (add-to-list 'recentf-filename-handlers #'substring-no-properties)
  (defun my-recentf-add-dired-directory-h ()
    "Add dired directories to recentf file list."
    (recentf-add-file default-directory)))

(use-package savehist
  :ensure nil
  :hook
  (savehist-save . my-savehist-unpropertize-variables-h)
  (savehist-save . my-savehist-remove-unprintable-registers-h)
  :init (savehist-mode 1)
  :custom
  (savehist-file (expand-file-name "savehist.el" nn-directory))
  (savehist-autosave-interval nil)
  (savehist-save-minibuffer-history t)
  (savehist-additional-variables
   '(kill-ring register-alist mark-ring global-mark-ring
               search-ring regexp-search-ring))
  :config
  (defun my-savehist-unpropertize-variables-h ()
    (setq kill-ring (mapcar #'substring-no-properties
                            (cl-remove-if-not #'stringp kill-ring))
          register-alist (cl-loop for (reg . item) in register-alist
                                  if (stringp item)
                                  collect (cons reg (substring-no-properties item))
                                  else collect (cons reg item))))
  (defun my-savehist-remove-unprintable-registers-h ()
    (setq register-alist (cl-remove-if-not #'savehist-printable register-alist))))

(use-package project
  :ensure nil
  :custom
  (project-list-file (expand-file-name "project-list.el" nn-directory))
  (project-vc-ignores
   '("node_modules" ".git" ".svn" "vendor" "dist" "build"
     ".cache" ".tox" "__pycache__" "target" "out"))
  (project-vc-include-untracked t)
  (project-vc-merge-submodules nil)
  (project-files-relative-names t)
  (project-search-function #'project-ripgrep))

(use-package mwheel
  :ensure nil
  :custom
  (mouse-wheel-progressive-speed nil)
  (mouse-wheel-follow-mouse nil)
  (mouse-wheel-tilt-scroll nil)
  (mouse-wheel-scroll-amount '(2 ((shift) . 2) ((control) . text-scale))))

(use-package pixel-scroll
  :ensure nil
  :init (pixel-scroll-precision-mode 1)
  :custom
  (scroll-margin 0)
  (scroll-step 0)
  (scroll-conservatively 101)
  (scroll-preserve-screen-position t)
  (fast-but-imprecise-scrolling t))

(use-package frame
  :ensure nil
  :hook (window-configuration-change . my-update-window-divider-bottom)
  :init
  (blink-cursor-mode -1)
  (window-divider-mode 1)
  :custom
  (frame-resize-pixelwise t)
  (frame-inhibit-implied-resize t)
  (frame-title-format
   '(:eval (concat
            (if (and buffer-file-name (buffer-modified-p)) "● " "")
            (buffer-name))))
  (window-divider-default-places t)
  (window-divider-default-right-width 1)
  (window-divider-default-bottom-width 0)
  :config
  (defun my-update-window-divider-bottom ()
    (set-frame-parameter nil 'bottom-divider-width
                         (if (eq (next-window) (selected-window))
                             0 1)))

  (defun my-buffer-predicate (buf)
    "Filter out * and space-prefixed buffers unless in `nn-buffer-allow-names'."
    (let ((name (buffer-name buf)))
      (or (member name nn-buffer-allow-names)
          (let ((first (aref name 0)))
            (not (= first ?*))))))
  (set-frame-parameter nil 'buffer-predicate #'my-buffer-predicate))

(use-package window
  :ensure nil
  :custom
  (split-width-threshold 160)
  (split-height-threshold nil)
  (window-resize-pixelwise t)
  (window-combination-resize t)
  (display-buffer-alist
   '(("\\*\\(Backtrace\\|Warnings\\|Compile-Log\\|Messages\\|Bookmark List\\|Occur\\|eldoc\\)\\*"
      (display-buffer-in-side-window)
      (window-height . 0.35)
      (side . bottom)
      (slot . 0))
     ("\\*\\([Hh]elp\\)\\*"
      (display-buffer-in-side-window)
      (window-width . 0.5)
      (side . right)
      (slot . 0))
     ("\\*\\(Flymake diagnostics\\)"
      (display-buffer-in-side-window)
      (window-height . 0.35)
      (side . bottom)
      (slot . 2))
     ("\\*\\(grep\\|xref\\|find\\)\\*"
      (display-buffer-in-side-window)
      (window-height . 0.35)
      (side . bottom)
      (slot . 1))
     ("\\*inferior.*"
      (display-buffer-in-side-window)
      (window-height . 0.5)
      (side . bottom)
      (slot . 1)))))

(provide 'init-base)
