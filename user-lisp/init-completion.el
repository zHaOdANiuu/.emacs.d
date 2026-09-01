;;; -*- lexical-binding: t -*-
(use-package dabbrev
  :ensure nil
  :custom
  (dabbrev-case-replace nil)
  (dabbrev-downcase-means-case-replace nil)
  (dabbrev-case-distinction nil))

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
  (fset #'jsonrpc--log-event #'ignore))

(use-package icomplete
  :ensure nil
  :bind ("C-x C-r" . my-recentf-open)
  :init
  (fido-mode 1)
  (fido-vertical-mode 1)
  :custom
  (icomplete-max-delay-chars 2)
  (icomplete-hide-common-prefix nil)
  (icomplete-tidy-shadowed-file-names t)
  (icomplete-show-matches-on-no-input nil)
  :config
  (defun my-recentf-open ()
    (interactive)
    (let ((file (completing-read "Find recent file: " recentf-list nil t)))
      (if (and file (file-exists-p file))
          (find-file file)
        (message "File open failed")))))

(use-package completion-preview
  :ensure nil
  :if (eq nn-completion-style 'completion-preview)
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

(use-package corfu
  :if (eq nn-completion-style 'corfu)
  :bind
  (:map corfu-map
   ([tab] . corfu-complete)
   ("<return>" . corfu-complete)
   ([backtab] . corfu-previous)
   ("<escape>" . corfu-quit)
   ("S-SPC" . corfu-insert-separator))
  :hook (nn-first-input . global-corfu-mode)
  :custom
  (cor)
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-auto-commands
   '("self-insert-command\\'"
     c-electric-colon c-electric-lt-gt
     c-electric-slash c-scope-operator
     lispy-colon))
  (corfu-preselect 'first)
  (corfu-quit-at-boundary nil)
  (corfu-quit-no-match t)
  (corfu-preview-current nil)
  (corfu-count 12)
  (corfu-max-width 120)
  (corfu-left-margin-width 0)
  (corfu-right-margin-width 0)
  (global-corfu-minibuffer nil)
  (global-corfu-modes '((not erc-mode help-mode gud-mode) t))
  :config
  ;; HACK: If you want to update the visual hints after completing minibuffer
  ;;   commands with Corfu and exiting, you have to do it manually.
  (define-advice exit-minibuffer
      (:before () my-corfu--insert-before-exit-minibuffer-a)
    (when (or (and (frame-live-p corfu--frame)
                   (frame-visible-p corfu--frame))
              (and (featurep 'corfu-terminal)
                   (popon-live-p corfu-terminal--popon)))
      (when (member isearch-lazy-highlight-timer timer-idle-list)
        (apply (timer--function isearch-lazy-highlight-timer)
               (timer--args isearch-lazy-highlight-timer)))
      (when (member (bound-and-true-p anzu--update-timer) timer-idle-list)
        (apply (timer--function anzu--update-timer)
               (timer--args anzu--update-timer)))
      (when (member (bound-and-true-p evil--ex-search-update-timer)
                    timer-idle-list)
        (apply (timer--function evil--ex-search-update-timer)
               (timer--args evil--ex-search-update-timer)))))

  ;; HACK: If your dictionaries aren't set up in text-mode buffers, ispell will
  ;;   continuously pester you about errors. This ensures it only happens once
  ;;   per session.
  (define-advice ispell-completion-at-point
      (:around (fn &rest args) my-corfu--auto-disable-ispell-capf-a )
    "If ispell isn't properly set up, only complain once per session."
    (condition-case-unless-debug e
        (apply fn args)
      ('error
       (message "Error: %s" (error-message-string e))
       (message "Auto-disabling `text-mode-ispell-word-completion'")
       (setq text-mode-ispell-word-completion nil)
       (remove-hook 'completion-at-point-functions #'ispell-completion-at-point t)))))

(use-package corfu-popupinfo
  :ensure nil
  :bind
  (:map corfu-map
   ("M-p" . my-corfu-popupinfo-toggle)
   ("M-1" . corfu-popupinfo-scroll-up)
   ("M-2" . corfu-popupinfo-scroll-down))
  :custom (corfu-popupinfo-delay '(0 . 0.2))
  :config
  (defun my-corfu-popupinfo-toggle ()
    (interactive)
    (corfu-popupinfo-mode (not corfu-popupinfo-mode)))

  (define-advice corfu-quit (:after (&rest _) my-corfu-popupinfo-quit)
    (when corfu-popupinfo-mode
      (corfu-popupinfo-mode -1))))

(use-package yasnippet
  :commands
  (yas-minor-mode-on
   yas-expand
   yas-expand-snippet
   yas-lookup-snippet
   yas-insert-snippet
   yas-new-snippet
   yas-visit-snippet-file
   yas-activate-extra-mode
   yas-deactivate-extra-mode
   yas-maybe-expand-abbrev-key-filter)
  :hook (nn-first-input . yas-global-mode))

(provide 'init-completion)
