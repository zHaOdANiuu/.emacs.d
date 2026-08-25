;;; -*- lexical-binding: t -*-
(use-package ispell
  :ensure nil
  :custom
  (ispell-program-name "aspell")
  (ispell-local-dictionary "en_US")
  (ispell-extra-args '("--sug-mode=ultra" "--lang=en_US" "--run-together"))
  (ispell-alternate-dictionary nil))

(use-package flyspell
  :ensure nil
  :if (executable-find "aspell")
  :bind
  (:map flyspell-mode-map
   ("C-;" . nil)
   ("C-," . nil)
   ("C-." . nil))
  :hook (org-mode markdown-ts-mode TeX-mode rst-mode message-mode git-commit-setup)
  :custom
  (flyspell-issue-message-flag nil)
  (flyspell-issue-welcome-flag nil))

(use-package flymake
  :ensure nil
  :bind
  (:map flymake-mode-map
   ("<f8>"   . flymake-goto-next-error)
   ("<S-f8>" . flymake-goto-prev-error)
   ("<C-f8>" . flymake-show-buffer-diagnostics))
  :hook (flymake-mode .  (lambda () (setq-local next-error-function #'flymake-goto-next-error)))
  :custom
  (flymake-no-changes-timeout nil)
  (flymake-wrap-around nil)
  (flymake-fringe-indicator-position nil)
  (flymake-margin-indicators-string
   '((error "" compilation-error)
     (warning "" compilation-warning)
     (note "" compilation-info)))
  (flymake-show-diagnostics-at-end-of-line t)
  :config
  (setq-default next-error-find-buffer-function #'next-error-buffer-unnavigated-current)

  (define-advice elisp-flymake-byte-compile (:before-while (&rest _) check-git-repo)
    "Only enable elisp flymake if inside a git repo."
    (locate-dominating-file default-directory ".git"))

  ;; saveing check
  (cl-defmethod eglot-handle-notification :after
    (_server (_method (eql textDocument/publishDiagnostics)) &key uri
             &allow-other-keys)
    (when-let* ((buffer (find-buffer-visiting (eglot-uri-to-path uri))))
      (with-current-buffer buffer
        (if (and (eq nil flymake-no-changes-timeout)
                 (not (buffer-modified-p)))
            (flymake-start t))))))

(provide 'init-diagnostics)
