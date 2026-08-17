;;; -*- lexical-binding: t -*-
(defun my-ido-recentf-open ()
  (interactive)
  (let ((file (completing-read "Find recent file: " recentf-list nil t)))
    (if (and file (file-exists-p file))
        (find-file file)
      (message "File open failed"))))

(use-package dabbrev
  :ensure nil
  :custom
  (dabbrev-case-replace nil)
  (dabbrev-downcase-means-case-replace nil)
  (dabbrev-case-distinction nil))

(use-package ido
  :ensure nil
  :if (< emacs-major-version 27)
  :bind
  (("C-x C-r" . my-ido-recentf-open)
   (:map ido-common-completion-map
    ("C-w" . ido-delete-backward-word-updir)
    ("C-n" . ido-next-match)
    ("C-p" . ido-prev-match)
    ("<down>" . ido-next-match)
    ("<up>" . ido-prev-match))
   (:map ido-file-completion-map
    ("C-w" . ido-delete-backward-word-updir))
   (:map ido-file-dir-completion-map
    ("C-n" . ido-next-match)
    ("C-p" . ido-prev-match)
    ("<down>" . ido-next-match)
    ("<up>" . ido-prev-match)))
  :init (ido-mode 1)
  :custom
  (ido-save-directory-list-file (expand-file-name "ido-save-directory-list.el" nn-directory))
  (ido-everywhere t)
  (ido-max-prospects 5)
  (ido-enable-flex-matching t)
  (ido-auto-merge-work-directories-length -1)
  (ido-confirm-unique-completion t)
  (ido-case-fold t)
  (ido-create-new-buffer 'always)
  (ido-ignore-files '("\\`.DS_Store$" "Icon\\?$"))
  (ido-ignore-buffers
   '("\\` " "^\\*ESS\\*" "^\\*Messages\\*" "^\\*[Hh]elp" "^\\*Buffer"
     "^\\*.*Completions\\*$" "^\\*Ediff" "^\\*tramp" "^\\*cvs-" "_region_"
     " output\\*$" "^TAGS$" "^\*Ido")))

(use-package icomplete
  :ensure nil
  :if (>= emacs-major-version 27)
  :bind ("C-x C-r" . my-ido-recentf-open)
  :init
  (fido-mode 1)
  (fido-vertical-mode 1)
  ;; (icomplete-mode 1)
  ;; (icomplete-vertical-mode 1)
  :custom
  (icomplete-max-delay-chars 3)
  (icomplete-show-matches-on-no-input nil)
  (icomplete-hide-common-prefix nil)
  (icomplete-tidy-shadowed-file-names t))

(use-package completion-preview
  :ensure nil
  :if (and (>= emacs-major-version 30)
           (eq nn-completion-style 'completion-preview))
  :bind
  (:map completion-preview-active-mode-map
   ("C-n" . completion-preview-next-candidate)
   ("C-p" . completion-preview-prev-candidate)
   ("C-l" . (lambda () (interactive)
              (completion-preview-hide)
              (completion-preview-next-candidate))))
  :custom
  (completion-preview-ignore-case t)
  (completion-preview-minimum-symbol-length nil)
  (completion-preview-completion-styles '(basic partial-completion initials orderless)))

(use-package yasnippet
  :init (yas-global-mode 1)
  :custom (yas-snippet-dirs nil))

(use-package yasnippet-snippets
  :hook (simpc-mode . (lambda () (yas-activate-extra-mode 'c++-mode))))

(use-package yasnippet-capf
  :commands yasnippet-capf
  :functions cape-capf-super eglot-completion-at-point
  :init (add-to-list 'completion-at-point-functions #'yasnippet-capf))

(use-package eglot
  :ensure nil
  :bind
  ("<f2>" . eglot-rename)
  ("<f12>" . xref-find-definitions)
  ("S-<f12>" . xref-find-references)
  ("C-<f12>" . eglot-find-implementation)
  ("C-S-<f12>" . eglot-find-typeDefinition)
  ("C-." . eglot-code-action-quickfix)
  :custom
  (eglot-autoshutdown t)
  (eglot-code-action-indications '(left-fringe))
  (eglot-events-buffer-config '(:size 0 :format 'short))
  (eglot-documentation-renderer 'markdown-ts-view-mode)
  (eglot-ignored-server-capabilities
   '(:inlayHintProvider
     :documentHighlightProvider
     :foldingRangeProvider))
  :config
  (define-fringe-bitmap 'eglot--fringe-action
    [#b0000000000000000
     #b0000001111000000
     #b0000111111110000
     #b0001111111111000
     #b0001100000011000
     #b0001100100011000
     #b0001100110011000
     #b0001100000011000
     #b0001111111111000
     #b0000111111110000
     #b0000111111100000
     #b0000001111000000
     #b0000001111000000
     #b0000001111000000
     #b0000001111000000
     #b0000000000000000]
    16 16 'center)

  ;; ignore jsonrpc log
  (fset #'jsonrpc--log-event #'ignore)

  ;; ignore eglot annotation face
  (when (< emacs-major-version 31)
    (define-advice eglot-completion-at-point (:filter-return (cap) no-face)
      (when-let* ((props (nthcdr 3 cap))
                  (fn (plist-get props :annotation-function)))
        (setf (plist-get props :annotation-function)
              (lambda (proxy) (substring-no-properties (funcall fn proxy)))))
      cap)))

(use-package corfu
  :if (eq nn-completion-style 'corfu)
  :commands (corfu-quit)
  :bind
  (:map corfu-map
   ([tab] . corfu-complete)
   ("<return>" . corfu-complete)
   ([backtab] . corfu-previous)
   ("<escape>" . corfu-quit)
   ("S-SPC" . corfu-insert-separator))
  :custom
  (global-corfu-mode 1)
  (global-corfu-modes '((not erc-mode help-mode gud-mode) t))
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-auto-prefix 2)
  (corfu-cycle nil)
  (corfu-preselect 'first)
  (corfu-on-exact-match nil)
  (corfu-quit-at-boundary nil)
  (corfu-quit-no-match t)
  (corfu-preview-current nil)
  (corfu-count 12)
  (corfu-max-width 120)
  (corfu-left-margin-width 0)
  (corfu-right-margin-width 0)
  (corfu-auto-commands
   '("self-insert-command\\'"
     c-electric-colon c-electric-lt-gt
     c-electric-slash c-scope-operator)))

(use-package corfu-popupinfo
  :ensure nil
  :hook (corfu-mode . corfu-popupinfo-mode)
  :bind (:map corfu-map ("M-p" . corfu-popupinfo-toggle))
  :custom (corfu-popupinfo-delay '(nil . nil)))

(provide 'init-completion)
