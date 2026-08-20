;;; -*- lexical-binding: t -*-
(use-package web-mode
  :mode "\\.\\(html?\\|vue\\)$"
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
  (web-mode-markup-indent-offset 2)
  (web-mode-code-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-enable-css-colorization nil)
  (web-mode-enable-auto-closing t)
  (web-mode-enable-current-element-highlight t)
  :config (setf (alist-get "javascript" web-mode-comment-formats nil nil #'equal) "//"))

(use-package emmet-mode
  :hook (web-mode html-mode mhtml-mode css-mode)
  :custom
  (emmet-move-cursor-between-quotes t)
  (emmet-move-cursor-after-expanding t)
  :config
  (when (require 'yasnippet nil t)
    (add-hook 'emmet-mode-hook #'yas-minor-mode-on)))

(provide 'lang-web)
