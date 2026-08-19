;;; -*- lexical-binding: t -*-
(setq cursor-type 'box
      sentence-end-double-space nil
      adaptive-fill-regexp "[ t]+|[ t]*([0-9]+.|*+)[ t]*"
      adaptive-fill-first-line-regexp "^* *$"
      bidi-inhibit-bpa t
      bidi-display-reordering 'left-to-right
      bidi-paragraph-direction 'left-to-right
      long-line-threshold 1000
      large-hscroll-threshold 1000
      truncate-partial-width-windows nil)

(setq-default word-wrap t
              tab-width 2
              tab-always-indent 'complete
              fill-column 80
              line-spacing 0)

(use-package ffap
  :ensure nil
  :custom
  (ffap-machine-p-known 'accept)
  (ffap-machine-p-unknown 'accept))

(use-package paragraphs
  :ensure nil
  :custom
  (sentence-end-double-space nil)
  (sentence-end "\\([   ]\\|  \\|[.?!][]\"')}]*\\($\\|[ \t]\\)\\)[ \t\n]*"))

(use-package elec-pair
  :ensure nil
  :hook (after-init . electric-pair-mode)
  :custom
  (electric-pair-open-newline-between-pairs t)
  (electric-pair-inhibit-predicate 'electric-pair-conservative-inhibit))

(use-package subword
  :ensure nil
  :hook
  ((java-mode
    js-mode typescript-ts-mode tsx-ts-mode
    csharp-mode c++-mode simpc-mode
    go-mode)
   . subword-mode)
  ((c-mode python-mode rust-mode) . superword-mode))

(use-package delsel
  :ensure nil
  :init (delete-selection-mode 1))

(use-package kinsoku
  :ensure nil
  :custom (word-wrap-by-category t))

(use-package so-long
  :ensure nil
  :init (global-so-long-mode 1)
  :custom (so-long-threshold 5000)
  :config
  (add-to-list 'so-long-target-modes 'conf-mode)
  (add-to-list 'so-long-target-modes 'text-mode)
  (add-to-list 'so-long-variable-overrides '(font-lock-maximum-decoration . 1))
  (add-to-list 'so-long-variable-overrides '(save-place-alist . nil))
  (cl-callf2 delq 'font-lock-mode so-long-minor-modes)
  (cl-callf2 delq 'display-line-numbers-mode so-long-minor-modes)
  (setf (alist-get 'buffer-read-only so-long-variable-overrides nil t) nil)
  (setq so-long-function #'turn-on-so-long-minor-mode
        so-long-revert-function #'turn-off-so-long-minor-mode))

(use-package hideshow-savefold
  :ensure nil
  :hook (prog-mode . hideshow-savefold-mode)
  :custom (hideshow-savefold-directory (expand-file-name "hideshow-savefold" nn-directory)))

(use-package hideshow
  :ensure nil
  :bind
  (:map hs-minor-mode-map
   ("S-<return>" . hs-toggle-hiding)
   ("C-c [" . hs-show-all)
   ("C-c ]" . my-hs-hide-level))
  :hook (prog-mode . hs-minor-mode)
  :custom
  (hs-allow-nesting t)
  (hs-hide-comments-when-hiding-all nil)
  :custom-face (hs-ellipsis ((t :inherit shadow)))
  :config
  (defun my-hs-hide-level ()
    (interactive)
    (hs-hide-level 0))

  (dolist (hook '(simpc-mode-hook
                  c-mode-hook c++-mode-hook
                  js-mode-hook typescript-ts-mode-hook tsx-ts-mode-hook))
    (add-hook hook
              (lambda ()
                (setq-local hs-adjust-block-end-function
                            (lambda (p) (1- (line-beginning-position)))))))

  (when (>= emacs-major-version 31)
    (dolist (hook '(js-json-mode-hook
                    json-ts-mode-hook
                    python-mode-hook python-ts-mode-hook
                    yaml-ts-mode-hook))
      (add-hook hook #'hs-indentation-mode)))

  (defun my-hs-set-up-overlay (ov)
    (when (eq 'code (overlay-get ov 'hs))
      (overlay-put ov 'face 'hs-ellipsis)
      (overlay-put ov 'display nn-fold-string)))

  (setq hs-set-up-overlay #'my-hs-set-up-overlay)

  (setq hs-special-modes-alist
        '((c++-ts-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (c-ts-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (c++-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (c-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (simpc-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (js-ts-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (js-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (typescript-ts-mode "\\s(" "\\s)" "/[*/]" nil nil)
          (nxml-mode "<!--\\|<[^/>]*[^/]>"
                     "-->\\|</[^/>]*[^/]>"
                     "<!--" sgml-skip-tag-forward nil)
          (t))))

(use-package outline
  :ensure nil
  :bind
  (:map outline-minor-mode-map
   ("S-<return>" . outline-toggle-children)
   ("C-c [" . outline-show-all)
   ("C-c ]" . outline-hide-body))
  :hook
  (text-mode . outline-minor-mode)
  (conf-mode . outline-minor-mode)
  (outline-minor-mode . my-outline-set-buffer-local-ellipsis)
  :config
  ;; https://www.jamescherti.com/emacs-customize-ellipsis-outline-minor-mode/
  (defun my-outline-set-buffer-local-ellipsis ()
    (let* ((display-table (or buffer-display-table (make-display-table)))
           (face-offset (* (face-id 'shadow) (ash 1 22)))
           (value (vconcat (mapcar (lambda (c)
                                     (+ face-offset c))
                                   (string-trim-right nn-fold-string)))))
      (set-display-table-slot display-table 'selective-display value)
      (setq buffer-display-table display-table))))

(use-package editorconfig
  :if (>= emacs-major-version 30)
  :ensure nil
  :init (editorconfig-mode 1)
  :custom
  (editorconfig-trim-whitespaces-mode t)
  (editorconfig-get-properties-function #'editorconfig-get-properties))

(use-package apheleia
  :bind ("<f1>" . apheleia-format-buffer)
  :hook (apheleia-inhibit-functions . my-apheleia-inhibit-p)
  :custom (apheleia-log-only-errors t)
  :config
  (add-to-list 'apheleia-mode-alist '(sh-mode . shfmt))
  (add-to-list 'apheleia-mode-alist '(simpc-mode . clang-format))
  (add-to-list 'apheleia-mode-alist '(cuda-mode . clang-format))
  (add-to-list 'apheleia-mode-alist '(protobuf-mode . clang-format))

  (dolist (formatter '(prettier prettier-css prettier-html prettier-javascript
                                prettier-json prettier-scss prettier-svelte
                                prettier-typescript prettier-yaml))
    (setf (alist-get formatter apheleia-formatters)
          '("prettier" "--stdin-filepath"
            (or (apheleia-formatters-local-buffer-file-name)
                (apheleia-formatters-mode-extension)
                ".js")))))

(use-package symbol-overlay
  :bind
  ("M-n" . symbol-overlay-jump-next)
  ("M-p" . symbol-overlay-jump-prev)
  ("M-r" . symbol-overlay-rename)
  :bind-keymap ("M-s s" . symbol-overlay-map)
  :hook (prog-mode yaml-mode yaml-ts-mode)
  :custom (symbol-overlay-idle-time 0.3))

(use-package multiple-cursors
  :bind
  (("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   ("C-M->" . mc/skip-to-next-like-this)
   ("C-M-<" . mc/skip-to-previous-like-this)
   ("C-<mouse-1>" . mc/add-cursor-on-click)
   :map mc/keymap
   ("C-w" . my-mc/cat)
   ("M-w" . my-mc/copy)
   ("C-;" . mc/vertical-align-with-space)
   ("<escape>" . multiple-cursors-mode))
  :init (multiple-cursors-mode t)
  :custom
  (mc/always-run-for-all t)
  (mc/list-file (expand-file-name ".mc-lists.el" nn-directory))
  :config
  (add-to-list 'mc--default-cmds-to-run-once #'swiper-mc)

  (defun my-mc/get-line-with-indent (beg end)
    (save-excursion
      (goto-char beg)
      (concat (buffer-substring-no-properties (line-beginning-position) beg)
              (buffer-substring-no-properties beg end))))

  (defun my-mc/lines-get ()
    (let ((pairs
           `(,`(,(region-beginning) ,(region-end)
                ,(buffer-substring-no-properties
                  (region-beginning) (region-end))))))
      (mc/for-each-fake-cursor
       cursor
       (let* ((pt (marker-position (overlay-get cursor 'point)))
              (mk (marker-position (overlay-get cursor 'mark)))
              (beg (min pt mk))
              (end (max pt mk)))
         (push `(,beg ,end ,(my-mc/get-line-with-indent beg end))
               pairs)))
      (sort pairs (lambda (a b) (< (nth 0 a) (nth 0 b))))))

  (defun my-mc/copy ()
    (interactive)
    (kill-new (string-join (mapcar (lambda (r) (nth 2 r)) (my-mc/lines-get)) "\n"))
    (mc/keyboard-quit)
    (multiple-cursors-mode -1))

  (defun my-mc/cat ()
    (interactive)
    (let ((pairs (my-mc/lines-get)))
      (kill-new (string-join (mapcar (lambda (r) (nth 2 r)) pairs) "\n"))
      (dolist (r (reverse pairs))
        (delete-region (nth 0 r) (nth 1 r)))
      (mc/keyboard-quit)
      (multiple-cursors-mode -1))))

(provide 'init-editor)
