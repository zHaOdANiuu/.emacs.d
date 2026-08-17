;;; -*- lexical-binding: t -*-
(when (eq system-type 'windows-nt)
  (setenv "GIT_TERMINAL_PROMPT" "0")
  (setenv "GIT_ASK_YESNO" "false")
  (setenv "GIT_PAGER" "cat")
  (setenv "GIT_OPTIONAL_LOCKS" "0")
  (setenv "GIT_ASKPASS" "git-gui--askpass"))

(use-package vc
  :ensure nil
  :custom
  (vc-follow-symlinks t)
  (vc-handled-backends '(SVN Git Hg))
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
  :bind
  (:map diff-mode-map
   ("M-o" . other-window))
  :hook (diff-mode . outline-minor-mode)
  :custom
  (diff-default-read-only t)
  (diff-advance-after-apply-hunk t)
  (diff-update-on-the-fly t)
  (diff-font-lock-syntax 'hunk-also)
  (diff-font-lock-prettify nil))

(use-package ediff
  :ensure nil
  :hook
  (ediff-prepare-buffer . outline-show-all)
  (ediff-quit . tab-bar-history-back)
  :custom
  (ediff-diff-options "-w")
  (ediff-window-setup-function #'ediff-setup-windows-plain)
  (ediff-split-window-function #'split-window-horizontally)
  (ediff-merge-split-window-function #'split-window-horizontally))

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
  (transient-history-file (expand-file-name "transient/history.el" nn-directory))
  (transient-levels-file (expand-file-name "transient/levels.el" nn-directory))
  (transient-values-file (expand-file-name "transient/values.el" nn-directory))
  :config
  (make-directory (expand-file-name "transient/" nn-directory) t))

(use-package magit
  :commands magit-file-delete
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
  (magit-diff-refine-hunk t)
  (magit-uniquify-buffer-names nil)
  (magit-no-confirm '(stage-all-changes unstage-all-changes))
  (magit-run-hooks-from-githooks (not (eq system-type 'windows-nt)))
  (magit-status-sections-hook
   '(magit-insert-status-headers
     magit-insert-untracked-files
     my-magit-insert-unstaged-files
     my-magit-insert-staged-files
     magit-insert-stashes
     magit-insert-recent-commits))
  :config
  (defconst my-magit--status-alist
    '(("M" "modified" . (:foreground "#f9e2af"))
      ("A" "new file" . (:foreground "#a6e3a1"))
      ("D" "deleted"  . (:foreground "#f38ba8"))
      ("R" "renamed"  . (:foreground "#89b4fa"))
      ("C" "copied"   . (:foreground "#94e2d5"))
      ("U" "unmerged" . (:foreground "#cba6f7"))))

  (defun my-magit--wash-diff (line)
    (let* ((parts (split-string line "\t" t))
           (code (substring (car parts) 0 1))
           (file (cadr parts))
           (info (assoc code my-magit--status-alist))
           (status (if info (cadr info) code))
           (face (if info (cddr info) 'magit-diff-file-heading)))
      (when (and code file)
        (magit-insert-section (file file)
          (insert (propertize
                   (concat (format "%-10s" status) file "\n")
                   'font-lock-face face))))))

  (defun my-magit-insert-unstaged-files ()
    (let ((files (magit-git-lines "diff" "--name-status")))
      (when files
        (magit-insert-section (unstaged 'unstaged)
          (magit-insert-heading "Unstaged changes:")
          (dolist (line files)
            (unless (string-empty-p line)
              (my-magit--wash-diff line)))))))

  (defun my-magit-insert-staged-files ()
    (let ((files (magit-git-lines "diff" "--cached" "--name-status")))
      (when files
        (magit-insert-section (staged 'staged)
          (magit-insert-heading "Staged changes:")
          (dolist (line files)
            (unless (string-empty-p line)
              (my-magit--wash-diff line)))))))

  (defun my-magit-reveal-point-if-invisible-h ()
    "Reveal the point if in an invisible region."
    (if (derived-mode-p 'org-mode)
        (org-reveal '(4))
      (require 'reveal)
      (reveal-post-command))))

(provide 'init-vc)
