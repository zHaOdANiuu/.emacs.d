;;; -*- lexical-binding: t -*-
(use-package jit-lock
  :ensure nil
  :custom
  (jit-lock-defer-time 0)
  (jit-lock-stealth-time 0.5)
  (jit-lock-stealth-nice 0.5)
  (jit-lock-stealth-load 100)
  (jit-lock-chunk-size 1024))

(use-package project
  :ensure nil
  :custom
  (project-list-file (concat nn-directory "project-list.el"))
  (project-vc-ignores
   '("node_modules" ".git" ".svn" "vendor" "dist" "build"
     ".cache" ".tox" "__pycache__" "target" "out"))
  (project-vc-extra-root-markers
   '("Cargo.toml" "package.json" "go.mod" "*.asd"))
  (project-vc-include-untracked t)
  (project-vc-merge-submodules nil)
  (project-files-relative-names t)
  (project-search-function #'project-ripgrep))

(use-package mule
  :ensure nil
  :config
  (set-charset-priority 'unicode)
  (set-default-coding-systems 'utf-8-unix)
  (set-locale-environment "en_US.UTF-8")
  (set-clipboard-coding-system (if _WIN32 'utf-16-le 'utf-8-unix)))

(use-package simple
  :ensure nil
  :custom
  (indent-tabs-mode nil)
  (idle-update-delay 0.5)
  (kill-whole-line t)
  (kill-region-dwim t)
  (kill-do-not-save-duplicates t)
  (set-mark-command-repeat-pop t)
  (save-interprogram-paste-before-kill t)
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
  (require-final-newline t)
  (insert-directory-program (executable-find "ls")))

(use-package ls-lisp
  :ensure nil
  :custom
  (ls-lisp-use-insert-directory-program (when insert-directory-program t))
  (ls-lisp-emulation 'UNIX)
  (ls-lisp-use-string-collate nil)
  (ls-lisp-use-localized-time-format t)
  (ls-lisp-support-symlinks t)
  (ls-lisp-dirs-first t)
  (ls-lisp-verbosity '(links uid modes))
  :config
  (when (and ls-lisp-use-insert-directory-program
             _WIN32)
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
  :hook (prog-mode . auto-revert-mode)
  :custom
  (auto-revert-verbose t)
  (auto-revert-use-notify t)
  (auto-revert-avoid-polling t)
  (auto-revert-stop-on-user-input nil)
  :config (remove-hook 'find-file-hook #'auto-revert--global-adopt-current-buffer))

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

(use-package saveplace
  :ensure nil
  :hook (nn-first-file-hook . save-place-mode))

(use-package comint
  :ensure nil
  :commands comint-truncate-buffer
  :custom
  (comint-buffer-maximum-size 2048)
  (comint-prompt-read-only t))

(use-package ffap
  :ensure nil
  :custom (ffap-machine-p-known 'accept))

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
  (pixel-scroll-precision-use-momentum t)
  (pixel-scroll-precision-interpolate-page t))

(use-package frame
  :ensure nil
  :hook (window-configuration-change . my-update-window-divider-bottom)
  :init
  (blink-cursor-mode -1)
  (window-divider-mode 1)
  :custom
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
            (and (not (= first ?*))
                 (not (memq (buffer-local-value 'major-mode buf)
                            '(dired-mode org-agenda-mode))) )))))
  (set-frame-parameter nil 'buffer-predicate #'my-buffer-predicate))

(use-package window
  :ensure nil
  :custom
  (split-width-threshold 160)
  (split-height-threshold nil)
  (window-resize-pixelwise t)
  (window-combination-resize t)
  (switch-to-buffer-obey-display-actions t)
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
     ("\\*eldoc"
      (display-buffer-in-side-window)
      (window-height . 0.35)
      (side . bottom)
      (slot . 1))
     ("\\*\\(Flymake diagnostics\\)\\*"
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

(use-package eldoc
  :ensure nil
  :bind
  ("C-c h ." . my-eldoc-copy)
  ("M-<return>" . eldoc-print-current-symbol-info)
  :custom (eldoc-documentation-strategy 'eldoc-documentation-enthusiast)
  :config
  (global-eldoc-mode -1)
  (defun my-eldoc-copy ()
    (interactive)
    (when-let* ((buf (eldoc-doc-buffer)))
      (kill-new (with-current-buffer buf (buffer-string)))
      (message "Copied eldoc to kill ring"))))

(use-package minibuffer
  :ensure nil
  :bind ("C-<return>" . completion-at-point)
  :hook (minibuffer-setup . cursor-intangible-mode)
  :custom
  (completion-auto-help t)
  (completion-auto-select t)
  (completion-eager-update t)
  (completion-eager-display nil)
  (completion-ignore-case t)
  (completion-show-help t)
  (completion-styles '(partial-completion flex initials))
  (completions-max-height 10)
  (completions-format 'one-column)
  (completions-sort 'historical)
  (enable-recursive-minibuffers t)
  (read-buffer-completion-ignore-case t)
  (read-file-name-completion-ignore-case t)
  (minibuffer-visible-completions 'up-down)
  (minibuffer-prompt-properties
   '(read-only t intangible t cursor-intangible t face minibuffer-prompt))
  :config
  (minibuffer-depth-indicate-mode 1)
  (minibuffer-electric-default-mode 1))

(use-package help
  :ensure nil
  :custom
  (help-window-select t)
  (view-lossage-auto-refresh t))

(use-package help-mode
  :ensure nil
  :hook
  (help-mode . visual-line-mode)
  (help-mode . cursor-sensor-mode)
  :bind (:map help-mode-map ("r" . my-remove-hook-at-point))
  :config
  (defun my-function-advices (function)
    "Return FUNCTION's advices."
    (let ((flist (indirect-function function)) advices)
      (while (advice--p flist)
        (setq advices `(,@advices ,(advice--car flist)))
        (setq flist (advice--cdr flist)))
      advices))

  (defun my-help--update ()
    "Update the help buffer."
    (if (eq major-mode 'helpful-mode)
        (helpful-update)
      (revert-buffer nil t)))

  (defun my-add-remove-advice-button (advice function)
    (when (and (functionp advice) (functionp function))
      (let ((inhibit-read-only t)
            (msg (format "Remove advice `%s'" advice)))
        (insert "\t")
        (insert-button
         "Remove"
         'face 'custom-button
         'cursor-sensor-functions `((lambda (&rest _) ,msg))
         'help-echo msg
         'action (lambda (_)
                   (when (yes-or-no-p msg)
                     (message "%s from function `%s'" msg function)
                     (advice-remove function advice)
                     (my-help--update)))
         'follow-link t))))

  (defun my-add-button-to-remove-advice (buffer-or-name function)
    "Add a button to remove advice."
    (with-current-buffer buffer-or-name
      (save-excursion
        (goto-char (point-min))
        (let ((ad-list (my-function-advices function)))
          (while (re-search-forward "^\\(?:This function has \\)?:[-a-z]+ advice: \\(.+\\)$" nil t)
            (let ((advice (car ad-list)))
              (my-add-remove-advice-button advice function)
              (setq ad-list (delq advice ad-list))))))))

  (defun my-remove-hook-at-point ()
    "Remove the hook at the point in the *Help* buffer."
    (interactive)
    (unless (memq major-mode '(help-mode helpful-mode))
      (error "Only for help-mode or helpful-mode"))
    (let ((orig-point (point)))
      (save-excursion
        (when-let*
            ((hook (progn (goto-char (point-min)) (symbol-at-point)))
             (func
              (when (and
                     (or (re-search-forward (format "^Value:?[\s|\n]") nil t)
                         (goto-char orig-point))
                     (thing-at-point 'sexp))
                (thing-at-point--end-of-sexp)
                (backward-char 1)
                (catch 'break
                  (while t
                    (condition-case _err
                        (backward-sexp)
                      (scan-error (throw 'break nil)))
                    (let ((bounds (bounds-of-thing-at-point 'sexp)))
                      (when (<= (car bounds) orig-point (cdr bounds))
                        (throw 'break (thing-at-point 'sexp)))))))))
          (when (yes-or-no-p (format "Remove %s from %s? " func hook))
            (remove-hook hook (intern func))
            (my-help--update))))))

  (define-advice describe-function-1 (:after (f) my-advice-remove-button)
    (my-add-button-to-remove-advice (help-buffer) f))

  (define-advice helpful-update (:after () my-advice-remove-button)
    (when helpful--callable-p
      (my-add-button-to-remove-advice (current-buffer) helpful--sym))))

(use-package wdired
  :ensure nil
  :commands wdired-change-to-wdired-mode
  :bind
  (:map wdired-mode-map
   ("<escape>" . wdired-exit)
   ("<return>" . wdired-finish-edit))
  :custom
  (wdired-allow-to-change-permissions t)
  (wdired-create-parent-directories t))

(use-package dired
  :ensure nil
  :commands dired-jump
  :bind
  (:map dired-mode-map
   ("e" . dired-toggle-read-only)
   ("-" . dired-create-empty-file)
   ("C-c C-e" . wdired-change-to-wdired-mode)
   ([remap dired-do-open] . nn-open-in-external-app))
  :hook (dired-after-readin . my-dired-ignores)
  :custom
  (shell-command-guess-open nil)
  (dired-chown-program (not _WIN32))
  (dired-dwim-target t)
  (dired-mouse-drag-files t)
  (dired-auto-revert-buffer #'dired-buffer-stale-p)
  (dired-recursive-deletes 'top)
  (dired-recursive-copies 'always)
  (dired-create-destination-dirs 'always)
  (dired-no-confirm '(move copy delete))
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-isearch-filenames 'dwim)
  (dired-listing-switches "-alh --group-directories-first")
  :config
  (put 'dired-find-alternate-file 'disabled nil)

  (define-advice dired-buffer-stale-p (:before-while (&rest args)
                                       my-dired--no-revert-in-virtual-buffers-a)
    "Don't auto-revert in dired-virtual buffers (see `dired-virtual-revert')."
    (not (eq revert-buffer-function #'dired-virtual-revert)))

  (defun my-dired-ignores-get-cur-dir (root subdir)
    (mapcar
     #'directory-file-name
     (split-string
      (shell-command-to-string
       (format
        "git -C %s ls-files -zoi --exclude-standard --directory -- %s"
        root subdir))
      "\0" t)))

  (defun my-dired-ignores ()
    (when-let* ((root (vc-root-dir)))
      (font-lock-add-keywords
       nil
       `((,(regexp-opt
            (my-dired-ignores-get-cur-dir
             root (file-relative-name default-directory root)))
          . 'dired-ignored))))))

(use-package dired-x
  :ensure nil
  :hook (dired-mode . dired-omit-mode)
  :custom
  (dired-omit-verbose nil)
  (dired-omit-extensions nil)
  (dired-omit-files
   (concat
    "^#"
    "\\|^\\.#"
    "\\|^desktop\\.ini\\'"
    "\\|^Thumbs\\.db\\'"
    "\\|^System Volume Information\\'"
    "\\|^\\$RECYCLE\\.BIN\\'"
    "\\|^ntuser\\."
    "\\|^\\.DS_Store\\'"))
  :config
  (let ((cmd (cond ((eq system-type 'darwin) "open")
                   ((eq system-type 'gnu/linux) "xdg-open")
                   (_WIN32 "start")
                   (t ""))))
    (setq dired-guess-shell-alist-user
          `(("\\.pdf\\'" ,cmd)
            ("\\.docx\\'" ,cmd)
            ("\\.\\(?:djvu\\|eps\\)\\'" ,cmd)
            ("\\.\\(?:jpg\\|jpeg\\|png\\|gif\\|xpm\\)\\'" ,cmd)
            ("\\.\\(?:xcf\\)\\'" ,cmd)
            ("\\.csv\\'" ,cmd)
            ("\\.tex\\'" ,cmd)
            ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'" ,cmd)
            ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
            ("\\.html?\\'" ,cmd)
            ("\\.md\\'" ,cmd)))))

(use-package dired-aux
  :ensure nil
  :custom
  (dired-vc-rename-file t)
  (dired-create-destination-dirs 'ask)
  (dired-compress-file-alist
   '(("\\.7z\\'" . "7z a -r %o %i")
     ("\\.zip\\'" . "7z a -r %o  %i")))
  (dired-compress-files-alist
   '(("\\.7z\\'" . "7z a -r %o %i")
     ("\\.zip\\'" . "7z a -r %o  %i")))
  (dired-compress-directory-default-suffix ".7z")
  (dired-compress-file-default-suffix ".7z"))

(use-package image-dired
  :ensure nil
  :custom
  (image-dired-dir (expand-file-name "image-dired/" nn-directory))
  (image-dired-db-file (expand-file-name "image-dired/db.el" nn-directory))
  (image-dired-gallery-dir (expand-file-name "image-dired/gallery/" nn-directory))
  (image-dired-temp-image-file (expand-file-name "image-dired/temp-image" nn-directory))
  (image-dired-temp-rotate-image-file (expand-file-name "image-dired/temp-rotate-image" nn-directory))
  (image-dired-thumb-size 150)
  :config
  (make-directory (expand-file-name "image-dired/gallery/" nn-directory) t)
  (add-to-list
   'display-buffer-alist
   '("^\\*image-dired"
     (display-buffer-in-side-window)
     (side . bottom)
     (slot . 20)
     (window-width . 0.8))))

(use-package speedbar
  :ensure nil
  :bind
  (("C-|" . speedbar-window)
   :map speedbar-mode-map
   ("q" . delete-window))
  :custom
  (speedbar-window-side 'right)
  (speedbar-window-default-width 30)
  (speedbar-vc-do-check nil)
  (speedbar-obj-do-check nil)
  (speedbar-use-images nil)
  (speedbar-use-imenu-flag nil)
  (speedbar-use-tool-tips-flag nil)
  (speedbar-hide-button-brackets-flag t)
  (speedbar-mode-functions-list nil)
  (speedbar-mode-specific-contents-flag nil)
  (speedbar-dynamic-tags-function-list nil)
  (speedbar-special-mode-expansion-list nil)
  (speedbar-show-unknown-files t)
  (speedbar-smart-directory-expand-flag nil)
  (speedbar-verbosity-level 0)
  (speedbar-directory-unshown-regexp "^\\(\\.\\.*$\\)"))

(use-package compile
  :ensure nil
  :hook
  (compilation-filter . ansi-color-compilation-filter)
  (compilation-filter . nn-comint-truncate-buffer-h)
  :bind
  (("C-c c" . compile)
   :map compilation-mode-map
   ("r" . compile)
   ("C-c C-k" . delete-process))
  :custom
  (compile-command "")
  (compilation-always-kill t)
  (compilation-ask-about-save nil)
  (compilation-max-output-line-length nil)
  (compilation-scroll-output 'first-error)
  (compilation-window-height 12)
  (compilation-skip-threshold 1)
  (compilation-transform-file-name-alist nil)
  :config
  (add-to-list
   'compilation-error-regexp-alist
   '("\\([a-zA-Z0-9\\.]+\\)(\\([0-9]+\\)\\(,\\([0-9]+\\)\\)?) \\(Warning:\\)?"
     1 2 (4) (5)))

  (defun nn-comint-truncate-buffer-h (&optional _string)
    "Rate-limit `comint-truncate-buffer' in compilation-mode buffers."
    (if (> (buffer-size)
           ;; HACK: Approximate this because counting lines is prohibitively
           ;;   expensive in longer buffers, especially in
           ;;   `compilation-filter-hook' which fires rapidly.
           (* 80 comint-buffer-maximum-size))
        (let ((gc-cons-threshold most-positive-fixnum)
              (gc-cons-percentage 1.0))
          (with-silent-modifications
            (comint-truncate-buffer))))))

(use-package isearch
  :ensure nil
  :bind
  (:map isearch-mode-map
   ([remap isearch-delete-char] . isearch-del-char))
  :custom
  (lazy-highlight-cleanup t)
  (lazy-count-prefix-format "%s/%s ")
  (lazy-count-suffix-format nil)
  (search-whitespace-regexp ".*?")
  (isearch-lazy-count t)
  (isearch-lazy-highlight t)
  (isearch-wrap-pause nil)
  (isearch-allow-motion t)
  (isearch-motion-changes-direction t))

(use-package ibuffer
  :ensure nil
  :bind ("C-x C-b" . ibuffer)
  :hook (ibuffer-mode . (lambda () (ibuffer-switch-to-saved-filter-groups "main")))
  :custom
  (ibuffer-expert t)
  (ibuffer-display-summary nil)
  (ibuffer-use-other-window nil)
  (ibuffer-show-empty-filter-groups nil)
  (ibuffer-default-sorting-mode 'filename/process)
  (ibuffer-title-face 'font-lock-doc-face)
  (ibuffer-use-header-line t)
  (ibuffer-default-shrink-to-minimum-size nil)
  (ibuffer-formats
   '((mark " " (name 16 -1) " " filename)
     (mark modified read-only " "
           (name 18 18 :left :elide) " "
           (size 9 -1 :right) " "
           (mode 16 16 :left :elide) " "
           filename-and-process)))
  (ibuffer-saved-filter-groups
   '(("main"
      ("C/C++" (name . "\\.\\(c\\|cpp\\|cc\\|h\\|hpp\\|cppm\\|ixx\\)$"))
      ("Scripts" (name . "\\.\\(sh\\|lua\\|bat\\|cmd\\|ps1\\|py\\|pl\\)$"))
      ("Web" (or (name . "\\.\\(html?\\|xml\\|css\\|s[ac]ss\\|less\\|jsx?\\|tsx?\\|json\\|md\\)$")))
      ("Config" (or (name . "\\.\\(toml\\|ya?ml\\|ini\\|cfg\\|conf\\|gitignore\\)$")
                    (name . "^\\.clangd$")
                    (name . "^Doxyfile$")
                    (name . "^config\\.toml$")))
      ("Assets" (or (name . "\\.\\(png\\|jpe?g\\|svg\\|webp\\|bpm\\|ppm\\|mp[34]\\|mov\\|avi\\|obj\\)$")))
      ("News" (name . "^\\*Newsticker.*"))
      ("Gnus" (or
               (mode . gnus-server-mode)
               (mode . gnus-group-mode)
               (mode . gnus-summary-mode)
               (mode . gnus-article-mode)
               (name . "^\\.newsrc-dribble")
               (name . "^\\*Gnus Browse Server\\*")
               (name . "^\\*Group\\*")
               (name . "^\\*Summary\\*")
               (name . "^\\*Article\\*")
               (name . "^\\*BBDB\\*")))
      ("Chat" (or (mode . telega-root-mode)
                  (mode . telega-chat-mode)
                  (mode . rcirc-mode)
                  (mode . erc-mode)
                  (name . "^\\*rcirc.*")
                  (name . "^\\*ERC.*")))
      ("Document" (name . "\\.\\(md\\|markdown\\|org\\|adoc\\|tex\\|pdf\\|rst\\|txt\\)$"))
      ("VC" (name . "\\*vc-"))
      ("Magit" (or (name . "\\*magit")
                   (name . "COMMIT_EDITMSG")))
      ("LSP" (or (name . "\\`\\*\\(EGLOT\\|eldoc\\|LSP\\|lsp-help\\|Flymake\\)")
                 (derived-mode . eglot--managed-mode)))
      ("Debug" (or (name . "\\`\\*\\(Backtrace\\|debug\\|Messages\\|Warnings\\|Compile-Log\\|gud-\\|dap-\\)")
                   (mode . debugger-mode)
                   (mode . gdb-mi-mode)))
      ("Compile/Shell" (or (derived-mode . comint-mode)
                           (name . "\\`\\*\\(compilation\\|Async Shell Command\\)")))
      ("Dired" (mode . dired-mode))
      ("Emacs" (or (derived-mode . emacs-lisp-mode)
                   (name . "\\`\\*\\(Help\\|Custom\\|info\\|scratch\\)"))))))
  :config
  (define-ibuffer-column size
    (:name "Size" :inline t :header-mouse-map ibuffer-size-header-map)
    (file-size-human-readable (buffer-size))))

(provide 'init-builtin)
