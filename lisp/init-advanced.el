;;; -*- lexical-binding: t -*-
(use-package jit-lock
  :ensure nil
  :custom
  (jit-lock-defer-time 0)
  (jit-lock-stealth-time 0.5)
  (jit-lock-stealth-nice 0.5)
  (jit-lock-stealth-load 100)
  (jit-lock-chunk-size 1024))

(use-package eldoc
  :ensure nil
  :bind
  ("M-<return>" . eldoc-print-current-symbol-info)
  ("C-c h ." . my-eldoc-copy)
  :custom
  (eldoc-help-at-pt t)
  (eldoc-idle-delay 0.5)
  (eldoc-idle-delay-visible-only t)
  (eldoc-echo-area-use-multiline-p nil)
  (eldoc-documentation-strategy 'eldoc-documentation-enthusiast)
  :config
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
  (completions-format 'one-column)
  (completions-max-height 10)
  (completions-sort 'historical)
  (enable-recursive-minibuffers t)
  (read-buffer-completion-ignore-case t)
  (read-file-name-completion-ignore-case t)
  (minibuffer-visible-completions 'up-down)
  (minibuffer-prompt-properties
   '(read-only t intangible t cursor-intangible t face minibuffer-prompt))
  (minibuffer-depth-indicate-mode t)
  (minibuffer-electric-default-mode t))

(use-package wdired
  :ensure nil
  :commands (wdired-change-to-wdired-mode)
  :custom
  (wdired-allow-to-change-permissions t)
  (wdired-create-parent-directories t))

(use-package dired
  :ensure nil
  :commands dired-jump
  :bind
  (:map dired-mode-map
   ("-" . dired-create-empty-file)
   ("C-c C-e" . wdired-change-to-wdired-mode))
  :hook (dired-after-readin . my-dired-vc-ignores)
  :custom
  (dired-dwim-target t)
  (dired-mouse-drag-files t)
  (dired-auto-revert-buffer #'dired-buffer-stale-p)
  (dired-recursive-deletes 'top)
  (dired-recursive-copies 'always)
  (dired-create-destination-dirs 'always)
  (dired-no-confirm '(move copy delete))
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-listing-switches "-alh --group-directories-first")
  :config
  (put 'dired-find-alternate-file 'disabled nil)

  (define-advice dired-buffer-stale-p (:before-while (&rest args)
                                       my-dired--no-revert-in-virtual-buffers-a)
    "Don't auto-revert in dired-virtual buffers (see `dired-virtual-revert')."
    (not (eq revert-buffer-function #'dired-virtual-revert)))

  ;; git ignore face
  (defun my-dired-vc-ignores ()
    (when-let* ((root (vc-root-dir))
                (backend (vc-responsible-backend root))
                (ignores (vc-call-backend
                          backend
                          'ignore-completion-table default-directory))
                (pattern (concat "\\=\\(" (regexp-opt ignores)
                                 "\\)\\(?:$\\|\\s-\\)")))
      (font-lock-add-keywords
       nil
       `((,dired-move-to-filename-regexp
          (,pattern (dired-move-to-filename) nil (1 'dired-ignored t))))
       'add-to-end))))

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
                   ((eq system-type 'windows-nt) "start")
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
     ("\\.zip\\'" . "7z a -r %o  %i"))
   (dired-compress-files-alist
    '(("\\.7z\\'" . "7z a -r %o %i")
      ("\\.zip\\'" . "7z a -r %o  %i")))
   (dired-compress-directory-default-suffix ".7z")
   (dired-compress-file-default-suffix ".7z"))
  :config
  ;; The w32 subprocess argv is limited to the ANSI code page (src/w32proc.c
  ;; sys_spawnve treats argv as ANSI bytes), while MSYS2 ls outputs UTF-8.
  ;; files.el's insert-directory uses file-name-coding-system for both sides,
  ;; but a single global setting cannot satisfy both:
  ;; - argv side (files.el:8426-8429) encodes argv via file-name-coding-system
  ;;   → must be ANSI code page (cp936), or non-ASCII paths mangle at CreateProcessA;
  ;; - output side (files.el:8518-8521) uses coding-system-for-read first
  ;;   → must be utf-8 to correctly decode MSYS2 ls output.
  ;; We dynamically bind coding-system-for-read to utf-8 only within this call,
  ;; leaving the global file-name-coding-system unchanged (cp936).
  (when (and ls-lisp-use-insert-directory-program
             (eq system-type 'windows-nt))
    (define-advice insert-directory (:around (orig &rest args) w32-msys-ls)
      "Pass ANSI-codepage argv to `insert-directory-program', decode its UTF-8 output."
      (let ((file-name-coding-system (intern (format "cp%d" w32-ansi-code-page)))
            (coding-system-for-read 'utf-8))
        (apply orig args)))))

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
  (("C-|" . nn-speedbar-toggle)
   :map speedbar-mode-map
   ("q" . nn-speedbar-close))
  :custom
  (speedbar-use-images nil)
  (speedbar-use-imenu-flag nil)
  (speedbar-use-tool-tips-flag nil)
  (speedbar-hide-button-brackets-flag t)
  (speedbar-mode-specific-contents-flag nil)
  (speedbar-mode-functions-list nil)
  (speedbar-dynamic-tags-function-list nil)
  (speedbar-special-mode-expansion-list nil)
  (speedbar-show-unknown-files t)
  (speedbar-smart-directory-expand-flag t)
  (speedbar-verbosity-level 0)
  (speedbar-directory-unshown-regexp "^\\(\\.\\.*$\\)")
  :config
  (defvar nn-speedbar-width 30)
  (defvar nn-speedbar-split-style 'right)

  (when (>= emacs-major-version 31)
    (setq speedbar-prefer-window t
          speedbar--window-width nn-speedbar-width
          speedbar-window-side nn-speedbar-split-style)

    (defun nn-speedbar-toggle ()
      "Toggle speedbar window (Emacs 31+ native version)."
      (interactive)
      (speedbar))

    (defun nn-speedbar-close()
      (interactive)
      (delete-window)))

  (when (< emacs-major-version 31)
    (defvar nn-speedbar-window nil)

    (defun nn-speedbar-toggle ()
      "Toggle speedbar window (Custom implementation for Emacs 30 and earlier)."
      (interactive)
      (if (nn-speedbar-exist-p)
          (nn-speedbar-close)
        (nn-speedbar-open)))

    (defun nn-speedbar-exist-p ()
      "Check if speedbar window exists."
      (and nn-speedbar-window
           (window-live-p nn-speedbar-window)
           (buffer-live-p (window-buffer nn-speedbar-window))))

    (defun nn-speedbar-open ()
      "Open speedbar on left side."
      (let ((current-window (selected-window))
            (speedbar-buf (get-buffer-create "*speedbar*")))
        (select-window (split-window current-window (- nn-speedbar-width) nn-speedbar-split-style))
        (setq nn-speedbar-window (selected-window))
        (switch-to-buffer speedbar-buf)
        (setq speedbar-frame (selected-frame)
              speedbar-buffer speedbar-buf
              dframe-attached-frame (selected-frame)
              speedbar-verbosity-level 0)
        (speedbar-mode)
        (speedbar-reconfigure-keymaps)
        (speedbar-update-contents)
        (speedbar-set-timer 1)
        (display-line-numbers-mode -1)
        (set-window-dedicated-p nn-speedbar-window t)
        (select-window current-window)))

    (defun nn-speedbar-close ()
      "Close speedbar window."
      (interactive)
      (if (nn-speedbar-exist-p)
          (let ((current-window (selected-window)))
            (select-window nn-speedbar-window)
            (set-window-dedicated-p nn-speedbar-window nil)
            (delete-window nn-speedbar-window)
            (setq nn-speedbar-window nil)
            (if (window-live-p current-window)
                (select-window current-window)))
        (message "Speedbar window does not exist.")))

    (defun nn-speedbar-kill-buffer-task ()
      (when (bound-and-true-p speedbar-buffer)
        (when (eq (current-buffer) speedbar-buffer)
          (setq speedbar-frame nil
                dframe-attached-frame nil
                speedbar-buffer nil)
          (speedbar-set-timer nil)
          (setq nn-speedbar-window nil))))

    (defun nn-speedbar-select-mru-window ()
      "Select the most recently used window."
      (select-window (get-mru-window)))

    (add-hook 'speedbar-before-visiting-file-hook #'nn-speedbar-select-mru-window)
    (add-hook 'speedbar-before-visiting-tag-hook #'nn-speedbar-select-mru-window)
    (add-hook 'speedbar-visiting-file-hook #'nn-speedbar-select-mru-window)
    (add-hook 'speedbar-visiting-tag-hook #'nn-speedbar-select-mru-window)
    (add-hook 'kill-buffer-hook #'nn-speedbar-kill-buffer-task)))

(use-package compile
  :ensure nil
  :hook (compilation-filter . ansi-color-compilation-filter)
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
     1 2 (4) (5))))

(use-package comint
  :ensure nil
  :custom
  (comint-buffer-maximum-size 2048)
  (comint-prompt-read-only t))

(use-package isearch
  :ensure nil
  :bind
  (:map isearch-mode-map
   ([remap isearch-delete-char] . isearch-del-char))
  :custom
  (isearch-lazy-highlight t)
  (isearch-wrap-pause t)
  (isearch-allow-motion t)
  (isearch-motion-changes-direction t)
  (isearch-lazy-count t)
  (lazy-highlight-cleanup t)
  (lazy-count-prefix-format "%s/%s ")
  :config
  (defvar my-isearch--direction nil)
  (define-advice isearch-exit (:after nil)
    (setq-local my-isearch--direction nil))
  (define-advice isearch-repeat-forward (:after (_))
    (setq-local my-isearch--direction 'forward))
  (define-advice isearch-repeat-backward (:after (_))
    (setq-local my-isearch--direction 'backward)))

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
      ("Telega" (or
                 (mode . telega-root-mode)
                 (mode . telega-chat-mode)))
      ("Mail" (or (derived-mode . message-mode)
                  (name . "\\`\\*\\(Gnus\\|gnus\\|Article\\|Summary\\|Group\\|mail\\|message\\)")))
      ("Document" (name . "\\.\\(md\\|markdown\\|org\\|adoc\\|tex\\|pdf\\|rst\\|txt\\)$"))
      ("VC" (or (name . "\\*vc-")))
      ("LLM" (or (mode . gptel-mode)
                 (mode . gptel-chat-mode)))
      ("LSP" (or (name . "\\`\\*\\(EGLOT\\|eldoc\\|LSP\\|lsp-help\\|Flymake\\)")
                 (derived-mode . eglot--managed-mode)))
      ("Debug" (or (derived-mode . special-mode)
                   (name . "\\`\\*\\(Backtrace\\|debug\\|Messages\\|Warnings\\|Compile-Log\\|gud-\\|dap-\\)")
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

(provide 'init-advanced)
