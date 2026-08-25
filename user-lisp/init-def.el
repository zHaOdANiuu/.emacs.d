;;; -*- lexical-binding: t -*-
(defgroup nn nil
  "Personal customization group."
  :prefix "nn-")

(defcustom nn-directory (expand-file-name "~/.emacs.d/.nn/")
  "Base directory for nn."
  :type 'directory
  :group 'nn)

(defcustom nn-flyspell-everywhere t
  "Non-nil to enable flyspell in all buffers."
  :type 'boolean
  :group 'nn)

(defcustom nn-font-fallback t
  "Apply font fallback."
  :type 'boolean
  :group 'nn)

(defcustom nn-font-ligatures nil
  "Enbale font ligatures."
  :type 'boolean
  :group 'nn)

(defcustom nn-vim-mode nil
  "Enbale vim input method."
  :type 'boolean
  :group 'nn)

(defcustom nn-fold-string "…"
  "String used for folding/truncating display."
  :type 'string
  :group 'nn)

(defcustom nn-indent-offset 2
  "Default code indent ossfet."
  :type 'number
  :group 'nn)

(defcustom nn-proxy-port 7897
  "VPN Proxy port."
  :type 'number
  :group 'nn)

(defcustom nn-completion-style 'corfu
  "Completion framework to use."
  :type '(choice
          (const :tag "Corfu" corfu)
          (const :tag "Completion-preview" completion-preview))
  :group 'nn)

(defcustom nn-buffer-allow-names
  '("*compilation*" "*eshell*" "*ghostel*")
  "List of buffer names allowed in special contexts."
  :type '(repeat string)
  :group 'nn)

(defcustom nn-first-input-hook ()
  "Transient hooks run before the first user input."
  :type 'hook
  :group 'nn)

(defcustom nn-first-file-hook ()
  "Transient hooks run before the first interactively opened file."
  :type 'hook
  :group 'nn)

(defun nn-run-hook-on (hook-var trigger-hooks &optional predicate)
  "Configure HOOK-VAR to be invoked exactly once when any of the TRIGGER-HOOKS
are invoked *after* Emacs has initialized (to reduce false positives). Once
HOOK-VAR is triggered, it is reset to nil.

HOOK-VAR is a quoted hook.
TRIGGER-HOOK is a list of quoted hooks and/or sharp-quoted functions."
  (dolist (hook trigger-hooks)
    (let ((fn (make-symbol (format "chain-%s-to-%s-h" hook-var hook)))
          running?)
      (fset
       fn (lambda (&rest _)
            ;; Only trigger this after Emacs has initialized.
            (when (and (not running?)
                       after-init-time
                       (or (daemonp)
                           ;; In some cases, hooks may be lexically unset to
                           ;; inhibit them during expensive batch operations on
                           ;; buffers (such as when processing buffers
                           ;; internally). In that case assume this hook was
                           ;; invoked non-interactively.
                           (and (boundp hook)
                                (symbol-value hook)))
                       (or (null predicate)
                           (funcall predicate)))
              (setq running? t)  ; prevent infinite recursion
              (run-hooks hook-var)
              (set hook-var nil))))
      (when (daemonp)
        ;; In a daemon session we don't need all these lazy loading shenanigans.
        ;; Just load everything immediately.
        (add-hook 'server-after-make-frame-hook fn 'append))
      (if (eq hook 'find-file-hook)
          ;; Advise `after-find-file' instead of using `find-file-hook' because
          ;; the latter is triggered too late (after the file has opened and
          ;; modes are all set up).
          (advice-add 'after-find-file :before fn '((depth . -101)))
        (add-hook hook fn -101))
      fn)))

(defun nn-run-switch-buffer-hooks-h (&optional _)
  "Trigger `doom-switch-buffer-hook' when selecting a new buffer."
  (let ((gc-cons-threshold most-positive-fixnum))
    (run-hooks 'doom-switch-buffer-hook)))

(defun nn-run-switch-window-hooks-h (&optional _)
  "Trigger `doom-switch-window-hook' when selecting a window in the same frame."
  (unless (or (minibufferp)
              (not (equal (old-selected-frame) (selected-frame)))
              (equal (old-selected-window) (minibuffer-window)))
    (let ((gc-cons-threshold most-positive-fixnum))
      (run-hooks 'doom-switch-window-hook))))

(defun nn-childframe-workable-p ()
  (and (not noninteractive)
       (not emacs-basic-display)
       (or (display-graphic-p)
           (featurep 'tty-child-frames))
       (eq (frame-parameter (selected-frame) 'minibuffer) 't)))

(defun nn-drag-frame (event)
  (interactive "e")
  (let* ((frame (window-frame (posn-window (event-start event))))
         (start (mouse-absolute-pixel-position))
         (pos (frame-position frame)))
    (track-mouse
      (while (eq (car-safe (setq event (read-event))) 'mouse-movement)
        (let ((cur (mouse-absolute-pixel-position)))
          (set-frame-position
           frame
           (+ (car pos) (car cur) (- (car start)))
           (+ (cdr pos) (cdr cur) (- (cdr start)))))))))

(defun nn-proxy-enable ()
  "Enable proxy for all network connections in Emacs."
  (interactive)
  (setq-local url-proxy-services
              '(("no_proxy" . "^\\(localhost\\|10\\..*\\|192\\.168\\..*\\)")
                ("http" . (format "localhost:%d" nn-proxy-port))
                ("https" .(format "localhost:%d" nn-proxy-port))))
  (message "Proxy enabled"))

(defun nn-proxy-disable ()
  "Disable proxy in Emacs."
  (interactive)
  (setq url-proxy-services nil)
  (setq socks-server nil)
  (message "Proxy disabled"))

(nn-run-hook-on 'nn-first-file-hook '(find-file-hook dired-initial-position-hook))
(nn-run-hook-on 'nn-first-input-hook '(pre-command-hook))
(add-hook 'window-selection-change-functions #'nn-run-switch-window-hooks-h)
(add-hook 'window-buffer-change-functions #'nn-run-switch-buffer-hooks-h)
;; `window-buffer-change-functions' doesn't trigger for files visited via the server.
(add-hook 'server-switch-hook #'nn-run-switch-buffer-hooks-h)

(provide 'init-def)
