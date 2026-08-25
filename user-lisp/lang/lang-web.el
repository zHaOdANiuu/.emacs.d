;;; -*- lexical-binding: t -*-
(use-package css-mode
  :ensure nil
  :custom (css-fontify-colors nil))

(use-package css-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'css)
  :mode "\\.css\\'")

(use-package html-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'html))

(use-package mhtml-ts-mode
  :ensure nil
  :if (and (treesit-language-available-p 'html)
           (treesit-language-available-p 'css)
           (treesit-language-available-p 'javascript))
  :mode "\\.\\(html?\\|vue\\)$"
  :custom (mhtml-ts-mode-css-fontify-colors nil))

(use-package web-mode
  :if (not (featurep 'mhtml-ts-mode))
  :mode "\\.[px]?html?\\'"
  :mode "\\.\\(?:tpl\\|blade\\)\\(?:\\.php\\)?\\'"
  :mode "\\.erb\\'"
  :mode "\\.[lh]?eex\\'"
  :mode "\\.jsp\\'"
  :mode "\\.as[cp]x\\'"
  :mode "\\.ejs\\'"
  :mode "\\.hbs\\'"
  :mode "\\.mustache\\'"
  :mode "\\.svelte\\'"
  :mode "\\.twig\\'"
  :mode "\\.jinja2?\\'"
  :mode "\\.eco\\'"
  :mode "wp-content/themes/.+/.+\\.php\\'"
  :mode "templates/.+\\.php\\'"
  :mode "\\.vue\\'"
  :bind
  (:map web-mode-map
   ("C-c C-h" . web-mode-reload)
   ("C-c C-i" . web-mode-buffer-indent)
   ("M-]" . web-mode-tag-next)
   ("M-[" . web-mode-tag-previous)
   ("C-M-]" . web-mode-attribute-next)
   ("C-M-[" . web-mode-attribute-previous)
   ("C-c C-f" . web-mode-fold-or-unfold)
   ("C-c C-w" . web-mode-element-wrap)
   ("C-c C-k" . web-mode-element-kill)
   ("C-c C-r" . web-mode-element-rename)
   ("C-c C-c" . web-mode-element-clone)
   ("C-c /" . web-mode-element-close)
   ("C-c t s" . web-mode-tag-select)
   ("C-c t m" . web-mode-tag-match))
  :custom
  (web-mode-auto-close-style 1)
  (web-mode-markup-indent-offset nn-indent-offset)
  (web-mode-code-indent-offset nn-indent-offset)
  (web-mode-css-indent-offset nn-indent-offset)
  (web-mode-enable-css-colorization nil)
  (web-mode-enable-auto-closing t)
  (web-mode-enable-current-element-highlight t)
  (web-mode-enable-html-entities-fontification t)
  :config
  (setf (alist-get "javascript" web-mode-comment-formats nil nil #'equal) "//")
  (add-to-list 'web-mode-engines-alist '("elixir" . "\\.eex\\'"))
  (add-to-list 'web-mode-engines-alist '("phoenix" . "\\.[lh]eex\\'")))

(use-package emmet-mode
  :bind
  (:map emmet-mode-keymap
   ([tab] . my-web/indent-or-yas-or-emmet-expand )
   ("M-E" . emmet-expand-line))
  :hook (web-mode html-mode html-ts-mode mhtml-mode mhtml-ts-mode css-mode css-ts-mode)
  :custom
  (emmet-move-cursor-between-quotes t)
  (emmet-move-cursor-after-expanding t)
  :config
  (when (require 'yasnippet nil t)
    (add-hook 'emmet-mode-hook #'yas-minor-mode-on))

  (defun my-web/indent-or-yas-or-emmet-expand ()
    "Do-what-I-mean on TAB.

Invokes `indent-for-tab-command' if at or before text bol, `yas-expand' if on a
snippet, or `emmet-expand-yas'/`emmet-expand-line', depending on whether
`yas-minor-mode' is enabled or not."
    (interactive)
    (call-interactively
     (cond ((or (<= (current-column) (current-indentation))
                (not (eolp))
                (not (or (memq (char-after) (list ?\n ?\s ?\t))
                         (eobp))))
            #'indent-for-tab-command)
           ((featurep 'yasnippet)
            (require 'yasnippet)
            (if (yas--templates-for-key-at-point)
                #'yas-expand
              #'emmet-expand-yas))
           (#'emmet-expand-line)))))

(provide 'lang-web)
