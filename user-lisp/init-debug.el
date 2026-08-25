;;; -*- lexical-binding: t -*-
(defvar my-dape-toolbar-frame nil)
(defvar my-dape-toolbar-buf nil)

(defconst my-dape-toolbar-buttons
  '(("nf-cod-debug_continue"  dape-continue "Continue"  nerd-icons-lblue)
    ("nf-cod-debug_step_over" dape-next     "Step Over" nerd-icons-lblue)
    ("nf-cod-debug_step_into" dape-step-in  "Step Into" nerd-icons-lblue)
    ("nf-cod-debug_step_out"  dape-step-out "Step Out"  nerd-icons-lblue)
    ("nf-cod-debug_restart"   dape-restart  "Restart"   nerd-icons-lgreen)
    ("nf-cod-debug_stop"      dape-quit     "Quit"      nerd-icons-red)))

(defun my-dape-toolbar-buf-create ()
  (interactive)
  (setq my-dape-toolbar-buf (get-buffer-create "*NN Dape Toolbar*"))
  (with-current-buffer my-dape-toolbar-buf
    (erase-buffer)
    (insert " ")
    (insert-text-button
     (nerd-icons-codicon "nf-cod-gripper" :face 'nerd-icons-dsilver)
     'mouse-face 'highlight
     'keymap (let ((m (make-sparse-keymap)))
               (define-key m [down-mouse-1] #'nn-drag-frame)
               m))
    (dolist (btn my-dape-toolbar-buttons)
      (let ((icon (nth 0 btn))
            (func (nth 1 btn))
            (tooltip (nth 2 btn))
            (face (nth 3 btn)))
        (insert "  ")
        (insert-text-button
         (nerd-icons-codicon icon :face face)
         'mouse-face 'highlight
         'help-echo tooltip
         'action `(lambda (_) (call-interactively ',func)))))
    (put-text-property (point-min) (point-max) 'pointer 'arrow)))

(defun my-dape-toolbar-create ()
  (interactive)
  (my-dape-toolbar-buf-create)
  (setq my-dape-toolbar-frame
        (make-frame
         `((parent-frame . ,(selected-frame))
           (undecorated . t) (z-group . above)
           (left . 0.5) (top . 0)
           (min-width . 0) (min-height . 0)
           (width . 26) (height . 1)
           (internal-border-width . 15) (border-width . 3)
           (left-fringe . 0) (right-fringe . 0)
           (background-color . ,(face-background 'tooltip))
           (cursor-type . nil) (minibuffer . nil)
           (no-focus-on-map . t) (no-other-window . t))))
  (set-window-buffer (frame-root-window my-dape-toolbar-frame) my-dape-toolbar-buf)
  (set-face-attribute 'child-frame-border my-dape-toolbar-frame :background nil :inherit nil))

(defun my-dape-toolbar-close ()
  (interactive)
  (kill-buffer my-dape-toolbar-buf)
  (delete-frame my-dape-toolbar-frame))

(defun my-dape-select-process ()
  (let* ((lines (process-lines "tasklist" "/FO" "CSV" "/NH"))
         (table (mapcar (lambda (line)
                          (let* ((fields (split-string line "," t))
                                 (name (string-trim (car fields) "\"" "\""))
                                 (pid  (string-trim (cadr fields) "\"" "\"")))
                            (cons (format "%-30s  PID: %s" name pid)
                                  (string-to-number pid))))
                        lines))
         (choice (completing-read "Selection PID: " table nil t)))
    (cdr (assoc choice table))))

(use-package dape
  :bind
  ("<f5>"    . dape)
  ("S-<f5>"  . dape-quit)
  ("<f9>"    . dape-breakpoint-toggle)
  ("<f10>"   . dape-next)
  ("<f11>"   . dape-step-in)
  ("S-<f11>" . dape-step-out)
  ("C-<f5>"  . dape-kill)
  :custom
  (dape-adapter-dir (concat nn-directory "dape/adapters/"))
  (dape-default-breakpoints-file (concat nn-directory "dape/breakpoints.eld"))
  (dape-inlay-hints nil)
  (dape-buffer-window-arrangement 'right)
  :config
  (make-directory (concat nn-directory "dape/adapters/") t)
  (when (eq system-type 'windows-nt)
    (setenv "LLDB_USE_NATIVE_PDB_READER" "1"))

  (add-hook 'dape-start-hook #'my-dape-toolbar-create)
  (add-hook 'dape-active-mode-hook (lambda () (unless dape-active-mode (my-dape-toolbar-close))))
  (remove-hook 'dape-start-hook #'dape-repl)
  (add-to-list 'dape-configs
               '(gdb-attach
                 modes (c-mode c-ts-mode c++-mode c++-ts-mode)
                 command "gdb"
                 command-args ("--interpreter=dap")
                 :request "attach"
                 :pid (my-dape-select-process))))

(provide 'init-debug)
