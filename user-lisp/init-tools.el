;;; -*- lexical-binding: t -*-

;; Info & Help

(use-package proced
  :ensure nil
  :custom
  (proced-enable-color-flag t)
  (proced-tree-flag t)
  (proced-auto-update-flag 'visible)
  (proced-auto-update-interval 1)
  (proced-descend t)
  (proced-format 'medium)
  (proced-filter 'user))

(use-package man
  :ensure nil
  :commands man
  :custom (Man-notify-method 'pushy))

(use-package webjump
  :ensure nil
  :bind ("C-c /" . my-webjump-eww)
  :custom
  (webjump-sites
   '(("DuckDuckGo"     . [simple-query "https://www.duckduckgo.com"
                                       "https://www.duckduckgo.com/?q=" ""])
     ("DuckDuckAI"     . [simple-query "https://duck.ai" "https://duck.ai/?q=" ""])
     ("DuckDuckGoImg"  . [simple-query "https://www.duckduckgo.com"
                                       "https://www.duckduckgo.com/?iar=images&q=" ""])
     ("Bing"           . [simple-query "https://www.bing.com"
                                       "https://www.bing.com/search?q=" ""])
     ("Google"         . [simple-query "https://www.google.com"
                                       "https://www.google.com/search?q=" ""])
     ("YouTube"        . [simple-query "https://www.youtube.com/feed/subscriptions"
                                       "https://www.youtube.com/results?search_query=" ""])
     ("Wikipedia"      . [simple-query "https://wikipedia.org"
                                       "https://wikipedia.org/wiki/" ""])))
  :init
  (defun my-webjump-eww ()
    (interactive)
    (require 'eww)
    (call-interactively #'webjump)))

(use-package bookmark
  :ensure nil
  :custom (bookmark-default-file (concat nn-directory "bookmark-default.el"))
  :config
  (define-advice bookmark-bmenu--revert (:after (&rest _) my-bookmark-bmenu--icons)
    "Prepend nerd-icons to bookmark names."
    (when (display-graphic-p)
      (dolist (entry tabulated-list-entries)
        (let* ((rec (car entry))
               (row (cadr entry))
               (loc (bookmark-get-filename rec))
               (file (and (stringp loc)
                          (not (string-empty-p loc))
                          (file-name-nondirectory loc)))
               (icon (cond ((not loc) nil)
                           ((file-remote-p loc)
                            (nerd-icons-codicon "nf-cod-radio_tower"))
                           ((file-directory-p loc)
                            (nerd-icons-icon-for-dir loc))
                           ((and file (not (string-empty-p file)))
                            (nerd-icons-icon-for-file file))))
               (idx (if bookmark-bmenu-toggle-filenames 1 0)))
          (when icon
            (setf (elt row idx)
                  (concat icon "  " (elt row idx))))))
      (tabulated-list-print t))))


;; Search

(use-package wgrep
  :custom
  (wgrep-auto-save-buffer t)
  (wgrep-change-readonly-file t))

(use-package rg
  :commands rg
  :hook (rg-mode . (lambda () (setq-local compilation-insert-header-function #'ignore)))
  :bind
  (("C-c s" . my-rg-current-dir-all)
   ("C-c C-s" . rg-menu)
   :map rg-global-map
   ("c" . rg-dwim-current-dir)
   ("f" . rg-dwim-current-file)
   ("m" . rg-menu))
  :custom (rg-keymap-prefix nil)
  :config
  (defun my-rg-current-dir-all (query)
    "Search QUERY in all files under current directory."
    (interactive "sSearch: ")
    (rg-literal query "*" default-directory)))


;; Date

(use-package calfw
  :custom
  (calfw-fchar-junction ?╋)
  (calfw-fchar-vertical-line ?┃)
  (calfw-fchar-horizontal-line ?━)
  (calfw-fchar-left-junction ?┣)
  (calfw-fchar-right-junction ?┫)
  (calfw-fchar-top-junction ?┯)
  (calfw-fchar-top-left-corner ?┏)
  (calfw-fchar-top-right-corner ?┓)
  (calfw-show-holidays nil))

(use-package calfw-org
  :commands calfw-org-open-calendar
  :bind ("C-c C-c" . my-calfw-open)
  :config
  (defun my-calfw-open ()
    (interactive)
    (calfw-org-open-calendar)
    (text-scale-set -1)
    (calfw-refresh-calendar-buffer)))


;; Version Control

(use-package vc
  :ensure nil
  :custom
  (vc-follow-symlinks t)
  (vc-handled-backends '(Git))
  (vc-git-program (executable-find "git"))
  (vc-ignore-dir-regexp
   (format "%s\\|%s"
           locate-dominating-stop-dir-regexp
           "[/\\\\]node_modules")))

(use-package vc-dir
  :ensure nil
  :bind
  (:map vc-dir-mode-map
   ("c" . vc-next-action)
   ("f" . vc-pull)
   ("<return>" . vc-diff))
  :hook (vc-dir-refresh . my-vc-dir-hide-dirs)
  :config
  (defun my-vc-dir-hide-dirs ()
    (when (and (boundp 'vc-ewoc) vc-ewoc)
      (ewoc-filter vc-ewoc (lambda (i) (not (vc-dir-fileinfo->directory i)))))))

(use-package diff-mode
  :ensure nil
  :hook (diff-mode . outline-minor-mode)
  :custom
  (diff-refine nil)
  (diff-default-read-only t)
  (diff-advance-after-apply-hunk t)
  (diff-update-on-the-fly t)
  (diff-font-lock-syntax 'hunk-also)
  (diff-font-lock-prettify nil))

(use-package ediff
  :ensure nil
  :commands ediff-buffers ediff-files ediff-buffers3 ediff-files3
  :hook
  (ediff-quit . tab-bar-history-back)
  (ediff-prepare-buffer . outline-show-all)
  (ediff-before-setup . my-ediff-save-wconf-h)
  ((ediff-quit ediff-suspend) . my-ediff-restore-wconf-h)
  :custom
  (ediff-diff-options "-w")
  (ediff-keep-variants nil)
  (ediff-make-buffers-readonly-at-startup nil)
  (ediff-show-clashes-only t)
  (ediff-window-setup-function #'ediff-setup-windows-plain)
  (ediff-split-window-function #'split-window-horizontally)
  (ediff-merge-split-window-function #'split-window-horizontally)
  :config
  (defvar my--ediff-saved-wconf nil)
  ;; Restore window config after quitting ediff
  (defun my-ediff-save-wconf-h ()
    (setq my--ediff-saved-wconf (current-window-configuration)))

  (defun my-ediff-restore-wconf-h ()
    (when (window-configuration-p my--ediff-saved-wconf)
      (set-window-configuration my--ediff-saved-wconf))))

(use-package smerge-mode
  :ensure nil
  :hook (find-file . my-init-smerge-mode-h)
  :config
  (defun my-init-smerge-mode-h ()
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^<<<<<<< " nil t) (smerge-mode 1)))))

(use-package magit
  :bind ("C-c g l" . magit-log-buffer-file)
  :hook
  (git-commit-setup . (lambda () (setq fill-column git-commit-summary-max-length)))
  ;; HACK: See magit/magit#5320: large/long status buffers can change the
  ;;   behavior of motions and TAB in obscure ways.
  ;; REVIEW: REmove when magit/magit#5320 is addressed.
  (magit-status-mode . (lambda () (setq-local long-line-threshold nil)))
  (magit-diff-visit-file . my-magit-reveal-point-if-invisible-h)
  :init
  (magit-auto-revert-mode -1)
  (setq with-editor-emacsclient-executable (executable-find "emacsclient"))
  :custom
  (git-commit-major-mode 'git-commit-elisp-text-mode)
  (magit-commit-show-diff nil)
  (magit-commit-ask-to-stage nil)
  (magit-log-section-commit-count 5)
  (magit-process-connection-type nil)
  (magit-refresh-verbose nil)
  (magit-refresh-status-buffer nil)
  (magit-revision-insert-related-refs nil)
  (magit-save-repository-buffers nil)
  (magit-uniquify-buffer-names nil)
  (magit-no-confirm '(stage-all-changes unstage-all-changes))
  (magit-run-hooks-from-githooks (not _WIN32))
  ;; (magit-status-headers-hook
  ;;  '(magit-insert-error-header
  ;;    magit-insert-head-branch-header
  ;;    ))
  (magit-status-sections-hook
   '(magit-insert-error-header
     magit-insert-untracked-files
     magit-insert-unstaged-changes
     magit-insert-staged-changes
     magit-insert-recent-commits))
  :config
  (require 'reveal)

  (defun my-magit-reveal-point-if-invisible-h ()
    "Reveal the point if in an invisible region."
    (reveal-post-command))

  (transient-append-suffix 'magit-fetch "-t"
    '("-d" "Depth 1" "--depth=1")))

(use-package magit-fast
  :vc (:url "https://github.com/zHaOdANiuu/magit-fast" :rev :newest)
  :after magit
  :bind
  (:map magit-status-mode-map
   ("<return>" . my-magit-fast-diff))
  :init
  (remove-hook 'server-switch-hook 'magit-commit-diff)
  (remove-hook 'magit-pre-start-git-hook #'magit-maybe-save-repository-buffers)
  (magit-fast-mode)

  (defun my-magit-fast-diff ()
    (interactive)
    (when-let* ((file (magit-file-at-point)))
      (magit-diff-dwim nil `(,file)))))


;; Terminal

(use-package ielm
  :ensure nil
  :bind ("C-c i" . ielm)
  :custom (ielm-history-file-name (concat nn-directory "ielm-history.eld")))

(use-package tty-tip
  :ensure nil
  :if (featurep 'tty-child-frames)
  :hook (tty-setup . tty-tip-mode))

(use-package shell
  :ensure nil
  :bind
  ("C-:" . shell-command)
  ("C-c C-`" . shell)
  :hook
  (shell-mode . my-shell-mode-hook)
  (comint-output-filter-functions . comint-strip-ctrl-m)
  :custom (system-uses-terminfo nil)
  :config
  (defun my-shell-simple-send (proc command)
    "Various PROC COMMANDs pre-processing before sending to shell."
    (cond
     ((string-match "^[ \t]*clear[ \t]*$" command)
      (comint-send-string proc "\n")
      (erase-buffer))
     ((string-match "^[ \t]*man[ \t]*" command)
      (comint-send-string proc "\n")
      (setq command (replace-regexp-in-string "^[ \t]*man[ \t]*" "" command))
      (setq command (replace-regexp-in-string "[ \t]+$" "" command))
      (funcall 'man command))
     (t (comint-simple-send proc command))))

  (defun my-shell-mode-hook ()
    "Shell mode customization."
    (local-set-key '[up] 'comint-previous-input)
    (local-set-key '[down] 'comint-next-input)
    (local-set-key '[(shift tab)] 'comint-next-matching-input-from-input)
    (ansi-color-for-comint-mode-on)
    (setq comint-input-sender 'my-shell-simple-send)))

(use-package eshell
  :ensure nil
  :bind ("C-c `" . eshell)
  :hook (eshell-mode . (lambda () (local-set-key [remap recenter-top-bottom] 'eshell/clear)))
  :custom
  (eshell-history-size 100000)
  (eshell-hist-ignoredups t)
  :config
  (put 'eshell/ebc 'eshell-no-numeric-conversions t)

  (defalias 'eshell/e #'eshell/emacs)
  (defalias 'eshell/ec #'eshell/emacs)
  (defalias 'eshell/more #'eshell/less)

  (defun eshell/clear ()
    "Clear the eshell buffer."
    (interactive)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (eshell-send-input)))

  (defun eshell/emacs (&rest args)
    "Open a file (ARGS) in Emacs.  Some habits die hard."
    (if (null args)
        (bury-buffer)
      (mapc #'find-file (mapcar #'expand-file-name (flatten-tree (reverse args))))))

  (defun eshell/ebc (&rest args)
    "Compile a file (ARGS) in Emacs. Use `compile' to do background make."
    (if (eshell-interactive-output-p)
        (let ((compilation-process-setup-function
               (list 'lambda nil
                     (list 'setq 'process-environment
                           (list 'quote (eshell-copy-environment))))))
          (compile (eshell-flatten-and-stringify args))
          (pop-to-buffer compilation-last-buffer))
      (throw 'eshell-replace-command
             (let ((l (eshell-stringify-list (flatten-tree args))))
               (eshell-parse-command (car l) (cdr l))))))

  (defun my-eshell-view-file (file)
    "View FILE.  A version of `view-file' which properly rets the eshell prompt."
    (interactive "fView file: ")
    (unless (file-exists-p file) (error "%s does not exist" file))
    (let ((buffer (find-file-noselect file)))
      (if (eq (get (buffer-local-value 'major-mode buffer) 'mode-class)
              'special)
          (progn
            (switch-to-buffer buffer)
            (message "Not using View mode because the major mode is special"))
        (let ((undo-window (list (window-buffer) (window-start)
                                 (+ (window-point)
                                    (length (funcall eshell-prompt-function))))))
          (switch-to-buffer buffer)
          (view-mode-enter (cons (selected-window) (cons nil undo-window))
                           'kill-buffer)))))

  (defun eshell/less (&rest args)
    "Invoke `view-file' on a file (ARGS).
\"less +42 foo\" will go to line 42 in the buffer for foo."
    (while args
      (if (string-match "\\`\\+\\([0-9]+\\)\\'" (car args))
          (let* ((line (string-to-number (match-string 1 (pop args))))
                 (file (pop args)))
            (eshell-view-file file)
            (forward-line line))
        (my-eshell-view-file (pop args)))))  )

(use-package ghostel
  :commands ghostel
  :bind
  (("C-`" . ghostel)
   :map ghostel-semi-char-mode-map
   ("C-k" . my-ghostel-send-C-k-and-kill)
   ("M-p" . (lambda () (interactive) (ghostel-send-key "p" "ctrl")))
   ("M-n" . (lambda () (interactive) (ghostel-send-key "n" "ctrl")))
   :map project-prefix-map
   ("m" . ghostel-project)
   ("M" . ghostel-project-list-buffers))
  :custom (ghostel-term "xterm-256color")
  :config
  (defun my-ghostel-send-C-k-and-kill ()
    "Send `C-k' to ghostel.
Like normal Emacs `C-k'.  Kill to end of line and put content in kill-ring."
    (interactive)
    (kill-ring-save (point) (line-end-position))
    (ghostel-send-key "k" "ctrl"))

  (add-to-list 'project-switch-commands '(ghostel-project "Ghostel") t)
  (add-to-list 'project-switch-commands '(ghostel-project-list-buffers "Ghostel buffers") t)
  (add-to-list 'ghostel-eval-cmds '("magit-status-setup-buffer" magit-status-setup-buffer))
  (add-to-list 'display-buffer-alist
               '("\\*ghostel\\*"
                 (display-buffer-below-selected)
                 (window-height . 0.35))))


;; Debug

(use-package dape
  :bind
  ("<f5>"    . dape)
  ("S-<f5>"  . dape-quit)
  ("<f9>"    . dape-breakpoint-toggle)
  ("<f10>"   . dape-next)
  ("<f11>"   . dape-step-in)
  ("S-<f11>" . dape-step-out)
  ("C-<f5>"  . dape-kill)
  :custom
  (dape-adapter-dir (concat nn-directory "dape/adapters/"))
  (dape-default-breakpoints-file (concat nn-directory "dape/breakpoints.eld"))
  (dape-inlay-hints nil)
  (dape-buffer-window-arrangement 'right)
  :config
  (make-directory (concat nn-directory "dape/adapters/") t)
  (when _WIN32
    (setenv "LLDB_USE_NATIVE_PDB_READER" "1"))

  (defvar my-dape-toolbar-frame nil)
  (defvar my-dape-toolbar-buf nil)

  (defconst my-dape-toolbar-buttons
    '(("nf-cod-debug_continue"  dape-continue "Continue"  nerd-icons-lblue)
      ("nf-cod-debug_step_over" dape-next     "Step Over" nerd-icons-lblue)
      ("nf-cod-debug_step_into" dape-step-in  "Step Into" nerd-icons-lblue)
      ("nf-cod-debug_step_out"  dape-step-out "Step Out"  nerd-icons-lblue)
      ("nf-cod-debug_restart"   dape-restart  "Restart"   nerd-icons-lgreen)
      ("nf-cod-debug_stop"      dape-quit     "Quit"      nerd-icons-red)))

  (defun my-dape-toolbar-buf-create ()
    (setq my-dape-toolbar-buf (get-buffer-create "*NN Dape Toolbar*"))
    (with-current-buffer my-dape-toolbar-buf
      (erase-buffer)
      (insert " ")
      (insert-text-button
       (nerd-icons-codicon "nf-cod-gripper" :face 'nerd-icons-dsilver)
       'mouse-face 'highlight
       'keymap (let ((m (make-sparse-keymap)))
                 (define-key m [down-mouse-1] #'nn-drag-frame)
                 m))
      (dolist (btn my-dape-toolbar-buttons)
        (let ((icon (nth 0 btn))
              (func (nth 1 btn))
              (tooltip (nth 2 btn))
              (face (nth 3 btn)))
          (insert "  ")
          (insert-text-button
           (nerd-icons-codicon icon :face face)
           'mouse-face 'highlight
           'help-echo tooltip
           'action `(lambda (_) (call-interactively ',func)))))
      (put-text-property (point-min) (point-max) 'pointer 'arrow)))

  (defun my-dape-toolbar-create ()
    (my-dape-toolbar-buf-create)
    (setq my-dape-toolbar-frame
          (make-frame
           `((parent-frame . ,(selected-frame))
             (undecorated . t) (z-group . above)
             (left . 0.5) (top . 0)
             (min-width . 0) (min-height . 0)
             (width . 26) (height . 1)
             (internal-border-width . 15) (border-width . 3)
             (left-fringe . 0) (right-fringe . 0)
             (background-color . ,(face-background 'tooltip))
             (cursor-type . nil) (minibuffer . nil)
             (no-focus-on-map . t) (no-other-window . t))))
    (set-window-buffer (frame-root-window my-dape-toolbar-frame) my-dape-toolbar-buf)
    (set-face-attribute 'child-frame-border my-dape-toolbar-frame :background nil :inherit nil))

  (defun my-dape-toolbar-close ()
    (kill-buffer my-dape-toolbar-buf)
    (delete-frame my-dape-toolbar-frame))

  (defun my-dape-select-process ()
    (let* ((lines (process-lines "tasklist" "/FO" "CSV" "/NH"))
           (table (mapcar (lambda (line)
                            (let* ((fields (split-string line "," t))
                                   (name (string-trim (car fields) "\"" "\""))
                                   (pid  (string-trim (cadr fields) "\"" "\"")))
                              (cons (format "%-30s  PID: %s" name pid)
                                    (string-to-number pid))))
                          lines))
           (choice (completing-read "Selection PID: " table nil t)))
      (cdr (assoc choice table))))

  (add-hook 'dape-start-hook #'my-dape-toolbar-create)
  (add-hook 'dape-active-mode-hook (lambda () (unless dape-active-mode (my-dape-toolbar-close))))
  (remove-hook 'dape-start-hook #'dape-repl)
  (add-to-list
   'dape-configs
   '(gdb-attach
     modes (c-mode c-ts-mode c++-mode c++-ts-mode)
     command "gdb"
     command-args ("--interpreter=dap")
     :request "attach"
     :pid (my-dape-select-process))))


;; Remote

(use-package tramp
  :ensure nil
  :custom
  (remote-file-name-inhibit-cache 60)
  (remote-file-name-inhibit-locks t)
  (remote-file-name-inhibit-auto-save-visited t)
  (tramp-verbose 1)
  (tramp-copy-size-limit (* 1024 1024))
  (tramp-use-scp-direct-remote-copying t)
  (tramp-use-scp-direct-remote-copying t)
  (tramp-completion-reread-directory-timeout 60)
  :config
  (unless _WIN32
    (setq tramp-default-method "ssh"))
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))
  (connection-local-set-profiles
   '(:application tramp :protocol "scp")
   'remote-direct-async-process))


;; Extra

(use-package simple-mpv
  :ensure nil
  :custom (simple-mpv-debug nil)
  :bind ("C-c m" . simple-mpv-audio-browse)
  :config
  (with-eval-after-load 'dired
    (keymap-set dired-mode-map "C-c p" #'simple-mpv-play-file)))

(use-package nn-license-template
  :ensure nil
  :commands nn-license-template-file nn-license-template-header
  :bind
  ("C-c l f" . nn-license-template-file)
  ("C-c l h" . nn-license-template-header))

(provide 'init-tools)
