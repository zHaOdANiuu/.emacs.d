;;; -*- lexical-binding: t -*-
(defconst nn-logo-image-path "~/.emacs.d/logo.png")
(defconst nn-home-buffer "*HOME*")
(defconst nn-home-package-load-count (length package-activated-list))
(defconst nn-home-emacs-init-time (emacs-init-time))

(defvar-keymap nn-home-keymap
  "o" #'nn-home-return-action
  "n" #'nn-home-next-line
  "p" #'nn-home-previous-line
  "q" #'nn-home-quit
  "g" #'nn-home-refresh
  "<up>" #'nn-home-previous-line
  "<down>" #'nn-home-next-line
  "<return>" #'nn-home-return-action)

(defun nn-home-make-padding (len)
  (make-string (- len (default-font-width)) ?\s))

(defun nn-home-insert-logo ()
  (let ((padding (floor (* (window-width) 0.5))))
    (insert (nn-home-make-padding padding))
    (insert-image (create-image nn-logo-image-path))))

(defun nn-home-insert-info ()
  (let* ((text (format "%d packages loaded in %s" nn-home-package-load-count nn-home-emacs-init-time))
         (padding (- (floor (window-width) 2)
                     (floor (- (length text) (floor (* (length text) 0.2))) 2))))
    (insert (make-string (max padding 0) ?\s))
    (insert (propertize text 'face '(:inherit font-lock-type-face :height 0.8)))))

(defun nn-home-insert-group (group-name items &optional item-formatter)
  (let* ((formatter (or item-formatter (lambda (x) (format " %s" x))))
         (padding (floor (* (window-width) 0.5)))
         (indent (nn-home-make-padding padding)))
    (let ((title-pos (point)))
      (insert indent group-name "\n")
      (put-text-property title-pos (point) 'nn-group-header t)
      (put-text-property title-pos (point) 'nn-group-name group-name)
      (put-text-property title-pos (point) 'nn-group-open t)
      (put-text-property title-pos (point) 'face '(:inherit font-lock-keyword-face)))
    (dolist (item items)
      (let ((item-pos (point))
            (line (funcall formatter item)))
        (insert indent
                (if (> (length line) 64) (concat (substring line 0 63) nn-fold-string) line)
                "\n")
        (put-text-property item-pos (point) 'nn-group-member group-name)
        (put-text-property item-pos (point) 'nn-item-data item)))))

(defun nn-home-return-action ()
  (interactive)
  (let* ((header-p (get-text-property (point) 'nn-group-header))
         (item-data (get-text-property (point) 'nn-item-data)))
    (cond (header-p (nn-home-toggle-group))
          (item-data (find-file item-data)))))

(defun nn-home-toggle-group ()
  (interactive)
  (let ((group-name (get-text-property (point) 'nn-group-name)))
    (if (get-text-property (point) 'nn-group-open)
        (nn-home-collapse-group group-name)
      (nn-home-expand-group group-name))))

(defun nn-home-group-range (group-name)
  (save-excursion
    (let ((start (progn (forward-line 1) (point)))
          (end (point)))
      (while (and (not (eobp))
                  (equal
                   (get-text-property (point) 'nn-group-member) group-name))
        (forward-line 1))
      (setq end (point))
      (cons start end))))

(defun nn-home-collapse-group (group-name)
  (interactive)
  (let* ((inhibit-read-only t)
         (range (nn-home-group-range group-name))
         (start (car range))
         (end (cdr range))
         (overlay (make-overlay start end)))
    (overlay-put overlay 'invisible t)
    (overlay-put overlay 'nn-group-overlay t)
    (overlay-put overlay 'nn-group-name group-name)
    (put-text-property (line-beginning-position) (line-end-position) 'nn-group-open nil)))

(defun nn-home-expand-group (group-name)
  (interactive)
  (let* ((inhibit-read-only t)
         (range (nn-home-group-range group-name))
         (start (car range))
         (end (cdr range)))
    (mapc #'delete-overlay (overlays-in start end))
    (put-text-property (line-beginning-position) (line-end-position) 'nn-group-open t)))

(defun nn-home-next-line ()
  (interactive)
  (forward-line 1)
  (skip-chars-forward " \t\n"))

(defun nn-home-previous-line ()
  (interactive)
  (let ((prev-pos (point)))
    (forward-line -1)
    (if (looking-at-p "^\\s-*$")
        (forward-line -1))
    (skip-chars-forward " \t\n")
    (if (= (point) prev-pos)
        (goto-char (point-min)))))

(defun nn-home-quit ()
  (interactive)
  (save-buffers-kill-terminal))

(defun nn-home-create ()
  (let ((buf (get-buffer-create nn-home-buffer)))
    (with-current-buffer buf
      (buffer-disable-undo)
      (use-local-map nn-home-keymap)
      (read-only-mode 1)
      (display-line-numbers-mode -1)
      (setq-local header-line-format nil
                  mode-line-format nil
                  mouse-1-click-follows-link nil
                  mouse-highlight nil
                  vertical-scroll-bar nil)
      (add-hook 'kill-buffer-query-functions (lambda () nil) nil t))
    buf))

(defun nn-home-render ()
  (with-current-buffer nn-home-buffer
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "\n")
      (nn-home-insert-logo)
      (insert "\n")
      (nn-home-insert-info)
      (insert "\n\n")
      (nn-home-insert-group
       "Config"
       '("~/.emacs.d/"
         "~/.emacs.d/lisp/"))
      (insert "\n")
      (nn-home-insert-group
       "Recent Files"
       (seq-take recentf-list recentf-max-saved-items)))))

(defun nn-home-show ()
  (interactive)
  (when (get-buffer nn-home-buffer)
    (switch-to-buffer nn-home-buffer)))

(defun nn-home-refresh ()
  (interactive)
  (when (eq (current-buffer) (get-buffer nn-home-buffer))
    (nn-home-render)
    (goto-char (point-min))
    (nn-home-next-line)
    (nn-home-next-line)))

(nn-home-create)
(nn-home-render)
(nn-home-show)
(goto-char (point-min))
(nn-home-next-line)
(nn-home-next-line)

(keymap-global-set "C-<f1>" #'nn-home-show)

(provide 'init-home)
