;;; -*- lexical-binding: t -*-
(use-package project
  :ensure nil
  :custom
  (project-list-file (concat nn-directory "project-list.el"))
  (project-vc-ignores
   '("node_modules" ".git" ".svn" "vendor" "dist" "build"
     ".cache" ".tox" "__pycache__" "target" "out"))
  (project-vc-include-untracked t)
  (project-vc-merge-submodules nil)
  (project-files-relative-names t)
  (project-search-function #'project-ripgrep))

(use-package simple
  :ensure nil
  :custom
  (indent-tabs-mode nil)
  (idle-update-delay 0.5)
  (kill-whole-line t)
  (kill-region-dwim t)
  (kill-do-not-save-duplicates t)
  (track-eol t)
  (read-extended-command-predicate #'command-completion-default-include-p)
  (completion-show-help nil)
  (next-error-highlight t)
  (next-error-highlight-no-select t))

(use-package files
  :ensure nil
  :custom
  (make-backup-files nil)
  (backup-directory-alist `(("." . ,(concat nn-directory "backup"))))
  (auto-save-list-file-prefix nil)
  (auto-save-file-name-transforms
   `(("\\`/[^/]*:\\([^/]*/\\)*\\([^/]*\\)\\'"
      ,(concat nn-directory "autosave/tramp-\\2-") sha1)
     ("\\`/\\([^/]/\\)*\\([^/]\\)\\'"
      ,(concat nn-directory "autosave/\\2-") sha1)))
  (auto-save-default nil)
  (auto-mode-case-fold nil)
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

(use-package ls-lisp
  :ensure nil
  :custom
  (ls-lisp-use-insert-directory-program (when (executable-find "ls") t))
  (ls-lisp-emulation 'UNIX)
  (ls-lisp-use-string-collate nil)
  (ls-lisp-use-localized-time-format t)
  (ls-lisp-support-symlinks t)
  (ls-lisp-dirs-first t)
  (ls-lisp-verbosity '(links uid modes))
  :config
  (when (and ls-lisp-use-insert-directory-program
             (eq system-type 'windows-nt))
    (define-advice insert-directory (:around (orig &rest args) my-w32-msys-ls)
      "Pass ANSI-codepage argv to `insert-directory-program', decode its UTF-8 output."
      (let ((coding-system-for-read 'utf-8))
        (apply orig args)))))

(use-package recentf
  :ensure nil
  :hook (dired-mode . my-recentf-add-dired-directory-h)
  :custom
  (recentf-save-file (concat nn-directory "recentf.eld"))
  (revert-without-query '("."))
  (recentf-max-saved-items 5)
  (recentf-auto-cleanup t)
  (recentf-auto-save-timer nil)
  (recentf-exclude
   '("\\.?cache" ".cask" "url" "COMMIT_EDITMSG\\'" "bookmarks"
     "\\.\\(?:gz\\|gif\\|svg\\|png\\|jpe?g\\|bmp\\|xpm\\)$"
     "\\.?ido\\.last$" "\\.revive$" "/G?TAGS$" "/.elfeed/"
     "^/tmp/" "^/var/folders/.$" "^/ssh:" "/persp-confs/"
     (lambda (file) (file-in-directory-p file package-user-dir))))
  :config
  (add-to-list 'recentf-keep '(derived-mode-p . dired-mode))
  (add-to-list 'recentf-filename-handlers #'substring-no-properties)

  (defun my-recentf-add-dired-directory-h ()
    "Add dired directories to recentf file list."
    (recentf-add-file default-directory))

  (defun my-recentf-touch-buffer-h ()
    "Bump file in recent file list when it is switched or written to."
    (when buffer-file-name
      (recentf-add-file buffer-file-name))
    nil))

(use-package autorevert
  :ensure nil
  :hook (nn-first-file . global-auto-revert-mode)
  :custom
  (auto-revert-verbose t)
  (auto-revert-use-notify t)
  (auto-revert-avoid-polling t)
  (auto-revert-stop-on-user-input nil))

(use-package comint
  :ensure nil
  :commands comint-truncate-buffer
  :custom
  (comint-buffer-maximum-size 2048)
  (comint-prompt-read-only t))

(use-package savehist
  :ensure nil
  :hook
  (nn-first-input . savehist-mode)
  (savehist-save . my-savehist-unpropertize-variables-h)
  (savehist-save . my-savehist-remove-unprintable-registers-h)
  :custom
  (save-place-file (concat nn-directory "saveplace.el"))
  (savehist-file (concat nn-directory "savehist.el"))
  (savehist-autosave-interval nil)
  (savehist-save-minibuffer-history t)
  (savehist-additional-variables
   '(kill-ring register-alist mark-ring global-mark-ring
     search-ring regexp-search-ring))
  :config
  (defun my-savehist-unpropertize-variables-h ()
    (setq kill-ring
          (mapcar #'substring-no-properties
                  (cl-remove-if-not #'stringp kill-ring))
          register-alist
          (cl-loop for (reg . item) in register-alist
                   if (stringp item)
                   collect (cons reg (substring-no-properties item))
                   else collect (cons reg item))))

  (defun my-savehist-remove-unprintable-registers-h ()
    (setq-local register-alist (cl-remove-if-not #'savehist-printable register-alist)))

  (define-advice save-place-find-file-hook (:after-while (&rest _) my-recenter)
    "Recenter on cursor when loading a saved place."
    (if buffer-file-name (ignore-errors (recenter))))

  (define-advice save-place-to-alist (:around (fn &rest args) my-inhibit-long-files)
    (unless (bound-and-true-p so-long-minor-mode)
      (apply fn args)))

  (define-advice save-place-find-file-hook (:before-while (&rest _) my-point-at-bol)
    "If something else has moved point, don't try to move it again."
    (bobp))

  (define-advice save-place-alist-to-file (:around (fn &rest args) my-no-pp)
    "`save-place-alist-to-file' uses `pp' to prettify the contents of its cache.
`pp' can be expensive for longer lists, and there's no reason to prettify cache
files, so this replace calls to `pp' with the much faster `prin1'."
    (cl-letf (((symbol-function 'pp) #'prin1))
      (apply fn args))))

(use-package repeat
  :ensure nil
  :hook nn-first-file
  :custom (repeat-echo-mode-line t))

(use-package uniquify
  :ensure nil
  :custom
  (uniquify-buffer-name-style 'forward)
  (uniquify-strip-common-suffix t)
  (uniquify-after-kill-buffer-flag t))

(use-package mwheel
  :ensure nil
  :custom
  (mouse-wheel-progressive-speed nil)
  (mouse-wheel-follow-mouse nil)
  (mouse-wheel-tilt-scroll nil)
  (mouse-wheel-scroll-amount '(2 ((shift) . 2) ((control) . text-scale))))

(use-package pixel-scroll
  :ensure nil
  :hook (nn-first-file . pixel-scroll-precision-mode)
  :custom
  (scroll-margin 0)
  (scroll-step 0)
  (scroll-conservatively 101)
  (scroll-preserve-screen-position t)
  (pixel-scroll-precision-use-momentum nil))

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
