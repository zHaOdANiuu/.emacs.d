;;; gnus-modern-summary.el --- Custom Gnus Summary renderer  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: zdn <zhaodaniu1@gmail.com>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Replaces the native Gnus Summary line format with a custom renderer:
;; thread titles with article counts, month separators, foldable reply
;; trees, context lines for ancient articles, and a responsive
;; correspondent/date field.  One `gnus-modern-summary-renderer'
;; instance lives in each Summary buffer; it is permanent-local so
;; thread folds survive group switches.  Stateless formatting helpers
;; live in `gnus-modern-summary-format.el'.
;; Enable with `gnus-modern-summary-enable'.

;;; Code:

(require 'mail-parse)
(require 'nnheader)
(require 'gnus)
(require 'gnus-sum)
(require 'gnus-spec)
(require 'gnus-group)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-renderer)
(require 'gnus-modern-summary-format)

;; Bare defvar in gnus-spec.el; the declaration is dropped from the
;; compiled gnus-spec, so require cannot restore it.
(defvar gnus-tmp-unread)

(defvar-local gnus-modern--summary-renderer nil
  "Summary renderer instance of the current buffer.")

(defvar gnus-modern--summary-enabled nil
  "Non-nil when the custom Summary renderer is installed.")

(defvar gnus-modern--summary-original-user-format-function nil
  "Saved definition of `gnus-user-format-function-b'.")

(defconst gnus-modern--summary-line-format "    %U%R%O%z%*  %ub\n"
  "Gnus Summary format used by the custom renderer.")

(defconst gnus-modern--summary-setting-symbols
  '(gnus-summary-line-format
    header-line-format)
  "Buffer-local settings replaced by the custom renderer.")

(defun gnus-modern--current-summary-renderer ()
  "Return the Summary renderer instance of the current buffer."
  (or gnus-modern--summary-renderer
      (setq gnus-modern--summary-renderer
            (make-instance 'gnus-modern-summary-renderer))))

(defun gnus-modern--summary-insert-thread-lines (renderer threads width)
  "Insert thread title lines for THREADS with RENDERER into the current buffer."
  (let* ((count-width
          (gnus-modern--thread-count-width renderer threads))
         (month-data
          (when (gnus-modern--summary-threads-ordered-p threads)
            (gnus-modern--summary-month-data threads))))
    (dolist (thread (reverse threads))
      (gnus-modern--summary-insert-thread-line
       renderer thread width count-width month-data))))

(defun gnus-modern--summary-insert-thread-line
    (renderer thread width count-width month-data)
  "Insert one THREAD's title lines using RENDERER and layout data."
  (let ((root (car thread))
        (last (car (last thread)))
        (month-boundaries (car-safe month-data))
        (month-breaks (cdr-safe month-data)))
    (goto-char (gnus-data-pos last))
    (forward-line 1)
    (unless (or (eobp)
                (and month-data
                     (gethash
                      (gnus-data-number root) month-breaks)))
      (insert
       (gnus-modern--summary-decoration-line
        "" (gnus-data-number root) 'separator)))
    (goto-char (gnus-data-pos root))
    (beginning-of-line)
    (when-let* ((month
                 (and month-data
                      (gethash
                       (gnus-data-number root)
                       month-boundaries))))
      (insert
       (gnus-modern--summary-month-line
        (car month) (gnus-data-number root) (cdr month))))
    (insert
     (gnus-modern--summary-decoration-line
      (gnus-modern--thread-title
       renderer thread width count-width)
      (gnus-data-number root)
      'thread-title))
    (when-let*
        ((context
          (gnus-modern--thread-context-lines
           renderer thread width)))
      (insert
       (gnus-modern--summary-decoration-line
        context
        (gnus-data-number root)
        'thread-context)))))

(defclass gnus-modern-summary-renderer (gnus-modern-renderer)
  ((fold-state :initform (make-hash-table :test #'eql)
               :documentation
               "Article numbers whose replies are folded.")
   (context-prefixes :initform nil
                     :documentation
                     "Omitted thread-prefix headers keyed by retained root article.")
   (rendered-p :initform nil
               :documentation "Non-nil when the buffer is decorated.")
   (original-settings :initform nil
                      :documentation
                      "Settings replaced in the current Summary buffer."))
  :documentation "Buffer-local Summary renderer of gnus-modern.")

(cl-defmethod gnus-modern--configure-buffer
  ((renderer gnus-modern-summary-renderer))
  "Configure the current Gnus Summary buffer with RENDERER."
  (gnus-modern--save-settings renderer)
  (unless (hash-table-p (oref renderer fold-state))
    (oset renderer fold-state (make-hash-table :test #'eql)))
  (setq-local gnus-summary-line-format gnus-modern--summary-line-format)
  (setq-local header-line-format
              '(:eval (gnus-modern--summary-header)))
  (add-to-invisibility-spec 'gnus-modern-fold)
  (cl-call-next-method)
  (add-hook 'kill-buffer-hook #'gnus-modern--summary-cancel-timers nil t))

(cl-defmethod gnus-modern--save-settings ((renderer gnus-modern-summary-renderer))
  "Save settings replaced in the current Summary buffer with RENDERER."
  (unless (oref renderer original-settings)
    (oset renderer original-settings
          (mapcar
           (lambda (symbol)
             (cons symbol (symbol-value symbol)))
           gnus-modern--summary-setting-symbols))))

(cl-defmethod gnus-modern--restore-buffer ((renderer gnus-modern-summary-renderer))
  "Restore settings replaced in the current Summary buffer with RENDERER."
  (when (oref renderer original-settings)
    (gnus-modern--cancel-timers renderer)
    (let ((prepared gnus-newsgroup-prepared))
      (oset renderer rendered-p nil)
      (gnus-modern--summary-remove-decorations)
      (dolist (setting (oref renderer original-settings))
        (set (make-local-variable (car setting)) (cdr setting)))
      (remove-from-invisibility-spec 'gnus-modern-fold)
      (oset renderer original-settings nil)
      (oset renderer fold-state nil)
      (oset renderer render-width nil)
      (oset renderer configured-p nil)
      (gnus-modern--summary-update-format)
      (when prepared
        (gnus-summary-prepare)))))

(cl-defmethod gnus-modern--reset-render-state
  ((renderer gnus-modern-summary-renderer))
  "Reset transient render state with RENDERER before Gnus builds a Summary."
  (oset renderer rendered-p nil)
  (gnus-modern--summary-remove-fold-overlays)
  (gnus-modern--summary-remove-context-overlays))

(cl-defmethod gnus-modern--decorate ((renderer gnus-modern-summary-renderer))
  "Decorate the current native Gnus Summary buffer with RENDERER."
  (when (and gnus-modern--summary-enabled
             (oref renderer original-settings)
             (derived-mode-p 'gnus-summary-mode))
    (let ((article (gnus-modern--summary-selection-article))
          (threads (gnus-modern--summary-threads))
          (width (gnus-modern--summary-width))
          (inhibit-read-only t))
      (oset renderer rendered-p nil)
      (save-excursion
        (gnus-modern--summary-remove-decorations)
        (gnus-modern--summary-apply-correspondent-faces)
        (gnus-data-compute-positions)
        (gnus-modern--summary-align-mark-columns)
        (gnus-modern--summary-apply-mark-faces)
        (gnus-modern--summary-insert-thread-lines
         renderer threads width)
        (gnus-data-compute-positions)
        (gnus-modern--summary-apply-context-faces)
        (gnus-modern--apply-folds renderer threads))
      (oset renderer render-width width)
      (oset renderer rendered-p t)
      (setq-local header-line-format
                  '(:eval (gnus-modern--summary-header)))
      (gnus-modern--summary-restore-selection article)
      (force-mode-line-update))))

(cl-defmethod gnus-modern--apply-folds ((renderer gnus-modern-summary-renderer)
                                        threads)
  "Apply saved folds to THREADS with RENDERER."
  (gnus-modern--summary-remove-fold-overlays)
  (dolist (thread threads)
    (dolist (data thread)
      (let ((article (gnus-data-number data)))
        (when (gethash article (oref renderer fold-state))
          (gnus-modern--summary-apply-fold article thread))))))

(cl-defmethod gnus-modern--thread-count-label
  ((renderer gnus-modern-summary-renderer) thread &optional face)
  "Return the article-count label for THREAD with RENDERER."
  (let* ((context
          (cl-count-if #'gnus-modern--summary-context-data-p thread))
         (omitted
          (length
           (and (hash-table-p (oref renderer context-prefixes))
                (gethash
                 (gnus-data-number (car thread))
                 (oref renderer context-prefixes)))))
         (total (- (length thread) context))
         (unread (gnus-modern--summary-thread-unread-count thread))
         (label
          (if (> unread 0)
              (format "%d/%d" unread total)
            (number-to-string total)))
         (label
          (concat label (and (> (+ context omitted) 0) "+"))))
    (if face
        (propertize label 'face face)
      label)))

(cl-defmethod gnus-modern--thread-count-width
  ((renderer gnus-modern-summary-renderer) threads)
  "Return the widest article-count label in THREADS with RENDERER."
  (max
   gnus-modern-summary-thread-count-digits
   (cl-loop for thread in threads
            maximize
            (string-width
             (gnus-modern--thread-count-label renderer thread))
            into width
            finally return (or width 0))))

(cl-defmethod gnus-modern--thread-title
  ((renderer gnus-modern-summary-renderer) thread width count-width)
  "Return a title for THREAD fitted to WIDTH with RENDERER."
  (let* ((header (gnus-data-header (car thread)))
         (unread (gnus-modern--summary-thread-unread-count thread))
         (padding-width
          (max 0.0
               (min 0.5 gnus-modern-summary-thread-count-padding)))
         (count-face
          (if (> unread 0)
              'gnus-modern-summary-unread-thread-count-face
            'gnus-modern-summary-thread-count-face))
         (label
          (gnus-modern--thread-count-label renderer thread count-face))
         (count
          (concat
           (make-string
            (max 0 (- count-width (string-width label)))
            ?\s)
           (gnus-modern--summary-space padding-width count-face)
           label
           (gnus-modern--summary-space padding-width count-face)))
         (reserved (+ count-width (* 2 padding-width) 1))
         (subject
          (gnus-modern--truncate-string
           (gnus-modern--sanitize-single-line
            (mail-header-subject header))
           (max 0 (floor (- width reserved)))))
         (line (concat count " " subject)))
    (font-lock-append-text-property
     0 (length line)
     'font-lock-face 'gnus-modern-summary-title-face line)
    line))

(cl-defmethod gnus-modern--thread-context-lines
  ((renderer gnus-modern-summary-renderer) thread width)
  "Return omitted context lines for THREAD fitted to WIDTH with RENDERER."
  (when (hash-table-p (oref renderer context-prefixes))
    (when-let*
        ((headers
          (gethash
           (gnus-data-number (car thread))
           (oref renderer context-prefixes))))
      (mapconcat
       (lambda (header)
         (gnus-modern--summary-context-line header width))
       headers "\n"))))

(cl-defmethod gnus-modern--decorate-p ((renderer gnus-modern-summary-renderer))
  "Return non-nil when RENDERER should decorate the current buffer."
  (oref renderer rendered-p))

(cl-defmethod gnus-modern--rerender-p ((renderer gnus-modern-summary-renderer))
  "Return non-nil when RENDERER should re-render the current buffer."
  (and (oref renderer original-settings) gnus-newsgroup-prepared))

(cl-defmethod gnus-modern--rerender-now ((_renderer gnus-modern-summary-renderer))
  "Re-render the current buffer after a resize."
  (let ((article (gnus-modern--summary-selection-article)))
    (gnus-summary-prepare)
    (gnus-modern--summary-restore-selection article)))

(cl-defmethod gnus-modern--fallback-width
  ((_renderer gnus-modern-summary-renderer))
  "Return the width used when no Summary window is live."
  gnus-modern-summary-fallback-width)

(cl-defmethod cl-print-object ((object gnus-modern-summary-renderer) stream)
  "Print a compact description of OBJECT to STREAM."
  (princ (format "#<summary-renderer %s width=%s folds=%d>"
                 (if (oref object rendered-p) "rendered" "idle")
                 (or (oref object render-width) "-")
                 (hash-table-count (oref object fold-state)))
         stream))

(cl-defmethod gnus-modern--fold-toggle ((renderer gnus-modern-summary-renderer))
  "Toggle folding of replies to the article at point with RENDERER."
  (let* ((article (gnus-summary-article-number))
         (thread
          (and article
               (gnus-modern--summary-thread-for-article article)))
         (descendants
          (and thread
               (gnus-modern--summary-descendants article thread))))
    (unless thread
      (user-error "No article thread at point"))
    (unless descendants
      (user-error "The current article has no replies"))
    (if (gethash article (oref renderer fold-state))
        (progn
          (remhash article (oref renderer fold-state))
          (remove-overlays
           (point-min) (point-max)
           'gnus-modern-fold-anchor article))
      (puthash article t (oref renderer fold-state))
      (gnus-modern--summary-apply-fold article thread))
    (gnus-modern--summary-restore-selection article)))

(defun gnus-modern--summary-restore-selection (article)
  "Restore point to ARTICLE when it remains available."
  (when (and article
             (gnus-summary-goto-subject article nil t))
    (gnus-modern--summary-position-point)
    (let ((position (point)))
      (dolist (window (get-buffer-window-list (current-buffer) nil t))
        (set-window-point window position))))
  (when gnus-current-article
    (save-excursion
      (when (gnus-summary-goto-subject
             gnus-current-article nil t)
        (gnus-highlight-selected-summary))))
  (gnus-modern--summary-refresh-hl-line))

(defun gnus-modern--summary-selection-article ()
  "Return the Summary article whose point should survive a render."
  (let ((point-article
         (get-text-property (point) 'gnus-number)))
    (if (eq (window-buffer (selected-window)) (current-buffer))
        (or point-article gnus-current-article)
      (or gnus-current-article point-article))))

(defun gnus-modern--summary-update-format ()
  "Recompile the current Summary format and mark positions."
  (gnus-update-format-specifications
   t 'summary 'summary-mode 'summary-dummy)
  (gnus-update-summary-mark-positions))

(defun gnus-modern--summary-mode-hook ()
  "Configure the current Summary buffer's renderer."
  (gnus-modern--configure-buffer
   (gnus-modern--current-summary-renderer)))

(defun gnus-modern--summary-generate-hook ()
  "Reset render state before Gnus builds a Summary."
  (gnus-modern--reset-render-state
   (gnus-modern--current-summary-renderer)))

(defun gnus-modern--summary-prepare-hook ()
  "Decorate the current Summary buffer."
  (gnus-modern--decorate
   (gnus-modern--current-summary-renderer)))

(defun gnus-modern--summary-schedule-decoration ()
  "Schedule decoration after a native Summary line update."
  (when (and gnus-modern--summary-renderer
             (oref gnus-modern--summary-renderer rendered-p))
    (gnus-modern--schedule-decoration
     gnus-modern--summary-renderer)))

(defun gnus-modern--summary-cancel-timers ()
  "Cancel timers owned by the current buffer's Summary renderer."
  (when gnus-modern--summary-renderer
    (gnus-modern--cancel-timers gnus-modern--summary-renderer)))

(defun gnus-modern--summary-cut-threads-advice (function threads)
  "Call FUNCTION on THREADS and remember omitted context roots."
  (if (and gnus-modern--summary-enabled
           (derived-mode-p 'gnus-summary-mode))
      (let* ((renderer (gnus-modern--current-summary-renderer))
             (originals (copy-sequence threads))
             (cut-threads (funcall function threads)))
        (oset renderer context-prefixes (make-hash-table :test #'eql))
        (dolist (thread cut-threads)
          (when (mail-header-p (car-safe thread))
            (when-let*
                ((path
                  (cl-loop
                   for original in originals
                   for candidate =
                   (gnus-modern--summary-thread-subtree-path
                    original thread)
                   when candidate return candidate))
                 (headers
                  (cl-remove-if-not #'mail-header-p (cdr path))))
              (puthash
               (mail-header-number (car thread))
               headers
               (oref renderer context-prefixes)))))
        cut-threads)
    (funcall function threads)))

(defun gnus-modern--summary-limit-advice (function articles &optional pop)
  "Keep thread context when FUNCTION applies ARTICLES.
POP selects the existing limit."
  (when (and gnus-modern--summary-enabled
             (derived-mode-p 'gnus-summary-mode))
    (if pop
        (when gnus-newsgroup-limits
          (setcar
           gnus-newsgroup-limits
           (gnus-modern--summary-limit-with-context
            (car gnus-newsgroup-limits))))
      (setq articles
            (gnus-modern--summary-limit-with-context articles))))
  (funcall function articles pop))

(defun gnus-modern--summary-install ()
  "Install the custom Gnus Summary renderer."
  (unless gnus-modern--summary-enabled
    (setq gnus-modern--summary-enabled t
          gnus-modern--summary-original-user-format-function
          (if (fboundp 'gnus-user-format-function-b)
              (symbol-function 'gnus-user-format-function-b)
            :unbound))
    (fset 'gnus-user-format-function-b
          #'gnus-modern-summary-format-message)
    (advice-add
     'gnus-cut-threads
     :around #'gnus-modern--summary-cut-threads-advice)
    (advice-add
     'gnus-summary-limit
     :around #'gnus-modern--summary-limit-advice)
    (add-hook 'gnus-summary-mode-hook
              #'gnus-modern--summary-mode-hook)
    (add-hook 'gnus-summary-generate-hook
              #'gnus-modern--summary-generate-hook)
    (add-hook 'gnus-summary-prepare-hook
              #'gnus-modern--summary-prepare-hook)
    (add-hook 'gnus-summary-update-hook
              #'gnus-modern--summary-schedule-decoration)
    (add-hook 'window-size-change-functions
              #'gnus-modern--window-size-change-hook)
    (dolist (buffer (gnus-modern--summary-buffers))
      (with-current-buffer buffer
        (gnus-modern--configure-buffer
         (gnus-modern--current-summary-renderer))
        (gnus-modern--summary-update-format)
        (when gnus-newsgroup-prepared
          (gnus-summary-prepare)))))
  t)

(defun gnus-modern--summary-header ()
  "Return right-aligned Summary statistics."
  (let* ((statistics (gnus-modern--summary-header-statistics))
         (header
          (concat
           (gnus-modern--right-padding statistics)
           statistics)))
    (add-face-text-property
     0 (length header) 'gnus-modern-header-face t header)
    header))

(defun gnus-modern--summary-header-statistics ()
  "Return the Summary statistics shown right-aligned in the header."
  (let* ((name (or gnus-newsgroup-name "No group"))
         (unread (length gnus-newsgroup-unreads))
         (loaded (length gnus-newsgroup-data))
         (unread-face
          (if (> unread 0)
              'gnus-modern-summary-group-unread-face
            'gnus-modern-summary-group-empty-unread-face))
         (label-face 'gnus-modern-summary-group-face)
         (name
          (propertize
           (gnus-group-real-name name)
           'face 'gnus-modern-summary-group-name-face))
         (unread-text
          (propertize
           (format "%d unread" unread)
           'face unread-face))
         (loaded-text
          (propertize
           (format "%d loaded" loaded)
           'face 'gnus-modern-summary-group-loaded-face)))
    (concat
     (propertize " " 'face label-face)
     name
     (propertize " · " 'face label-face)
     unread-text
     (propertize " · " 'face label-face)
     loaded-text)))

(defun gnus-modern-summary-format-message (header)
  "Return the responsive correspondent and date fields for HEADER."
  (let* ((prefix
          (if (stringp gnus-tmp-thread-tree-header-string)
              gnus-tmp-thread-tree-header-string
            ""))
         (date (gnus-modern--summary-date header))
         (name (gnus-modern--summary-contact-name
                (mail-header-from header)))
         (date-col
          (max 0 (- (gnus-modern--summary-width)
                    (string-width date))))
         (name-width
          (max 0 (- date-col gnus-modern--summary-prefix-width
                    (string-width prefix) 1)))
         (name (gnus-modern--truncate-string name name-width))
         (name
          (propertize
           name 'gnus-modern-correspondent-face
           (if (= gnus-tmp-unread gnus-unread-mark)
               'gnus-modern-summary-unread-correspondent-face
             'gnus-modern-summary-correspondent-face)))
         (date
          (propertize date 'face 'gnus-modern-summary-timestamp-face)))
    (concat prefix name
            (propertize " " 'display `(space :align-to ,date-col))
            date)))

;;;###autoload
(defun gnus-modern-summary-disable ()
  "Restore Gnus's native Summary renderer."
  (interactive)
  (when gnus-modern--summary-enabled
    (setq gnus-modern--summary-enabled nil)
    (remove-hook 'gnus-summary-mode-hook
                 #'gnus-modern--summary-mode-hook)
    (remove-hook 'gnus-summary-generate-hook
                 #'gnus-modern--summary-generate-hook)
    (remove-hook 'gnus-summary-prepare-hook
                 #'gnus-modern--summary-prepare-hook)
    (remove-hook 'gnus-summary-update-hook
                 #'gnus-modern--summary-schedule-decoration)
    (remove-hook 'window-size-change-functions
                 #'gnus-modern--window-size-change-hook)
    (advice-remove
     'gnus-cut-threads
     #'gnus-modern--summary-cut-threads-advice)
    (advice-remove
     'gnus-summary-limit
     #'gnus-modern--summary-limit-advice)
    (if (eq gnus-modern--summary-original-user-format-function :unbound)
        (fmakunbound 'gnus-user-format-function-b)
      (fset 'gnus-user-format-function-b
            gnus-modern--summary-original-user-format-function))
    (setq gnus-modern--summary-original-user-format-function nil)
    (dolist (buffer (gnus-modern--summary-buffers))
      (with-current-buffer buffer
        (when gnus-modern--summary-renderer
          (gnus-modern--restore-buffer
           gnus-modern--summary-renderer)
          (setq gnus-modern--summary-renderer nil))))))

;;;###autoload
(defun gnus-modern-summary-enable ()
  "Enable the gnus-modern multi-line Summary renderer."
  (interactive)
  (with-eval-after-load 'gnus-sum
    (gnus-modern--summary-install)))

;;;###autoload
(defun gnus-modern-summary-fold-toggle ()
  "Toggle folding of replies to the article at point."
  (interactive)
  (unless (and (gnus-modern--summary-article-buffer-p)
               gnus-modern--summary-renderer
               (oref gnus-modern--summary-renderer rendered-p))
    (user-error "The custom Gnus Summary renderer is not active"))
  (gnus-modern--fold-toggle gnus-modern--summary-renderer))

(put 'gnus-modern--summary-renderer 'permanent-local t)

(provide 'gnus-modern-summary)
;;; gnus-modern-summary.el ends here
