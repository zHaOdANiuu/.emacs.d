;;; gnus-modern-renderer.el --- Base renderer class for gnus-modern  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: zdn <zhaodaniu1@gmail.com>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Abstract base class `gnus-modern-renderer' for the buffer-local
;; Summary and Group renderers.  It owns the debounced decoration and
;; resize machinery shared by both renderers:

;; - `gnus-modern--schedule-decoration' / `gnus-modern--run-decoration'
;;   debounce native Gnus updates into a single decorate pass;
;; - `gnus-modern--schedule-resize' / `gnus-modern--rerender' re-render
;;   when the buffer width changes;
;; - `gnus-modern--window-size-change-hook' is a single shared handler
;;   for both renderer types;
;; - `gnus-modern--cancel-timers' releases timer state, e.g. on kill.

;; Subclasses implement `gnus-modern--decorate', `gnus-modern--decorate-p',
;; `gnus-modern--configure-buffer', `gnus-modern--rerender-p',
;; `gnus-modern--rerender-now', and `gnus-modern--fallback-width'.

;;; Code:

(require 'cl-lib)
(require 'eieio)

(defun gnus-modern--renderer-width (buffer &optional fallback)
  "Return the display width of BUFFER, falling back to FALLBACK."
  (if-let* ((window
             (or (and (eq (window-buffer (selected-window)) buffer)
                      (selected-window))
                 (get-buffer-window buffer t))))
      (window-body-width window)
    (or fallback 100)))

(defclass gnus-modern-renderer ()
  ((decoration-timer :initform nil
                     :documentation "Idle timer debouncing decoration.")
   (resize-timer :initform nil
                 :documentation "Idle timer debouncing resize renders.")
   (render-width :initform nil
                 :documentation "Width used by the latest render.")
   (configured-p :initform nil
                 :documentation "Non-nil after the buffer is configured."))
  :abstract t
  :documentation "Base class of the buffer-local gnus-modern renderers.")

(cl-defmethod gnus-modern--cancel-timers ((renderer gnus-modern-renderer))
  "Cancel timers owned by RENDERER."
  (when (timerp (oref renderer decoration-timer))
    (cancel-timer (oref renderer decoration-timer)))
  (when (timerp (oref renderer resize-timer))
    (cancel-timer (oref renderer resize-timer)))
  (oset renderer decoration-timer nil)
  (oset renderer resize-timer nil))

(cl-defmethod gnus-modern--schedule-decoration ((renderer gnus-modern-renderer))
  "Schedule decoration of the current buffer with RENDERER after a debounce."
  (when (timerp (oref renderer decoration-timer))
    (cancel-timer (oref renderer decoration-timer)))
  (oset renderer decoration-timer
        (run-with-idle-timer
         0.05 nil #'gnus-modern--run-decoration
         renderer (current-buffer))))

(cl-defmethod gnus-modern--run-decoration ((renderer gnus-modern-renderer) buffer)
  "Decorate BUFFER with RENDERER after the decoration debounce elapses."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (oset renderer decoration-timer nil)
      (when (gnus-modern--decorate-p renderer)
        (gnus-modern--decorate renderer)))))

(cl-defmethod gnus-modern--schedule-resize ((renderer gnus-modern-renderer)
                                            buffer)
  "Schedule a debounced resize render of BUFFER with RENDERER."
  (when (buffer-live-p buffer)
    (when (timerp (oref renderer resize-timer))
      (cancel-timer (oref renderer resize-timer)))
    (oset renderer resize-timer
          (run-with-idle-timer
           0.2 nil #'gnus-modern--rerender renderer buffer))))

(cl-defmethod gnus-modern--rerender ((renderer gnus-modern-renderer) buffer)
  "Rerender BUFFER with RENDERER after a debounced resize."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (oset renderer resize-timer nil)
      (when (and (gnus-modern--rerender-p renderer)
                 (get-buffer-window buffer t)
                 (not (equal (gnus-modern--renderer-width
                              buffer (gnus-modern--fallback-width renderer))
                             (oref renderer render-width))))
        (gnus-modern--rerender-now renderer)))))

(defun gnus-modern--window-size-change-hook (frame)
  "Schedule rerenders for visible buffers on FRAME with active renderers."
  (let ((seen (make-hash-table :test #'eq)))
    (dolist (window (window-list frame 'no-minibuffer))
      (let* ((buffer (window-buffer window))
             (renderer (and (buffer-live-p buffer)
                            (or (buffer-local-value
                                 'gnus-modern--summary-renderer buffer)
                                (buffer-local-value
                                 'gnus-modern--group-renderer buffer)))))
        (when (and renderer
                   (oref renderer configured-p)
                   (not (gethash buffer seen)))
          (puthash buffer t seen)
          (gnus-modern--schedule-resize renderer buffer))))))

(cl-defmethod gnus-modern--decorate-p ((_renderer gnus-modern-renderer))
  "Return non-nil when RENDERER should decorate the current buffer."
  nil)

(cl-defmethod gnus-modern--decorate ((renderer gnus-modern-renderer))
  "Decorate the current buffer with RENDERER."
  (error "`gnus-modern--decorate' is not implemented for %S"
         (eieio-object-class renderer)))

(cl-defmethod gnus-modern--configure-buffer ((renderer gnus-modern-renderer))
  "Configure the current buffer for RENDERER."
  (oset renderer configured-p t))

(cl-defmethod gnus-modern--rerender-p ((renderer gnus-modern-renderer))
  "Return non-nil when RENDERER should re-render the current buffer."
  (oref renderer configured-p))

(cl-defmethod gnus-modern--rerender-now ((renderer gnus-modern-renderer))
  "Re-render the current buffer with RENDERER."
  (gnus-modern--decorate renderer))

(cl-defmethod gnus-modern--fallback-width ((_renderer gnus-modern-renderer))
  "Return the width used when RENDERER's buffer has no live window."
  100)

(provide 'gnus-modern-renderer)
;;; gnus-modern-renderer.el ends here
