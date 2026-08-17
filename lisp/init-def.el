;;; -*- lexical-binding: t -*-
(defgroup nn nil
  "Personal customization group."
  :prefix "nn-")

(defcustom nn-directory "~/.emacs.d/.nn"
  "Base directory for nn."
  :type 'directory
  :group 'nn)

(defcustom nn-flyspell-everywhere t
  "Non-nil to enable flyspell in all buffers."
  :type 'boolean
  :group 'nn)

(defcustom nn-fold-string "…"
  "String used for folding/truncating display."
  :type 'string
  :group 'nn)

(defcustom nn-proxy-port 7897
  "VPN Proxy port."
  :type 'number
  :group 'nn)

(defcustom nn-completion-style 'corfu
  "Completion framework to use."
  :type '(choice (const :tag "Corfu" corfu)
                 (const :tag "Completion-preview" completion-preview))
  :group 'nn)

(defcustom nn-buffer-allow-names
  '("*compilation*" "*eshell*" "*ghostel*")
  "List of buffer names allowed in special contexts."
  :type '(repeat string)
  :group 'nn)

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

(provide 'init-def)
