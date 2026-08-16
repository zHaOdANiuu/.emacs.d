;;; gnus-modern.el --- Modern Gnus interface  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: zdn <zhaodaniu1@gmail.com>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; A personal Gnus interface built from two renderer subsystems:

;; - `gnus-modern-summary'   custom Summary renderer with thread
;;   titles, month separators, folding, and context lines
;;   (stateless formatting in `gnus-modern-summary-format');
;; - `gnus-modern-group'     custom Group renderer with source labels
;;   and decorated Topic rows (formatting in
;;   `gnus-modern-group-format').

;; Enable everything with `gnus-modern-mode'; disable with
;; `(gnus-modern-mode -1)'.  Individual subsystems have their own
;; `gnus-modern-...-enable' / `gnus-modern-...-disable' commands.

;;; Code:

(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-renderer)
(require 'gnus-modern-group-format)
(require 'gnus-modern-group)
(require 'gnus-modern-summary-format)
(require 'gnus-modern-summary)

;;;###autoload
(define-minor-mode gnus-modern-mode
  "Toggle the gnus-modern interface for Gnus buffers."
  :global t
  :lighter nil
  :group 'gnus-modern
  (if gnus-modern-mode
      (progn
        (gnus-modern-group-enable)
        (gnus-modern-summary-enable))
    (progn
      (gnus-modern-summary-disable)
      (gnus-modern-group-disable))))

(provide 'gnus-modern)
;;; gnus-modern.el ends here
