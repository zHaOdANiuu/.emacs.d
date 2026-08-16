;;; gnus-modern-group.el --- Custom Gnus Group renderer  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: zdn <zhaodaniu1@gmail.com>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Replaces the native Gnus Group buffer line format with a custom
;; renderer: right-aligned unread/total counts, source labels, and
;; decorated Topic rows.  One `gnus-modern-group-renderer' instance
;; lives in each Group buffer; stateless formatting helpers live in
;; `gnus-modern-group-format.el'.  Enable with
;; `gnus-modern-group-enable'.

;;; Code:

(require 'gnus)
(require 'gnus-group)
(require 'gnus-topic)
(require 'nntp)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-renderer)
(require 'gnus-modern-group-format)

(defvar-local gnus-modern--group-renderer nil
  "Group renderer instance of the current buffer.")

(defvar gnus-modern--group-installed-p nil
  "Non-nil when the custom Group renderer is installed.")

(defvar gnus-modern--group-posting-status-cache
  (make-hash-table :test #'equal)
  "NNTP posting statuses cached by full Gnus group name.")

(defun gnus-modern--current-group-renderer ()
  "Return the Group renderer instance of the current buffer."
  (or gnus-modern--group-renderer
      (setq gnus-modern--group-renderer
            (make-instance 'gnus-modern-group-renderer))))

(defun gnus-modern--group-decorate-lines (width count-widths)
  "Decorate every Group and Topic row with WIDTH and COUNT-WIDTHS."
  (goto-char (point-min))
  (while (not (eobp))
    (let ((group
           (get-text-property
            (line-beginning-position) 'gnus-group))
          (topic
           (get-text-property
            (line-beginning-position) 'gnus-topic)))
      (cond
       (topic
        (let ((level
               (get-text-property
                (line-beginning-position)
                'gnus-topic-level))
              (unread
               (get-text-property
                (line-beginning-position)
                'gnus-topic-unread))
              (visible
               (get-text-property
                (line-beginning-position)
                'gnus-topic-visible)))
          (gnus-modern--group-replace-line
           (gnus-modern--group-format-topic
            topic level unread visible width))))
       (group
        (gnus-modern--group-replace-line
         (gnus-modern--group-format-row
          group
          (get-text-property
           (line-beginning-position) 'gnus-unread)
          (or (get-text-property
               (line-beginning-position)
               'gnus-indentation)
              "")
          width
          count-widths))))
      (forward-line 1))))

(defun gnus-modern--group-mode-hook ()
  "Configure the current Group buffer's renderer."
  (gnus-modern--configure-buffer
   (gnus-modern--current-group-renderer)))

(defun gnus-modern--group-prepare-hook ()
  "Decorate the current Group buffer."
  (gnus-modern--decorate (gnus-modern--current-group-renderer)))

(defun gnus-modern--group-after-topic-change (&rest _arguments)
  "Redecorate a Group buffer after its topic structure changes."
  (when (derived-mode-p 'gnus-group-mode)
    (gnus-modern--decorate (gnus-modern--current-group-renderer))))

(defun gnus-modern--group-around-topic-fold (function &rest arguments)
  "Call FUNCTION with ARGUMENTS while preserving point on its Topic."
  (let ((topic
         (and (derived-mode-p 'gnus-group-mode)
              (get-text-property
               (line-beginning-position) 'gnus-topic)))
        (column (current-column)))
    (prog1
        (apply function arguments)
      (when (derived-mode-p 'gnus-group-mode)
        (let ((renderer (gnus-modern--current-group-renderer)))
          (gnus-modern--cancel-timers renderer)
          (gnus-modern--decorate renderer)
          (when (and topic (gnus-topic-goto-topic topic))
            (move-to-column column)))))))

(defun gnus-modern--group-schedule-decoration (&rest _arguments)
  "Schedule decoration after a native Group or Topic line update."
  (when (derived-mode-p 'gnus-group-mode)
    (gnus-modern--schedule-decoration
     (gnus-modern--current-group-renderer))))

(defun gnus-modern--group-cancel-timers ()
  "Cancel timers owned by the current buffer's Group renderer."
  (when gnus-modern--group-renderer
    (gnus-modern--cancel-timers gnus-modern--group-renderer)))

(defun gnus-modern--group-install ()
  "Install the custom Gnus Group renderer."
  (unless gnus-modern--group-installed-p
    (setq gnus-modern--group-installed-p t)
    (add-hook 'gnus-group-mode-hook #'gnus-modern--group-mode-hook)
    (add-hook 'gnus-group-prepare-hook #'gnus-modern--group-prepare-hook)
    (add-hook 'gnus-group-update-hook
              #'gnus-modern--group-schedule-decoration)
    (add-hook 'window-size-change-functions
              #'gnus-modern--window-size-change-hook)
    (advice-remove 'gnus-topic-fold
                   #'gnus-modern--group-after-topic-change)
    (advice-add 'gnus-topic-fold
                :around #'gnus-modern--group-around-topic-fold)
    (advice-add 'gnus-topic-indent
                :after #'gnus-modern--group-after-topic-change)
    (advice-add 'gnus-topic-unindent
                :after #'gnus-modern--group-after-topic-change)
    (advice-add 'gnus-topic-update-topic-line
                :after #'gnus-modern--group-schedule-decoration)
    (dolist (buffer (gnus-modern--group-buffers))
      (with-current-buffer buffer
        (gnus-modern--configure-buffer
         (gnus-modern--current-group-renderer))
        (gnus-modern--decorate
         (gnus-modern--current-group-renderer)))))
  t)

(defclass gnus-modern-group-renderer (gnus-modern-renderer)
  ((original-header-line-format :initform nil
                                :documentation
                                "Header line format saved before enabling."))
  :documentation "Buffer-local Group renderer of gnus-modern.")

(cl-defmethod gnus-modern--configure-buffer
  ((renderer gnus-modern-group-renderer))
  "Configure the current Gnus Group buffer with RENDERER."
  (unless (oref renderer configured-p)
    (oset renderer original-header-line-format header-line-format))
  (setq-local header-line-format
              '(:eval (gnus-modern--group-header)))
  (cl-call-next-method)
  (add-hook 'kill-buffer-hook #'gnus-modern--group-cancel-timers nil t))

(cl-defmethod gnus-modern--decorate ((renderer gnus-modern-group-renderer))
  "Decorate the current native Gnus Group buffer with RENDERER."
  (when (and gnus-modern--group-installed-p
             (derived-mode-p 'gnus-group-mode)
             (bound-and-true-p gnus-topic-mode))
    (let ((topic
           (get-text-property
            (line-beginning-position) 'gnus-topic))
          (column (current-column))
          (width (gnus-modern--group-width))
          (count-widths (gnus-modern--group-count-widths))
          (inhibit-read-only t))
      (save-excursion
        (gnus-modern--group-remove-decorations)
        (gnus-modern--group-decorate-lines width count-widths)
        (dolist (row (gnus-modern--group-topic-rows))
          (gnus-modern--group-add-topic-spacing
           (car row) (cdr row))))
      (oset renderer render-width width)
      (force-mode-line-update)
      (when (and topic (gnus-topic-goto-topic topic))
        (move-to-column column)))))

(cl-defmethod gnus-modern--decorate-p ((renderer gnus-modern-group-renderer))
  "Return non-nil when RENDERER should decorate the current buffer."
  (oref renderer configured-p))

(cl-defmethod gnus-modern--rerender-p ((_renderer gnus-modern-group-renderer))
  "Return non-nil when RENDERER should re-render the current buffer."
  gnus-modern--group-installed-p)

(cl-defmethod gnus-modern--fallback-width
  ((_renderer gnus-modern-group-renderer))
  "Return the width used when no Group window is live."
  gnus-modern-group-fallback-width)

(cl-defmethod cl-print-object ((object gnus-modern-group-renderer) stream)
  "Print a compact description of OBJECT to STREAM."
  (princ (format "#<group-renderer %s width=%s>"
                 (if (oref object configured-p) "configured" "idle")
                 (or (oref object render-width) "-"))
         stream))

;;;###autoload
(defun gnus-modern-group-disable ()
  "Restore Gnus's native Group renderer."
  (interactive)
  (when gnus-modern--group-installed-p
    (setq gnus-modern--group-installed-p nil)
    (remove-hook 'gnus-group-mode-hook #'gnus-modern--group-mode-hook)
    (remove-hook 'gnus-group-prepare-hook #'gnus-modern--group-prepare-hook)
    (remove-hook 'gnus-group-update-hook
                 #'gnus-modern--group-schedule-decoration)
    (remove-hook 'window-size-change-functions
                 #'gnus-modern--window-size-change-hook)
    (advice-remove 'gnus-topic-fold
                   #'gnus-modern--group-around-topic-fold)
    (advice-remove 'gnus-topic-fold
                   #'gnus-modern--group-after-topic-change)
    (advice-remove 'gnus-topic-indent
                   #'gnus-modern--group-after-topic-change)
    (advice-remove 'gnus-topic-unindent
                   #'gnus-modern--group-after-topic-change)
    (advice-remove 'gnus-topic-update-topic-line
                   #'gnus-modern--group-schedule-decoration)
    (dolist (buffer (gnus-modern--group-buffers))
      (with-current-buffer buffer
        (when gnus-modern--group-renderer
          (gnus-modern--cancel-timers gnus-modern--group-renderer)
          (gnus-modern--group-remove-decorations)
          (setq-local header-line-format
                      (oref gnus-modern--group-renderer
                            original-header-line-format))
          (oset gnus-modern--group-renderer configured-p nil)
          (setq gnus-modern--group-renderer nil))
        (gnus-group-list-groups
         (car gnus-group-list-mode)
         (cdr gnus-group-list-mode))))))

;;;###autoload
(defun gnus-modern-group-enable ()
  "Enable the gnus-modern Group renderer."
  (interactive)
  (with-eval-after-load 'gnus-topic
    (gnus-modern--group-install)))

;;;###autoload
(defun gnus-modern-group-topic-toggle ()
  "Toggle the topic at point without changing its hierarchy."
  (interactive)
  (unless (derived-mode-p 'gnus-group-mode)
    (user-error "This command requires a Gnus Group buffer"))
  (unless (get-text-property
           (line-beginning-position) 'gnus-topic)
    (user-error "No topic at point"))
  (gnus-topic-fold))

;;;###autoload
(defun gnus-modern-group-posting-status (group &optional refresh)
  "Return NNTP posting status for GROUP, refreshing when REFRESH is non-nil."
  (or (and (not refresh)
           (gethash group gnus-modern--group-posting-status-cache))
      (let* ((method (gnus-find-method-for-group group))
             (backend (car method))
             (server (cadr method))
             (real-group (gnus-group-real-name group)))
        (unless (eq backend 'nntp)
          (user-error "%s is not an NNTP group" group))
        (require 'nntp)
        (unless (nntp-list-active-group real-group server)
          (user-error "Cannot query the posting status of %s" group))
        (with-current-buffer nntp-server-buffer
          (goto-char (point-min))
          (unless (re-search-forward
                   (concat
                    "^" (regexp-quote real-group)
                    "[\t ]+[0-9]+[\t ]+[0-9]+[\t ]+"
                    "\\([ymn]\\)[\t ]*\r?$")
                   nil t)
            (user-error "Unknown posting status for %s" group))
          (let ((status (string-to-char (match-string 1))))
            (puthash group status
                     gnus-modern--group-posting-status-cache)
            status)))))

(provide 'gnus-modern-group)
;;; gnus-modern-group.el ends here
