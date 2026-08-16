;;; gnus-modern-group-format.el --- Group formatting helpers  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: zdn <zhaodaniu1@gmail.com>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Stateless formatting helpers of the custom Gnus Group renderer:
;; source labels, right-aligned unread/total counts, Topic rows, root
;; statistics, and decoration removal.
;; The buffer-local renderer and its methods live in
;; `gnus-modern-group.el'.

;;; Code:

(require 'gnus)
(require 'gnus-group)
(require 'gnus-topic)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-renderer)

(defun gnus-modern--group-width ()
  "Return the display width for the current Group buffer."
  (gnus-modern--renderer-width
   (current-buffer) gnus-modern-group-fallback-width))

(defun gnus-modern--group-source (group)
  "Return the concise source label for GROUP."
  (let* ((method (gnus-find-method-for-group group))
         (address
          (or (cadr (assq 'nntp-address (cddr method)))
              (nth 1 method)))
         (name
          (and address
               (cdr
                (assoc-string
                 address gnus-modern-group-source-names t)))))
    (cond
     (name name)
     ((eq (car method) 'nntp)
      "Usenet")
     (t "Local"))))

(defun gnus-modern--group-total (group)
  "Return the highest known article number in GROUP."
  (if-let* ((active (gnus-active group)))
      (cdr active)
    0))

(defun gnus-modern--group-max-indentation-width ()
  "Return the widest group indentation represented in the Topic tree."
  (let ((width 0))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((indentation
               (get-text-property
                (line-beginning-position)
                'gnus-indentation))
              (level
               (get-text-property
                (line-beginning-position)
                'gnus-topic-level)))
          (setq width
                (max width
                     (if (stringp indentation)
                         (string-width indentation)
                       0)
                     (if (numberp level)
                         (* level gnus-topic-indent-level)
                       0))))
        (forward-line 1)))
    width))

(defun gnus-modern--group-count-widths ()
  "Return unread, total, and indentation widths for Group counts."
  (let ((unread-width 2)
        (total-width 1))
    (dolist (group (gnus-modern--group-groups))
      (let* ((entry (gnus-group-entry group))
             (unread (and entry (car entry))))
        (setq unread-width
              (max unread-width
                   (string-width
                    (if (numberp unread)
                        (number-to-string (max 0 unread))
                      "*")))
              total-width
              (max total-width
                   (string-width
                    (number-to-string
                     (gnus-modern--group-total group)))))))
    (setq total-width
          (+ total-width
             (max 0
                  (- gnus-modern-group-count-width
                     unread-width 1 total-width))))
    (list
     unread-width
     total-width
     (gnus-modern--group-max-indentation-width))))

(defun gnus-modern--group-format-row
    (group unread indentation width count-widths)
  "Format GROUP with UNREAD articles and INDENTATION for WIDTH using COUNT-WIDTHS."
  (let* ((unread-width
          (+ (nth 0 count-widths)
             (max
              0
              (- (nth 2 count-widths)
                 (string-width indentation)))))
         (total-width (nth 1 count-widths))
         (unread-number (and (numberp unread) (max 0 unread)))
         (unread-string
          (format
           (format "%%%ds" unread-width)
           (if unread-number (number-to-string unread-number) "*")))
         (total-string
          (number-to-string (gnus-modern--group-total group)))
         (unread-face
          (if (and unread-number (> unread-number 0))
              'gnus-modern-group-unread-face
            'gnus-modern-group-read-face))
         (count
          (concat
           (propertize unread-string 'face unread-face)
           (propertize "/" 'face 'gnus-modern-group-separator-face)
           (propertize total-string 'face 'gnus-modern-group-total-face)
           (make-string
            (max 0 (- total-width (string-width total-string)))
            ?\s)))
         (prefix (concat indentation count "  "))
         (source
          (propertize
           (gnus-modern--group-source group)
           'face 'gnus-modern-group-source-face))
         (name-width
          (max 0
               (- width
                  (string-width prefix)
                  (string-width source)
                  4)))
         (name
          (propertize
           (gnus-modern--truncate-string
            (gnus-group-real-name group)
            name-width)
           'face 'gnus-modern-group-name-face))
         (padding
          (make-string 2 ?\s)))
    (concat prefix name padding source)))

(defun gnus-modern--group-root-statistics (unread)
  "Return root Topic statistics containing UNREAD articles."
  (let* ((groups (gnus-modern--group-groups))
         (total
          (cl-loop
           for group in groups
           sum (gnus-modern--group-total group)))
         (unread (if (numberp unread) (max 0 unread) 0))
         (unread-face
          (if (> unread 0)
              'gnus-modern-group-topic-count-face
            'gnus-modern-group-topic-empty-count-face)))
    (concat
     (propertize
      (format "%d subscribed · " (length groups))
      'face 'gnus-modern-group-source-face)
     (propertize
      (number-to-string unread)
      'face unread-face)
     (propertize
      " unread · "
      'face 'gnus-modern-group-source-face)
     (propertize
      (number-to-string total)
      'face 'gnus-modern-group-total-face)
     (propertize
      " total"
      'face 'gnus-modern-group-source-face))))

(defun gnus-modern--group-root-unread ()
  "Return the unread count stored on the root Group Topic."
  (save-excursion
    (goto-char (point-min))
    (catch 'unread
      (while (not (eobp))
        (when (zerop
               (or (get-text-property
                    (line-beginning-position) 'gnus-topic-level)
                   -1))
          (throw
           'unread
           (or (get-text-property
                (line-beginning-position) 'gnus-topic-unread)
               0)))
        (forward-line 1))
      0)))

(defun gnus-modern--group-header ()
  "Return right-aligned Group statistics."
  (let* ((statistics
          (gnus-modern--group-root-statistics
           (gnus-modern--group-root-unread)))
         (header
          (concat
           (gnus-modern--right-padding statistics)
           statistics)))
    (add-face-text-property
     0 (length header) 'gnus-modern-header-face t header)
    header))

(defun gnus-modern--group-format-topic
    (topic level unread visible width)
  "Format TOPIC at LEVEL with UNREAD articles for WIDTH.
VISIBLE controls expansion."
  (let* ((prefix
          (if visible
              "  "
            (propertize
             "▸ " 'face 'gnus-modern-group-topic-face)))
         (count-string
          (number-to-string (if (numberp unread) unread 0)))
         (count
          (let ((face
                 (if (and (numberp unread) (> unread 0))
                     'gnus-modern-group-topic-count-face
                   'gnus-modern-group-topic-empty-count-face)))
            (propertize count-string 'face face)))
         (statistics
          (if (zerop level)
              ""
            (concat
             (propertize
              " (" 'face 'gnus-modern-group-separator-face)
             count
             (propertize
              ")" 'face 'gnus-modern-group-separator-face))))
         (title-width
          (max 0
               (- width
                  (string-width prefix)
                  (string-width statistics))))
         (title
          (propertize
           (gnus-modern--truncate-string topic title-width)
           'face 'gnus-modern-group-topic-face))
         (line (concat prefix title statistics)))
    (when-let* ((face
                 (cond
                  ((zerop level) 'gnus-modern-group-root-topic-face)
                  ((= level 1) 'gnus-modern-group-top-level-topic-face))))
      (add-face-text-property
       (length prefix)
       (length line)
       face t line))
    line))

(defun gnus-modern--group-preserved-properties ()
  "Return operational properties on the current Group buffer line."
  (let ((properties
         (text-properties-at (line-beginning-position)))
        preserved)
    (while properties
      (let ((property (pop properties))
            (value (pop properties)))
        (unless (memq property '(display face font-lock-face))
          (setq preserved
                (nconc preserved (list property value))))))
    preserved))

(defun gnus-modern--group-replace-line (string)
  "Replace the current Group buffer line with STRING."
  (let ((beginning (line-beginning-position))
        (end (line-end-position))
        (properties (gnus-modern--group-preserved-properties)))
    (delete-region beginning end)
    (insert string)
    (add-text-properties beginning (point) properties)))

(defun gnus-modern--group-groups ()
  "Return groups assigned to topics without duplicates."
  (let (groups)
    (dolist (topic gnus-topic-alist)
      (dolist (group (cdr topic))
        (when (stringp group)
          (cl-pushnew group groups :test #'equal))))
    groups))

(defun gnus-modern--group-add-topic-spacing (position trailing)
  "Add spacing around the Topic row at POSITION; TRAILING controls the lower gap."
  (save-excursion
    (goto-char position)
    (let* ((newline (line-end-position))
           (level
            (get-text-property position 'gnus-topic-level))
           (spacing
            (+ gnus-modern-group-topic-spacing-height
               (if (and (numberp level) (zerop level))
                   gnus-modern-header-bottom-spacing
                 0)))
           (prefix
            (gnus-modern--top-spacing-prefix spacing)))
      (when (< position (point-max))
        (add-text-properties
         position (1+ position)
         `(gnus-modern-group-topic-spacing t
                                       line-prefix ,prefix)))
      (when trailing
        (add-text-properties
         newline (1+ newline)
         `(gnus-modern-group-topic-spacing t
                                       line-spacing
                                       ,gnus-modern-group-topic-spacing-height))))))

(defun gnus-modern--group-remove-topic-spacing ()
  "Remove partial-line spacing added around Topics."
  (let ((limit (point-max))
        (position (point-min)))
    (while (setq position
                 (text-property-any
                  position limit
                  'gnus-modern-group-topic-spacing t))
      (let ((end
             (next-single-property-change
              position
              'gnus-modern-group-topic-spacing
              nil limit)))
        (remove-text-properties
         position end
         '(gnus-modern-group-topic-spacing nil
                                       line-prefix nil
                                       line-height nil
                                       line-spacing nil))
        (setq position end)))))

(defun gnus-modern--group-remove-decorations ()
  "Remove custom overview and separator lines from the Group buffer."
  (let ((inhibit-read-only t))
    (gnus-modern--group-remove-topic-spacing)
    (goto-char (point-min))
    (while (not (eobp))
      (if (get-text-property
           (line-beginning-position)
           'gnus-modern-group-decoration)
          (delete-region
           (line-beginning-position)
           (line-beginning-position 2))
        (forward-line 1)))))

(defun gnus-modern--group-topic-rows ()
  "Return Topic row positions paired with trailing-spacing flags."
  (let (rows)
    (goto-char (point-min))
    (while (not (eobp))
      (when (get-text-property
             (line-beginning-position) 'gnus-topic)
        (let* ((position (line-beginning-position))
               (next-line (line-beginning-position 2))
               (next-topic
                (get-text-property next-line 'gnus-topic)))
          (push (cons position (not next-topic)) rows)))
      (forward-line 1))
    (nreverse rows)))

(provide 'gnus-modern-group-format)
;;; gnus-modern-group-format.el ends here
