;;; -*- lexical-binding: t -*-
(unless (display-graphic-p)
  (setq-default auto-composition-mode nil))

(use-package tty-tip
  :ensure nil
  :if (featurep 'tty-child-frames)
  :hook (tty-setup . tty-tip-mode))

(use-package shell
  :ensure nil
  :bind
  ("C-:" . shell-command)
  ("C-c C-`" . shell)
  :hook
  (shell-mode . my-shell-mode-hook)
  (comint-output-filter-functions . comint-strip-ctrl-m)
  :custom (system-uses-terminfo nil)
  :config
  (defun my-shell-simple-send (proc command)
    "Various PROC COMMANDs pre-processing before sending to shell."
    (cond
     ((string-match "^[ \t]*clear[ \t]*$" command)
      (comint-send-string proc "\n")
      (erase-buffer))
     ((string-match "^[ \t]*man[ \t]*" command)
      (comint-send-string proc "\n")
      (setq command (replace-regexp-in-string "^[ \t]*man[ \t]*" "" command))
      (setq command (replace-regexp-in-string "[ \t]+$" "" command))
      (funcall 'man command))
     (t (comint-simple-send proc command))))

  (defun my-shell-mode-hook ()
    "Shell mode customization."
    (local-set-key '[up] 'comint-previous-input)
    (local-set-key '[down] 'comint-next-input)
    (local-set-key '[(shift tab)] 'comint-next-matching-input-from-input)
    (ansi-color-for-comint-mode-on)
    (setq comint-input-sender 'my-shell-simple-send)))

(use-package eshell
  :ensure nil
  :bind ("C-c `" . eshell)
  :hook (eshell-mode . (lambda () (local-set-key [remap recenter-top-bottom] 'eshell/clear)))
  :custom
  (eshell-history-size 100000)
  (eshell-hist-ignoredups t)
  :config
  (put 'eshell/ebc 'eshell-no-numeric-conversions t)

  (defalias 'eshell/e #'eshell/emacs)
  (defalias 'eshell/ec #'eshell/emacs)
  (defalias 'eshell/more #'eshell/less)

  (defun eshell/clear ()
    "Clear the eshell buffer."
    (interactive)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (eshell-send-input)))

  (defun eshell/emacs (&rest args)
    "Open a file (ARGS) in Emacs.  Some habits die hard."
    (if (null args)
        (bury-buffer)
      (mapc #'find-file (mapcar #'expand-file-name (flatten-tree (reverse args))))))

  (defun eshell/ebc (&rest args)
    "Compile a file (ARGS) in Emacs. Use `compile' to do background make."
    (if (eshell-interactive-output-p)
        (let ((compilation-process-setup-function
               (list 'lambda nil
                     (list 'setq 'process-environment
                           (list 'quote (eshell-copy-environment))))))
          (compile (eshell-flatten-and-stringify args))
          (pop-to-buffer compilation-last-buffer))
      (throw 'eshell-replace-command
             (let ((l (eshell-stringify-list (flatten-tree args))))
               (eshell-parse-command (car l) (cdr l))))))

  (defun my-eshell-view-file (file)
    "View FILE.  A version of `view-file' which properly rets the eshell prompt."
    (interactive "fView file: ")
    (unless (file-exists-p file) (error "%s does not exist" file))
    (let ((buffer (find-file-noselect file)))
      (if (eq (get (buffer-local-value 'major-mode buffer) 'mode-class)
              'special)
          (progn
            (switch-to-buffer buffer)
            (message "Not using View mode because the major mode is special"))
        (let ((undo-window (list (window-buffer) (window-start)
                                 (+ (window-point)
                                    (length (funcall eshell-prompt-function))))))
          (switch-to-buffer buffer)
          (view-mode-enter (cons (selected-window) (cons nil undo-window))
                           'kill-buffer)))))

  (defun eshell/less (&rest args)
    "Invoke `view-file' on a file (ARGS).
\"less +42 foo\" will go to line 42 in the buffer for foo."
    (while args
      (if (string-match "\\`\\+\\([0-9]+\\)\\'" (car args))
          (let* ((line (string-to-number (match-string 1 (pop args))))
                 (file (pop args)))
            (eshell-view-file file)
            (forward-line line))
        (my-eshell-view-file (pop args)))))  )

(use-package ielm
  :ensure nil
  :custom (ielm-history-file-name (concat nn-directory "ielm-history.eld"))
  :config
  ;; Adapted from http://www.modernemacs.com/post/comint-highlighting/ to add
  ;; syntax highlighting to ielm REPLs.
  (setq ielm-font-lock-keywords
        (append
         '(("\\(^\\*\\*\\*[^*]+\\*\\*\\*\\)\\(.*$\\)"
            (1 font-lock-comment-face)
            (2 font-lock-constant-face)))
         (cl-loop for (matcher . match-highlights)
                  in (append lisp-el-font-lock-keywords-2
                             lisp-cl-font-lock-keywords-2)
                  collect
                  `((lambda (limit)
                      (when ,(if (symbolp matcher)
                                 `(,matcher limit)
                               `(re-search-forward ,matcher limit t))
                        ;; Only highlight matches after the prompt
                        (> (match-beginning 0) (car comint-last-prompt))
                        ;; Make sure we're not in a comment or string
                        (let ((state (syntax-ppss)))
                          (not (or (nth 3 state)
                                   (nth 4 state))))))
                    ,@match-highlights)))))

(use-package ghostel
  :commands ghostel
  :bind
  (("C-`" . ghostel)
   :map ghostel-semi-char-mode-map
   ("C-k" . my-ghostel-send-C-k-and-kill)
   ("M-p" . (lambda () (interactive) (ghostel-send-key "p" "ctrl")))
   ("M-n" . (lambda () (interactive) (ghostel-send-key "n" "ctrl")))
   :map project-prefix-map
   ("m" . ghostel-project)
   ("M" . ghostel-project-list-buffers))
  :custom (ghostel-term "xterm-256color")
  :config
  (defun my-ghostel-send-C-k-and-kill ()
    "Send `C-k' to ghostel.
Like normal Emacs `C-k'.  Kill to end of line and put content in kill-ring."
    (interactive)
    (kill-ring-save (point) (line-end-position))
    (ghostel-send-key "k" "ctrl"))

  (add-to-list 'project-switch-commands '(ghostel-project "Ghostel") t)
  (add-to-list 'project-switch-commands '(ghostel-project-list-buffers "Ghostel buffers") t)
  (add-to-list 'ghostel-eval-cmds '("magit-status-setup-buffer" magit-status-setup-buffer))
  (add-to-list 'display-buffer-alist
               '("\\*ghostel\\*"
                 (display-buffer-below-selected)
                 (window-height . 0.35))))

(provide 'init-terminal)
