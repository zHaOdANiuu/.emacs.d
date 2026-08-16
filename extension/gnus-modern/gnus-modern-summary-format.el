;;; gnus-modern-summary-format.el --- Summary formatting helpers  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: zdn <zhaodaniu1@gmail.com>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Stateless formatting and folding helpers of the custom Gnus Summary
;; renderer: thread splitting and month data, title and context lines,
;; mark faces and alignment, fold overlays, and decoration removal.
;; The buffer-local renderer and its methods live in
;; `gnus-modern-summary.el'.

;;; Code:

(require 'cl-lib)
(require 'mail-parse)
(require 'nnheader)
(require 'hl-line)
(require 'gnus)
(require 'gnus-sum)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-renderer)

(defconst gnus-modern--summary-prefix-width 10
  "Columns reserved before the thread-tree prefix.")

(defun gnus-modern--summary-space (width &optional face)
  "Return spacing WIDTH character widths wide using optional FACE."
  (let* ((width (max 0.0 width))
         (whole (floor width))
         (fraction (- width whole))
         (space (make-string whole ?\s)))
    (when (> fraction 0.001)
      (setq space
            (concat
             space
             (propertize
              " " 'display `(space :width ,fraction)))))
    (when (and face (not (string-empty-p space)))
      (put-text-property 0 (length space) 'face face space))
    space))

(defun gnus-modern--summary-width ()
  "Return the display width for the current Summary buffer."
  (gnus-modern--renderer-width
   (current-buffer) gnus-modern-summary-fallback-width))

(defun gnus-modern--summary-contact-name (address)
  "Return a compact display name for ADDRESS."
  (let* ((parsed
          (and (stringp address)
               (mail-header-parse-address-lax address)))
         (email (if (consp parsed) (car parsed) parsed))
         (name (and (consp parsed) (cdr parsed)))
         (name
          (and (stringp name)
               (string-trim
                (replace-regexp-in-string
                 "[\n\r][ \t]+" " " name)))))
    (when (and name
               (> (length name) 1)
               (string-prefix-p "\"" name)
               (string-suffix-p "\"" name))
      (setq name (string-trim (substring name 1 -1))))
    (gnus-modern--sanitize-single-line
     (or (and name (not (string-empty-p name)) name)
         (and (stringp email) email)
         address
         "?"))))

(defun gnus-modern--summary-date (header)
  "Return the formatted date from HEADER."
  (let* ((date (mail-header-date header))
         (blank
          (make-string
           (string-width
            (format-time-string gnus-modern-summary-date-format '(0 0)))
           ?\s)))
    (if (and (stringp date) (not (string-empty-p date)))
        (condition-case err
            (format-time-string gnus-modern-summary-date-format
                                (date-to-time date))
          (error
           (message "gnus-modern: unparseable date %S: %s"
                    date (error-message-string err))
           blank))
      blank)))

(defun gnus-modern--summary-context-article-p (article)
  "Return non-nil when ARTICLE exists only as thread context."
  (or (memq article gnus-newsgroup-ancient)
      (memq article gnus-newsgroup-sparse)))

(defun gnus-modern--summary-context-data-p (data)
  "Return non-nil when DATA exists only to connect visible articles."
  (gnus-modern--summary-context-article-p (gnus-data-number data)))

(defun gnus-modern--summary-limit-with-context (articles)
  "Return ARTICLES together with their available context ancestors."
  (if (not (hash-table-p gnus-newsgroup-dependencies))
      articles
    (let ((headers (make-hash-table :test #'eql))
          (ids (make-hash-table :test #'equal))
          (included (make-hash-table :test #'eql))
          pending result)
      (maphash
       (lambda (_id dependencies)
         (when-let* ((header (car dependencies)))
           (let ((number (mail-header-number header))
                 (id (mail-header-id header)))
             (puthash number header headers)
             (when id
               (puthash id number ids)))))
       gnus-newsgroup-dependencies)
      (dolist (article articles)
        (unless (gethash article included)
          (puthash article t included)
          (push article pending)
          (push article result)))
      (while pending
        (when-let* ((header (gethash (pop pending) headers))
                    (references (mail-header-references header)))
          (dolist (id (gnus-split-references references))
            (when-let* ((article (gethash id ids))
                        ((gnus-modern--summary-context-article-p article))
                        ((not (gethash article included))))
              (puthash article t included)
              (push article pending)
              (push article result)))))
      (sort result #'<))))

(defun gnus-modern--summary-thread-subtree-path (thread target)
  "Return the headers leading from THREAD to TARGET."
  (cond
   ((eq thread target)
    '(t))
   ((consp thread)
    (cl-loop
     for child in (cdr thread)
     for path = (gnus-modern--summary-thread-subtree-path child target)
     when path
     return (cons t (cons (car thread) (cdr path)))))))

(defun gnus-modern--summary-important-data-p (data)
  "Return non-nil when DATA should remain visible in a folded thread."
  (let ((number (gnus-data-number data))
        (mark (gnus-data-mark data)))
    (or (= mark gnus-unread-mark)
        (= mark gnus-ticked-mark)
        (= mark gnus-dormant-mark)
        (memq number gnus-newsgroup-processable))))

(defun gnus-modern--summary-threads ()
  "Return `gnus-newsgroup-data' split into top-level threads."
  (let (current threads)
    (dolist (data gnus-newsgroup-data)
      (when (and current (zerop (gnus-data-level data)))
        (push (nreverse current) threads)
        (setq current nil))
      (push data current))
    (when current
      (push (nreverse current) threads))
    (nreverse threads)))

(defun gnus-modern--summary-root-date (thread)
  "Return THREAD's root-article date, or nil when it has none."
  (let ((date (mail-header-date (gnus-data-header (car thread)))))
    (when (and (stringp date) (not (string-empty-p date)))
      (condition-case err
          (date-to-time date)
        (error
         (message "gnus-modern: unparseable root date %S: %s"
                  date (error-message-string err))
         nil)))))

(defun gnus-modern--summary-root-month (thread)
  "Return the month key and title of THREAD's root article."
  (when-let* ((date (gnus-modern--summary-root-date thread)))
    (cons (format-time-string "%Y-%m" date)
          (format-time-string gnus-modern-summary-month-format date))))

(defun gnus-modern--summary-threads-ordered-p (threads)
  "Return non-nil when THREADS have descending root-article dates."
  (let (previous
        (ordered-p t))
    (while (and ordered-p threads)
      (when-let* ((date (gnus-modern--summary-root-date (car threads))))
        (when (and previous (time-less-p previous date))
          (setq ordered-p nil))
        (setq previous date))
      (setq threads (cdr threads)))
    ordered-p))

(defun gnus-modern--summary-month-data (threads)
  "Return month boundaries and preceding breaks for THREADS."
  (let ((boundaries (make-hash-table :test #'eql))
        (breaks (make-hash-table :test #'eql))
        previous
        last-month
        (first-p t))
    (dolist (thread threads)
      (let* ((root (car thread))
             (article (gnus-data-number root))
             (month (gnus-modern--summary-root-month thread))
             (key (car-safe month))
             (title (cdr-safe month)))
        (when (and key (not (equal key last-month)))
          (puthash article (cons title first-p) boundaries)
          (when previous
            (puthash previous t breaks))
          (setq first-p nil
                last-month key))
        (setq previous article)))
    (cons boundaries breaks)))

(defun gnus-modern--summary-thread-unread-count (thread)
  "Return the number of unread articles in THREAD."
  (cl-count-if
   (lambda (data)
     (and (not (gnus-modern--summary-context-data-p data))
          (= (gnus-data-mark data) gnus-unread-mark)))
   thread))

(defun gnus-modern--summary-decoration-line (string article kind)
  "Return a decoration line containing STRING for ARTICLE and KIND."
  (propertize
   (concat string "\n")
   'gnus-modern-decoration kind
   'gnus-intangible article
   'rear-nonsticky t))

(defun gnus-modern--summary-month-line (title article first-p)
  "Return a month separator for TITLE anchored to ARTICLE.
FIRST-P controls spacing."
  (let* ((top-spacing
          (+ gnus-modern-summary-month-line-spacing
             (if first-p gnus-modern-header-bottom-spacing 0)))
         (line
          (gnus-modern--summary-decoration-line
           (concat "  " title) article 'month-separator))
         (newline (1- (length line))))
    (add-text-properties
     0 (length line)
     '(face gnus-modern-summary-month-face)
     line)
    (add-text-properties
     0 1
     `(line-prefix ,(gnus-modern--top-spacing-prefix top-spacing))
     line)
    (add-text-properties
     newline (length line)
     `(line-spacing ,gnus-modern-summary-month-line-spacing)
     line)
    line))

(defun gnus-modern--summary-context-line (header width)
  "Return an unselectable context line for HEADER fitted to WIDTH."
  (let* ((prefix
          (concat
           (make-string gnus-modern--summary-prefix-width ?\s)
           "…  "))
         (date (gnus-modern--summary-date header))
         (name
          (gnus-modern--summary-contact-name
           (mail-header-from header)))
         (available
          (max
           0
           (- width
              (string-width prefix)
              (string-width date)
              1)))
         (name (gnus-modern--truncate-string name available))
         (padding
          (make-string
           (max 1 (- available (string-width name)))
           ?\s)))
    (propertize
     (concat prefix name padding date)
     'face 'gnus-modern-summary-context-face)))

(defun gnus-modern--summary-remove-fold-overlays ()
  "Remove fold overlays owned by the custom Summary renderer."
  (remove-overlays
   (point-min) (point-max) 'gnus-modern-fold-overlay t))

(defun gnus-modern--summary-remove-context-overlays ()
  "Remove context overlays owned by the custom Summary renderer."
  (remove-overlays
   (point-min) (point-max) 'gnus-modern-context-overlay t))

(defun gnus-modern--summary-remove-mark-alignment ()
  "Remove display spacing used to align Summary mark columns."
  (let ((limit (point-max))
        (position (point-min)))
    (while (setq position
                 (text-property-any
                  position limit 'gnus-modern-mark-alignment t))
      (let ((end
             (next-single-property-change
              position 'gnus-modern-mark-alignment nil limit)))
        (remove-text-properties
         position end
         '(gnus-modern-mark-alignment nil display nil))
        (setq position end)))))

(defun gnus-modern--summary-primary-mark-face (mark)
  "Return the face appropriate for primary article MARK."
  (cond
   ((= mark gnus-unread-mark)
    'gnus-modern-summary-unread-mark-face)
   ((memq mark (list gnus-ticked-mark gnus-dormant-mark))
    'gnus-modern-summary-attention-mark-face)
   ((memq mark
          (list gnus-ancient-mark gnus-expirable-mark
                gnus-del-mark gnus-read-mark gnus-catchup-mark
                gnus-sparse-mark))
    'gnus-modern-summary-quiet-mark-face)
   ((memq mark
          (list gnus-killed-mark gnus-spam-mark
                gnus-kill-file-mark gnus-low-score-mark
                gnus-canceled-mark gnus-duplicate-mark))
    'gnus-modern-summary-negative-mark-face)))

(defun gnus-modern--summary-secondary-mark-face (mark)
  "Return the face appropriate for secondary article MARK."
  (cond
   ((= mark gnus-process-mark)
    'gnus-modern-summary-attention-mark-face)
   ((memq mark (list gnus-cached-mark gnus-saved-mark))
    'gnus-modern-summary-stored-mark-face)
   ((memq mark
          (list gnus-replied-mark gnus-forwarded-mark
                gnus-unseen-mark))
    'gnus-modern-summary-activity-mark-face)))

(defun gnus-modern--summary-download-mark-face (mark)
  "Return the face appropriate for Agent download MARK."
  (cond
   ((= mark gnus-downloaded-mark)
    'gnus-modern-summary-stored-mark-face)
   ((= mark gnus-undownloaded-mark)
    'gnus-modern-summary-quiet-mark-face)
   ((= mark gnus-downloadable-mark)
    'gnus-modern-summary-attention-mark-face)
   ((= mark gnus-unsendable-mark)
    'gnus-modern-summary-negative-mark-face)))

(defun gnus-modern--summary-score-mark-face (mark)
  "Return the face appropriate for article score MARK."
  (cond
   ((= mark gnus-score-over-mark)
    'gnus-modern-summary-stored-mark-face)
   ((= mark gnus-score-below-mark)
    'gnus-modern-summary-negative-mark-face)))

(defun gnus-modern--summary-mark-face (kind mark)
  "Return the face for mark KIND whose character is MARK."
  (pcase kind
    ('unread (gnus-modern--summary-primary-mark-face mark))
    ('replied (gnus-modern--summary-secondary-mark-face mark))
    ('download (gnus-modern--summary-download-mark-face mark))
    ('score (gnus-modern--summary-score-mark-face mark))))

(defun gnus-modern--summary-remove-mark-faces ()
  "Remove faces previously added to individual Summary marks."
  (let ((position (point-min)))
    (while (setq position
                 (text-property-not-all
                  position (point-max) 'gnus-modern-mark-face nil))
      (let* ((end
              (next-single-property-change
               position 'gnus-modern-mark-face nil (point-max)))
             (mark-face
              (get-text-property position 'gnus-modern-mark-face))
             (current (get-text-property position 'face))
             (faces
              (cond
               ((eq current mark-face) nil)
               ((listp current)
                (delq mark-face (copy-sequence current)))
               (t current))))
        (put-text-property position end 'face faces)
        (remove-text-properties
         position end '(gnus-modern-mark-face nil))
        (setq position end)))))

(defun gnus-modern--summary-apply-mark-faces ()
  "Apply semantic faces to visible Summary status marks."
  (gnus-modern--summary-remove-mark-faces)
  (dolist (data gnus-newsgroup-data)
    (save-excursion
      (goto-char (gnus-data-pos data))
      (let ((start (line-beginning-position))
            (end (line-end-position)))
        (dolist (entry gnus-summary-mark-positions)
          (when-let* ((offset (cdr entry))
                      (position (+ start offset))
                      ((< position end))
                      (mark
                       (if (eq (car entry) 'unread)
                           (gnus-data-mark data)
                         (char-after position)))
                      ((not (= mark ?\s)))
                      (face
                       (gnus-modern--summary-mark-face
                        (car entry) mark)))
            (add-face-text-property
             position (1+ position) face nil)
            (put-text-property
             position (1+ position) 'gnus-modern-mark-face face)))))))

(defun gnus-modern--summary-align-mark-columns ()
  "Right-align article marks with thread count labels."
  (gnus-modern--summary-remove-mark-alignment)
  (dolist (data gnus-newsgroup-data)
    (save-excursion
      (goto-char (gnus-data-pos data))
      (let ((start (line-beginning-position))
            (end (line-end-position)))
        (when (and (< (+ start 8) end)
                   (eq (char-after (+ start 3)) ?\s)
                   (eq (char-after (+ start 8)) ?\s))
          (add-text-properties
           (+ start 3) (+ start 4)
           '(gnus-modern-mark-alignment t
                                    display (space :width 1.5)))
          (add-text-properties
           (+ start 8) (+ start 9)
           '(gnus-modern-mark-alignment t
                                    display (space :width 0.5))))))))

(defun gnus-modern--summary-remove-decorations ()
  "Remove custom title and separator lines from the current buffer."
  (gnus-modern--summary-remove-fold-overlays)
  (gnus-modern--summary-remove-context-overlays)
  (gnus-modern--summary-remove-mark-alignment)
  (gnus-modern--summary-remove-mark-faces)
  (let ((inhibit-read-only t))
    (goto-char (point-min))
    (while (not (eobp))
      (if (get-text-property (point) 'gnus-modern-decoration)
          (delete-region
           (line-beginning-position)
           (line-beginning-position 2))
        (forward-line 1)))))

(defun gnus-modern--summary-thread-for-article (article)
  "Return the thread containing ARTICLE."
  (cl-find-if
   (lambda (thread)
     (cl-find article thread :key #'gnus-data-number))
   (gnus-modern--summary-threads)))

(defun gnus-modern--summary-descendants (article thread)
  "Return descendants of ARTICLE within THREAD."
  (when-let* ((tail
               (cl-member article thread :key #'gnus-data-number)))
    (let ((level (gnus-data-level (car tail))))
      (cl-loop for data in (cdr tail)
               while (> (gnus-data-level data) level)
               collect data))))

(defun gnus-modern--summary-add-fold-indicator (article thread)
  "Display a fold indicator on ARTICLE within THREAD."
  (when-let* ((data
               (cl-find article thread :key #'gnus-data-number)))
    (save-excursion
      (goto-char (gnus-data-pos data))
      (let ((position (line-beginning-position)))
        (when (eq (char-after position) ?\s)
          (let ((overlay
                 (make-overlay position (1+ position) nil t nil)))
            (overlay-put
             overlay 'display
             (propertize
              (char-to-string gnus-modern-summary-fold-indicator)
              'face 'gnus-modern-summary-fold-indicator-face))
            (overlay-put overlay 'evaporate t)
            (overlay-put overlay 'gnus-modern-fold-overlay t)
            (overlay-put overlay 'gnus-modern-fold-indicator t)
            (overlay-put overlay 'gnus-modern-fold-anchor article)))))))

(defun gnus-modern--summary-apply-fold (article thread)
  "Hide unimportant descendants of ARTICLE within THREAD."
  (gnus-modern--summary-add-fold-indicator article thread)
  (dolist (data (gnus-modern--summary-descendants article thread))
    (unless (gnus-modern--summary-important-data-p data)
      (save-excursion
        (goto-char (gnus-data-pos data))
        (let ((overlay
               (make-overlay
                (line-beginning-position)
                (line-beginning-position 2)
                nil t nil)))
          (overlay-put overlay 'invisible 'gnus-modern-fold)
          (overlay-put overlay 'evaporate t)
          (overlay-put overlay 'gnus-modern-fold-overlay t)
          (overlay-put overlay 'gnus-modern-fold-anchor article))))))

(defun gnus-modern--summary-apply-context-faces ()
  "Visually weaken articles displayed only as thread context."
  (gnus-modern--summary-remove-context-overlays)
  (dolist (data gnus-newsgroup-data)
    (when (gnus-modern--summary-context-data-p data)
      (save-excursion
        (goto-char (gnus-data-pos data))
        (let ((overlay
               (make-overlay
                (line-beginning-position)
                (line-end-position)
                nil t nil)))
          (overlay-put overlay 'face 'gnus-modern-summary-context-face)
          (overlay-put overlay 'evaporate t)
          (overlay-put overlay 'gnus-modern-context-overlay t))))))

(defun gnus-modern--summary-refresh-hl-line ()
  "Move the current Summary buffer's Hl-Line overlay to point."
  (when (bound-and-true-p hl-line-mode)
    (if (overlayp hl-line-overlay)
        (hl-line-move hl-line-overlay)
      (when-let* ((window
                   (get-buffer-window (current-buffer) t)))
        (with-selected-window window
          (hl-line-highlight))))))

(defun gnus-modern--summary-apply-correspondent-faces ()
  "Restore correspondent faces after Gnus applies article-line faces."
  (let ((position (point-min)))
    (while (setq position
                 (text-property-not-all
                  position (point-max)
                  'gnus-modern-correspondent-face nil))
      (let* ((article
              (get-text-property position 'gnus-number))
             (data (and article (gnus-data-find article)))
             (face
              (if data
                  (if (= (gnus-data-mark data) gnus-unread-mark)
                      'gnus-modern-summary-unread-correspondent-face
                    'gnus-modern-summary-correspondent-face)
                (get-text-property
                 position 'gnus-modern-correspondent-face)))
             (end
              (next-single-property-change
               position 'gnus-modern-correspondent-face
               nil (point-max)))
             (current (get-text-property position 'face))
             (faces
              (cond
               ((null current) nil)
               ((and (listp current)
                     (not (keywordp (car current))))
                current)
               (t (list current))))
             (faces
              (cl-remove-if
               (lambda (candidate)
                 (memq candidate
                       '(gnus-modern-summary-correspondent-face
                         gnus-modern-summary-unread-correspondent-face)))
               faces)))
        (put-text-property
         position end 'gnus-modern-correspondent-face face)
        (put-text-property position end 'face (cons face faces))
        (setq position end)))))

(defun gnus-modern--summary-article-buffer-p ()
  "Return non-nil when the current buffer is a Gnus Summary buffer."
  (derived-mode-p 'gnus-summary-mode))

(defun gnus-modern--summary-position-point ()
  "Position point at the start of custom Summary row contents."
  (beginning-of-line)
  (move-to-column gnus-modern--summary-prefix-width))

(provide 'gnus-modern-summary-format)
;;; gnus-modern-summary-format.el ends here
