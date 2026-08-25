;;; -*- lexical-binding: t -*-
(setq eol-mnemonic-unix "LF"
      eol-mnemonic-dos "CRLF"
      eol-mnemonic-mac "CR"
      eol-mnemonic-undecided "?")

(setq-default mode-line-format nil)

(defvar nn-mode-line--prog-modes-cache nil)
(defvar-local nn-mode-line--vc-cache nil)
(defvar-local nn-mode-line--eglot-cache nil)
(defvar-local nn-mode-line--flymake-cache nil)
(defvar-local nn-mode-line--flymake-counts '(0 0 0))

(defconst nn-mode-line-error   (nerd-icons-codicon   "nf-cod-error"))
(defconst nn-mode-line-warning (nerd-icons-codicon   "nf-cod-warning"))
(defconst nn-mode-line-info    (nerd-icons-codicon   "nf-cod-info"))
(defconst nn-mode-line-git     (nerd-icons-powerline "nf-pl-branch"))

(defun nn-mode-line--prop (text help cmd)
  (propertize
   text
   'mouse-face 'highlight
   'help-echo help
   'local-map (let ((map (make-sparse-keymap)))
                (keymap-set map "<mode-line> <mouse-1>" cmd)
                map)))

(defun nn-mode-line-vc-format ()
  (or nn-mode-line--vc-cache
      (setq nn-mode-line--vc-cache
            (concat
             nn-mode-line-git
             (if-let* ((root (vc-root-dir))
                       (backend (vc-responsible-backend root)))
                 (let ((b (string-trim-left
                           (substring-no-properties
                            (vc-call-backend backend 'mode-line-string root))
                           "[A-Za-z]+[-:] ?")))
                   (if (string-empty-p b) "?" b))
               "!")))))

(defun nn-mode-line-flymake-format ()
  (or nn-mode-line--flymake-cache
      (setq nn-mode-line--flymake-cache
            (nn-mode-line--prop
             (format "%s %d %s %d %s %d"
                     nn-mode-line-error (nth 0 nn-mode-line--flymake-counts)
                     nn-mode-line-warning (nth 1 nn-mode-line--flymake-counts)
                     nn-mode-line-info (nth 2 nn-mode-line--flymake-counts))
             "mouse-1: diagnostics" #'flymake-show-buffer-diagnostics))))

(defun nn-mode-line-eglot-format ()
  (or nn-mode-line--eglot-cache
      (when (bound-and-true-p eglot--managed-mode)
        (setq nn-mode-line--eglot-cache
              (nn-mode-line--prop
               (pcase (alist-get major-mode eglot-server-programs)
                 ((and (pred stringp) name) name)
                 (`(,name . ,_) name)
                 (_ "lsp"))
               "mouse-1: LSP log"
               (lambda () (interactive)
                 (if-let* ((s (eglot-current-server))
                           (buf (eglot--stderr-buffer s)))
                     (switch-to-buffer-other-window buf)
                   (message "No LSP server"))))))))

(defun nn-mode-line-position-format ()
  (when display-line-numbers-mode
    (nn-mode-line--prop
     (format "L%s C%s"
             (format-mode-line "%l")
             (format-mode-line "%c"))
     "mouse-1: goto line:col"
     (lambda () (interactive)
       (let ((input (read-string "Goto line:col (e.g. 42:10): ")))
         (when (string-match "^\\([0-9]+\\)\\(?::\\([0-9]+\\)\\)?$" input)
           (goto-line (string-to-number (match-string 1 input)))
           (when (match-string 2 input)
             (move-to-column (string-to-number (match-string 2 input))))))))))

(defun nn-mode-line-encoding-format ()
  (nn-mode-line--prop
   (symbol-name buffer-file-coding-system)
   "mouse-1: encoding"
   (lambda () (interactive)
     (let* ((coding (read-coding-system "Coding system: "))
            (action (completing-read "Action: " '("Save" "Reopen") nil t)))
       (if (string= action "Save")
           (progn (set-buffer-file-coding-system coding)
                  (message "Save as %s" coding))
         (revert-buffer-with-coding-system coding)
         (save-buffer))))))

(defun nn-mode-line--prog-modes ()
  (or nn-mode-line--prog-modes-cache
      (setq nn-mode-line--prog-modes-cache
            (let ((modes '()))
              (dolist (entry auto-mode-alist)
                (let ((mode (cdr entry)))
                  (when (and (symbolp mode)
                             (not (memq mode modes))
                             (not (memq mode '(fundamental-mode special-mode))))
                    (push mode modes))))
              (sort (mapcar (lambda (m) (string-trim-right (symbol-name m) "-mode$")) modes)
                    #'string<)))))

(defun nn-mode-line-mode-format ()
  (nn-mode-line--prop
   (string-trim-right (symbol-name major-mode) "-mode$")
   "mouse-1: switch major mode"
   (lambda () (interactive)
     (let* ((name (completing-read "Language: " (nn-mode-line--prog-modes) nil t))
            (mode (intern (concat name "-mode"))))
       (when (commandp mode)
         (funcall mode))))))

(defun nn-viper-mode-format ()
  (when (bound-and-true-p viper-mode)
    (if mark-active "VISUAL"
      (pcase viper-current-state
        ('vi-state      "NORMAL")
        ('insert-state  "INSERT")
        ('replace-state "REPLACE")
        ('emacs-state   "EMACS")))))

(define-advice vc-refresh-state (:after (&rest _) reset-nn-vc-cache)
  (setq nn-mode-line--vc-cache nil))

(define-advice flymake--handle-report (:after (&rest _) reset-nn-flymake-cache)
  (setq nn-mode-line--flymake-cache nil
        nn-mode-line--flymake-counts
        (list (string-to-number (format-mode-line flymake-mode-line-error-counter))
              (string-to-number (format-mode-line flymake-mode-line-warning-counter))
              (string-to-number (format-mode-line flymake-mode-line-note-counter)))))

(define-advice eglot--managed-mode (:after (&rest _) reset-nn-eglot-cache)
  (setq nn-mode-line--eglot-cache nil))

(defconst nn-mode-line-format
  '("%e"
    "  " (:eval (nn-viper-mode-format))
    "  " (:eval (nn-mode-line-vc-format))
    "  " "%b"
    "  " (:eval (nn-mode-line-flymake-format))
    "  " (:eval (nn-mode-line-eglot-format))
    "  " mode-line-misc-info
    mode-line-format-right-align
    "  " (:eval (nn-mode-line-position-format))
    "  " (:eval (nn-mode-line-encoding-format))
    "  " (:eval (if current-input-method "C" "A"))
    "  " (:eval (nn-mode-line-mode-format))
    "  "))

(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook dired-mode-hook))
  (add-hook hook
            (lambda ()
              (setq nn-mode-line--vc-cache nil
                    nn-mode-line--eglot-cache nil
                    nn-mode-line--flymake-cache nil)
              (setq-local mode-line-format nn-mode-line-format))))

(provide 'init-mode-line)
