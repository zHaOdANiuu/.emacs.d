;;; -*- lexical-binding: t -*-
(use-package vc
  :ensure nil
  :custom
  (vc-follow-symlinks t)
  (vc-handled-backends '(Git))
  (vc-ignored-dir-regexp (format "%s\\|%s" locate-dominating-stop-dir-regexp "[/\\\\]node_modules")))

(use-package vc-dir
  :ensure nil
  :bind
  (:map vc-dir-mode-map
   ("RET" . vc-diff)
   ("c" . vc-next-action)
   ("f" . vc-pull))
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
  :hook
  (ediff-quit . tab-bar-history-back)
  (ediff-prepare-buffer . outline-show-all)
  (ediff-before-setup . my-ediff-save-wconf-h)
  ((ediff-quit ediff-suspend) . my-ediff-restore-wconf-h)
  :custom
  (ediff-diff-options "-w")
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
  (magit-status-mode . (lambda () (setq long-line-threshold nil)))
  (magit-process-mode . goto-address-mode)
  (magit-diff-visit-file . my-magit-reveal-point-if-invisible-h)
  :custom
  (git-commit-major-mode 'git-commit-elisp-text-mode)
  (magit-commit-show-diff nil)
  (magit-commit-ask-to-stage nil)
  (magit-auto-revert-mode nil)
  (magit-refresh-verbose nil)
  (magit-refresh-status-buffer nil)
  (magit-revision-insert-related-refs nil)
  (magit-save-repository-buffers nil)
  (magit-uniquify-buffer-names nil)
  (magit-no-confirm '(stage-all-changes unstage-all-changes))
  (magit-run-hooks-from-githooks (not (eq system-type 'windows-nt)))
  (magit-status-sections-hook
   '(magit-insert-status-headers
     magit-insert-untracked-files
     my-magit-insert-unstaged-files
     my-magit-insert-staged-files
     magit-insert-recent-commits))
  :config
  (defconst my-magit--status-alist
    '(("M" "modified" . (:foreground "#f9e2af"))
      ("A" "new file" . (:foreground "#a6e3a1"))
      ("D" "deleted"  . (:foreground "#f38ba8"))
      ("R" "renamed"  . (:foreground "#89b4fa"))
      ("C" "copied"   . (:foreground "#94e2d5"))
      ("U" "unmerged" . (:foreground "#cba6f7"))))

  (defun my-magit--insert (lines)
    "Insert file status LINES as Magit file sections."
    (dolist (line lines)
      (let* ((parts (split-string line "\t"))
             (code (car parts))
             (file (car (last parts)))
             (info (and code (assoc (substring code 0 1) my-magit--status-alist))))
        (magit-insert-section (file file)
          (insert
           (propertize
            (format "%-10s%s\n" (if info (cadr info) code) file)
            'font-lock-face (if info (cddr info) 'magit-diff-file-heading))))))
    (insert "\n"))

  (defun my-magit-insert-unstaged-files ()
    "Insert compact status entries for unstaged files."
    (when-let* ((lines (magit-git-lines "diff" "--name-status")))
      (magit-insert-section (unstaged)
        (magit-insert-heading t "Unstaged changes")
        (my-magit--insert lines))))

  (defun my-magit-insert-staged-files ()
    "Insert compact status entries for staged files."
    (unless (magit-bare-repo-p)
      (when-let* ((lines (magit-git-lines "diff" "--cached" "--name-status")))
        (magit-insert-section (staged)
          (magit-insert-heading t "Staged changes")
          (my-magit--insert lines)))))

  (defun my-magit-reveal-point-if-invisible-h ()
    "Reveal the point if in an invisible region."
    (if (derived-mode-p 'org-mode)
        (org-reveal '(4))
      (require 'reveal)
      (reveal-post-command)))

  (defun my-magit-fast-diff ()
    (interactive)
    (when-let* ((file (magit-file-at-point)))
      (magit-diff-dwim nil `(,file)))))

(provide 'init-vc)
