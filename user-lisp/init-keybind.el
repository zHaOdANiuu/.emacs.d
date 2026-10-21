;;; -*- lexical-binding: t -*-
(use-package transient
  :ensure nil
  :custom
  (transient-history-file (concat nn-directory "transient/history.el"))
  (transient-levels-file (concat nn-directory "transient/levels.el"))
  (transient-values-file (concat nn-directory "transient/values.el"))
  :config
  (defvar my-transient-defer-autoload--inhibit nil
    "Non-nil while a Transient layout is being built.")

  (define-advice transient--load-command-if-autoload
      (:around (orig cmd) my-transient-defer-autoload--load-command)
    "Skip autoload loading of CMD while a layout is being built.
The actual load still happens on key press via `transient--wrap-command'."
    (if my-transient-defer-autoload--inhibit
        cmd
      (funcall orig cmd)))

  (define-advice transient--init-suffix
      (:around (orig levels spec parent) my-transient-defer-autoload--init-suffix)
    "Defer autoload loading while building a single suffix.
LEVELS, SPEC and PARENT are passed to ORIG."
    (let ((my-transient-defer-autoload--inhibit t))
      (when (listp spec)
        (let ((cmd (plist-get (cdr spec) :command)))
          (when (and cmd (symbolp cmd))
            (unless (fboundp cmd)
              (defalias cmd
                (lambda ()
                  (interactive)
                  (error "Command `%s' is not available; the package providing it may not be installed"
                         cmd))
                (format "Stub for missing Transient command `%s'." cmd))))))
      (funcall orig levels spec parent))))

(use-package nn-keybind
  :ensure nil
  :no-require t
  :bind
  ("C-<down-mouse-1>" . nil)
  ("C-<backspace>" . my-smart-delete-backward-word)
  ("<escape>" . keyboard-escape-quit)
  ("C-c f" . ff-find-other-file)
  ("C-c 4 f" . ff-find-other-file-other-window)
  ("C-c C-r" . my-switch-to-project-root)
  ("C-c r" . my-replace)
  ("C-c p" . pop-to-mark-command)
  ("M-w" . my-copy)
  ("C-w" . my-cut)
  ("C-x k" . my-kill)
  ("C-x C-k" . kill-buffer)
  ("C-S-<backspace>" . my-delete-whole-line-no-kill)
  ("C-," . duplicate-dwim)
  ("C-~" . my-home-dired)
  ("C-'" . imenu)
  ("C-1" . scroll-up-command)
  ("C-2" . scroll-down-command)
  ("C-3" . recenter-top-bottom)
  ("S-<tab>" . indent-rigidly-left-to-tab-stop)
  ("C-<tab>" . next-buffer)
  ("C-S-<tab>" . bs-cycle-previous)
  ("C-a" . back-to-indentation)
  ("C-v" . yank)
  ("C-z" . undo)
  ("C-S-z" . undo-redo)
  ("C-M-<up>" . windmove-up)
  ("C-M-<down>" . windmove-down)
  ("C-M-<left>" . windmove-left)
  ("C-M-<right>" . windmove-right)
  ("C-M-S-<down>" . shrink-window)
  ("C-M-S-<up>" . enlarge-window)
  ("C-M-S-<left>" . enlarge-window-horizontally)
  ("C-M-S-<right>" . shrink-window-horizontally)
  ("M-l" . my-downcase-dwim)
  ("M-u" . my-upcase-dwim)
  ("M-<f11>" . toggle-frame-fullscreen)
  ("M--" . split-window-below)
  ("M-+" . split-window-right)
  ("M-=" . split-window-right)
  ("M-<up>" . my-move-line-up)
  ("M-<down>" . my-move-line-down)
  ("M-<left>" . backward-sexp)
  ("M-<right>" . forward-sexp)
  :init
  (setq duplicate-line-final-position 1)

  (defun my-smart-delete-backward-word ()
    (interactive)
    (if (= (point) (save-excursion (back-to-indentation) (point)))
        (unless (bobp)
          (delete-indentation))
      (delete-region (point) (progn (backward-word) (point)))))

  (defun my-cut ()
    (interactive)
    (if (use-region-p)
        (kill-region (region-beginning) (region-end))
      (kill-whole-line)))

  (defun my-copy ()
    (interactive)
    (if (use-region-p)
        (copy-region-as-kill (region-beginning) (region-end))
      (kill-ring-save (line-beginning-position) (line-beginning-position 2))))

  (defun my-move-line-up ()
    (interactive)
    (let ((col (current-column)))
      (transpose-lines 1)
      (forward-line -2)
      (move-to-column col)))

  (defun my-move-line-down ()
    (interactive)
    (let ((col (current-column)))
      (forward-line 1)
      (transpose-lines 1)
      (forward-line -1)
      (move-to-column col)))

  (defun my-delete-whole-line-no-kill ()
    (interactive)
    (delete-region (line-beginning-position) (line-beginning-position 2)))

  (defun my-downcase-dwim ()
    (interactive)
    (if (use-region-p)
        (downcase-region (region-beginning) (region-end))
      (call-interactively #'downcase-word)))

  (defun my-upcase-dwim ()
    (interactive)
    (if (use-region-p)
        (upcase-region (region-beginning) (region-end))
      (call-interactively #'upcase-word)))

  (defun my-home-dired ()
    (interactive)
    (dired "~"))

  (defun my-switch-to-project-root ()
    (interactive)
    (if-let* ((proj (project-current)))
        (dired (project-root proj))
      (dired default-directory)))

  (defun my-surround-word (char)
    "Wrap word at point or active region with CHAR."
    (interactive "cWrap char: ")
    (let ((beg (if (use-region-p) (region-beginning)
                 (car (bounds-of-thing-at-point 'word))))
          (end (if (use-region-p) (region-end)
                 (cdr (bounds-of-thing-at-point 'word)))))
      (when (and beg end)
        (save-excursion
          (goto-char end) (insert char)
          (goto-char beg) (insert char)))))

  (defun my-surround-replace (char)
    (interactive "cReplace surrounding chars with: ")
    (when-let* ((bounds (bounds-of-thing-at-point 'word)))
      (save-excursion
        (goto-char (car bounds))
        (when (search-backward-regexp "[^[:space:]]" (line-beginning-position) t)
          (delete-char 1) (insert char))
        (goto-char (cdr bounds))
        (when (search-forward-regexp "[^[:space:]]" (line-end-position) t)
          (delete-char -1) (insert char)))))

  (defun my-surround-replace-pair (old-char new-char)
    (interactive "cWrap char? \ncReplace surrounding chars with: ")
    (when-let* ((bounds (bounds-of-thing-at-point 'word)))
      (save-excursion
        (goto-char (car bounds))
        (when (search-backward (string old-char) (line-beginning-position) t)
          (delete-char 1)
          (insert (string new-char)))
        (goto-char (cdr bounds))
        (when (search-forward (string old-char) (line-end-position) t)
          (delete-char -1)
          (insert (string new-char))))))

  (defun my-replace (from to &optional delimited start end)
    (interactive
     (let ((beg (if (use-region-p) (region-beginning) (point-min)))
           (end (if (use-region-p) (region-end)       (point-max))))
       (list (read-string "Replace: ")
             (read-string "With: ")
             nil beg end)))
    (replace-string from to delimited start end))

  (defun my-kill ()
    (interactive)
    (let ((buf-name (buffer-file-name)))
      (when (and buf-name
                 (file-exists-p buf-name)
                 (buffer-modified-p))
        (save-buffer)))
    (let ((other-buf (window-buffer (next-window))))
      (kill-current-buffer)
      (when (and (= (count-windows) 2)
                 (eq (window-buffer (next-window)) other-buf))
        (delete-window)))))

(use-package nn-context-menu
  :ensure nil
  :no-require t
  :bind
  ("<mouse-3>" . nn-context-menu)
  ("<left-margin> <mouse-3>" . nn-context-menu)
  ("<right-margin> <mouse-3>" . nn-context-menu)
  :init
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

  (defun my-translate-word () (interactive))

  (defun my-translate-region () (interactive))

  (defun my-translate-buffer () (interactive))

  (defun nn-context-menu ()
    (interactive)
    (popup-menu
     (cond
      ((or (derived-mode-p 'dired-mode)
           (derived-mode-p 'speedbar-mode))
       nn-project-menu-items)
      ((or (derived-mode-p 'prog-mode)
           (derived-mode-p 'text-mode))
       nn-edit-menu-items)
      (t nn-leisure-menu-items))
     `(mouse-3 ,(mouse-absolute-pixel-position))))

  (defconst nn-edit-menu-items
    '("NN Edit Menu"
      ["Lsp Format" eglot-format-buffer :active (nn-has-lsp)]
      ["Lsp Log"    eglot-stderr-buffer :active (nn-has-lsp)]
      ("Code Actions"
       :active (nn-has-lsp)
       ["Quick Fix"        eglot-code-actions]
       ["Extract"          eglot-code-action-extract]
       ["Inline"           eglot-code-action-inline]
       ["Organize Imports" eglot-code-action-organize-imports]
       ["Rewrite"          eglot-code-action-rewrite])
      ["Debug Code"    dape]
      ["Comman Format" apheleia-format-buffer]
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
      ["New File"         dired-create-empty-file]
      ["New Folder"       dired-create-directory]
      ["Create Tasg File" citre-create-tags-file]
      ["Update Tags File" citre-update-this-tags-file]
      "--"
      ["On Lsp Server"    eglot]
      ["On Lsp Close"     eglot-shutdown]
      ["On Live server"   nn-live-server]))

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
    (keymap-set speedbar-mode-map "<down-mouse-3>" nil)))

(provide 'init-keybind)
