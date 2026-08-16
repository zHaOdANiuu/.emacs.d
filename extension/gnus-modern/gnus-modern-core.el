;;; gnus-modern-core.el --- Shared utilities for gnus-modern  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: zdn <zhaodaniu1@gmail.com>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Small self-contained helpers shared by the gnus-modern modules.
;; They replace the private bs-lib package, so
;; the package has no external dependencies.

;;; Code:

(require 'cl-lib)

(defun gnus-modern--truncate-string (string width)
  "Return STRING truncated to WIDTH columns with an ellipsis."
  (if (<= (string-width string) width)
      string
    (truncate-string-to-width string (max 0 width) nil nil "…")))

(defun gnus-modern--right-padding (string &optional width)
  "Return SPACES right-aligning STRING within WIDTH columns."
  (let ((width (or width (window-body-width) 100)))
    (make-string (max 0 (- width (string-width string))) ?\s)))

(defun gnus-modern--top-spacing-prefix (height)
  "Return a line prefix adding HEIGHT lines of spacing above a line."
  (propertize " " 'line-height height))

(defun gnus-modern--sanitize-single-line (string)
  "Return STRING with line breaks replaced by spaces."
  (replace-regexp-in-string "[\n\r]+" " " (or string "")))

(defun gnus-modern--group-buffers ()
  "Return live Gnus Group buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-group-mode)))
   (buffer-list)))

(defun gnus-modern--summary-buffers ()
  "Return live Gnus Summary buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-summary-mode)))
   (buffer-list)))

(provide 'gnus-modern-core)
;;; gnus-modern-core.el ends here
