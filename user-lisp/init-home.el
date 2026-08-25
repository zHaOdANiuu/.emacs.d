;;; -*- lexical-binding: t -*-
(require 'recentf)
(require 'bookmark)
(recentf-mode 1)

(defconst nn-home-buffer-name "*HOME*")
(defconst nn-home-logo (create-image (concat user-lisp-directory "logo.png")))
(defconst nn-home-emacs-init-string
  (propertize
   (format "%d packages loaded in %s"
           (length package-activated-list)
           (emacs-init-time))
   'face '(:inherit font-lock-type-face :height 0.8)))

(defvar-keymap nn-home-keymap
  "q" #'kill-emacs
  "n" #'nn-home-next-line
  "p" #'nn-home-previous-line
  "g" #'nn-home-refresh
  "<up>" #'nn-home-previous-line
  "<down>" #'nn-home-next-line
  "<return>" #'nn-home-return-action)

(defun nn-home-group-range (group-name)
  (save-excursion
    (forward-line 1)
    (let ((start (point)))
      (while (and (not (eobp))
                  (equal (get-text-property (point) 'nn-group-member)
                         group-name))
        (forward-line 1))
      (cons start (point)))))

(defun nn-home-expand-group (group-name)
  (let ((inhibit-read-only t)
        (range (nn-home-group-range group-name)))
    (mapc #'delete-overlay (overlays-in (car range) (cdr range)))
    (put-text-property (line-beginning-position) (line-end-position) 'nn-group-open t)))

(defun nn-home-collapse-group (group-name)
  (let* ((inhibit-read-only t)
         (range (nn-home-group-range group-name))
         (overlay (make-overlay (car range) (cdr range))))
    (overlay-put overlay 'invisible t)
    (overlay-put overlay 'nn-group-overlay t)
    (overlay-put overlay 'nn-group-name group-name)
    (put-text-property (line-beginning-position) (line-end-position) 'nn-group-open nil)))

(defun nn-home-toggle-group ()
  (let ((group-name (get-text-property (point) 'nn-group-name)))
    (if (get-text-property (point) 'nn-group-open)
        (nn-home-collapse-group group-name)
      (nn-home-expand-group group-name))))

(defun nn-home-return-action ()
  (interactive)
  (let ((item (get-text-property (point) 'nn-item-data)))
    (cond
     ((get-text-property (point) 'nn-group-header)
      (nn-home-toggle-group))
     (item
      (funcall (get-text-property (point) 'nn-item-action) item)))))

(defun nn-home--entry-p ()
  (and (not (invisible-p (point)))
       (or (get-text-property (point) 'nn-group-header)
           (get-text-property (point) 'nn-item-data))))

(defun nn-home--move-to-entry (direction)
  (let ((origin (point)))
    (when (or (> direction 0)
              (> (line-beginning-position) (point-min)))
      (forward-line direction)
      (while (and (not (nn-home--entry-p))
                  (if (> direction 0)
                      (not (eobp))
                    (> (point) (point-min))))
        (forward-line direction))
      (if (nn-home--entry-p)
          (skip-chars-forward " \t" (line-end-position))
        (goto-char origin)))))

(defun nn-home-next-line ()
  (interactive)
  (nn-home--move-to-entry 1))

(defun nn-home-previous-line ()
  (interactive)
  (nn-home--move-to-entry -1))

(defun nn-home-insert-group (group-name items &optional item-action)
  (let ((action (or item-action #'find-file)))
    (let ((start (point)))
      (insert group-name "\n")
      (add-text-properties
       start (point)
       `(nn-group-header t nn-group-name ,group-name
         nn-group-open t
         face (:inherit font-lock-keyword-face))))
    (dolist (item items)
      (let ((start (point))
            (line (truncate-string-to-width
                   (format " %s" item) 64 nil nil nn-fold-string)))
        (insert line "\n")
        (add-text-properties
         start (point)
         `(nn-group-member ,group-name nn-item-data ,item
           nn-item-action ,action))))))

(defun nn-home-set-margins ()
  (let* ((win (get-buffer-window nn-home-buffer-name))
         (w (window-total-width win)))
    (with-current-buffer nn-home-buffer-name
      (setq-local left-margin-width (floor (- w (* w 0.25)) 2)))
    (set-window-buffer win (get-buffer nn-home-buffer-name))))

(defun nn-home-create ()
  (with-current-buffer (get-buffer-create nn-home-buffer-name)
    (setq-local header-line-format nil
                mode-line-format nil
                display-line-numbers-mode nil)
    (use-local-map nn-home-keymap)
    (read-only-mode)
    (add-hook 'kill-buffer-query-functions #'ignore nil t)
    (add-hook 'window-size-change-functions
              (lambda (&rest _)
                (when (get-buffer-window nn-home-buffer-name)
                  (nn-home-set-margins))))))

(defun nn-home-render ()
  (with-current-buffer nn-home-buffer-name
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "\n")
      (insert-image nn-home-logo)
      (insert "\n")
      (insert nn-home-emacs-init-string)
      (insert "\n\n")
      (nn-home-insert-group
       "Config"
       `(,user-emacs-directory ,user-lisp-directory))
      (insert "\n")
      (nn-home-insert-group
       "Recent Files"
       (seq-take recentf-list recentf-max-saved-items))
      (insert "\n")
      (nn-home-insert-group
       "Bookmarks"
       (bookmark-all-names)
       #'bookmark-jump))))

(defun nn-home-show ()
  (interactive)
  (when (get-buffer nn-home-buffer-name)
    (switch-to-buffer nn-home-buffer-name)))

(defun nn-home-refresh ()
  (interactive)
  (when (eq (current-buffer) (get-buffer nn-home-buffer-name))
    (nn-home-render)))

(nn-home-create)
(nn-home-set-margins)
(nn-home-render)
(nn-home-show)
(goto-char (point-min))
(nn-home-next-line)

(keymap-global-set "C-<f1>" #'nn-home-show)

(provide 'init-home)
