;;; -*- lexical-binding: t -*-
(use-package vc
  :ensure nil
  :custom
  (vc-follow-symlinks t)
  (vc-handled-backends '(Git))
  (vc-git-program (executable-find "git"))
  (vc-ignore-dir-regexp
   (format "%s\\|%s"
           locate-dominating-stop-dir-regexp
           "[/\\\\]node_modules")))

(use-package vc-dir
  :ensure nil
  :bind
  (:map vc-dir-mode-map
   ("c" . vc-next-action)
   ("f" . vc-pull)
   ("<return>" . vc-diff))
  :hook (vc-dir-refresh . my-vc-dir-hide-dirs)
  :config
  (defun my-vc-dir-hide-dirs ()
    (when (and (boundp 'vc-ewoc) vc-ewoc)
      (ewoc-filter vc-ewoc (lambda (i) (not (vc-dir-fileinfo->directory i)))))))

(use-package diff-mode
  :ensure nil
  :hook (diff-mode . outline-minor-mode)
  :custom
  (diff-refine nil)
  (diff-default-read-only t)
  (diff-advance-after-apply-hunk t)
  (diff-update-on-the-fly t)
  (diff-font-lock-syntax 'hunk-also)
  (diff-font-lock-prettify nil))

(use-package ediff
  :ensure nil
  :commands ediff-buffers ediff-files ediff-buffers3 ediff-files3
  :hook
  (ediff-quit . tab-bar-history-back)
  (ediff-prepare-buffer . outline-show-all)
  (ediff-before-setup . my-ediff-save-wconf-h)
  ((ediff-quit ediff-suspend) . my-ediff-restore-wconf-h)
  :custom
  (ediff-diff-options "-w")
  (ediff-keep-variants nil)
  (ediff-make-buffers-readonly-at-startup nil)
  (ediff-show-clashes-only t)
  (ediff-window-setup-function #'ediff-setup-windows-plain)
  (ediff-split-window-function #'split-window-horizontally)
  (ediff-merge-split-window-function #'split-window-horizontally)
  :config
  (defvar my--ediff-saved-wconf nil)
  ;; Restore window config after quitting ediff
  (defun my-ediff-save-wconf-h ()
    (setq my--ediff-saved-wconf (current-window-configuration)))

  (defun my-ediff-restore-wconf-h ()
    (when (window-configuration-p my--ediff-saved-wconf)
      (set-window-configuration my--ediff-saved-wconf))))

(use-package smerge-mode
  :ensure nil
  :hook (find-file . my-init-smerge-mode-h)
  :config
  (defun my-init-smerge-mode-h ()
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^<<<<<<< " nil t) (smerge-mode 1)))))

(use-package transient
  :ensure nil
  :custom
  (transient-history-file (concat nn-directory "transient/history.el"))
  (transient-levels-file (concat nn-directory "transient/levels.el"))
  (transient-values-file (concat nn-directory "transient/values.el")))

;; (use-package majutsu
;;   :vc (:url "https://github.com/0WD0/majutsu" :rev :newest))

(use-package magit
  :bind
  (("C-c g l" . magit-log-buffer-file)
   :map magit-status-mode-map
   ("<return>" . my-magit-fast-diff))
  :hook
  (git-commit-setup . (lambda () (setq fill-column git-commit-summary-max-length)))
  ;; HACK: See magit/magit#5320: large/long status buffers can change the
  ;;   behavior of motions and TAB in obscure ways.
  ;; REVIEW: REmove when magit/magit#5320 is addressed.
  (magit-status-mode . (lambda () (setq-local long-line-threshold nil)))
  (magit-diff-visit-file . my-magit-reveal-point-if-invisible-h)
  :custom
  (git-commit-major-mode 'git-commit-elisp-text-mode)
  (magit-commit-show-diff nil)
  (magit-commit-ask-to-stage nil)
  (magit-log-section-commit-count 5)
  (magit-process-connection-type nil)
  (magit-refresh-verbose nil)
  (magit-refresh-status-buffer nil)
  (magit-revision-insert-related-refs nil)
  (magit-save-repository-buffers nil)
  (magit-uniquify-buffer-names nil)
  (magit-no-confirm '(stage-all-changes unstage-all-changes))
  (magit-run-hooks-from-githooks (not _WIN32))
  ;; (magit-status-headers-hook
  ;;  '(magit-insert-error-header
  ;;    magit-insert-head-branch-header
  ;;    ))
  (magit-status-sections-hook
   '(magit-insert-error-header
     magit-insert-untracked-files
     magit-insert-unstaged-changes
     magit-insert-staged-changes
     magit-insert-recent-commits))
  :config
  (require 'reveal)

  (defun my-magit-reveal-point-if-invisible-h ()
    "Reveal the point if in an invisible region."
    (reveal-post-command))

  (defun my-magit-fast-diff ()
    (interactive)
    (when-let* ((file (magit-file-at-point)))
      (magit-diff-dwim nil `(,file))))

  (transient-append-suffix 'magit-fetch "-t"
    '("-d" "Depth 1" "--depth=1")))

(use-package magit-fast
  :ensure nil
  :demand t
  :after magit
  :init
  (magit-auto-revert-mode -1)
  (setq with-editor-emacsclient-executable (executable-find "emacsclient"))
  :config
  (remove-hook 'server-switch-hook 'magit-commit-diff)
  (remove-hook 'magit-pre-start-git-hook #'magit-maybe-save-repository-buffers)
  (magit-fast-mode))

(provide 'init-vc)
