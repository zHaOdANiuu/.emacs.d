;;; -*- lexical-binding: t -*-
(use-package markdown-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'markdown)
  :mode "\\.md\\'" "/README\\'"
  :init
  (add-to-list 'treesit-language-source-alist
               '(markdown . ("https://github.com/tree-sitter-grammars/tree-sitter-markdown"
                             nil "tree-sitter-markdown/src")))
  (add-to-list 'treesit-language-source-alist
               '(markdown-inline . ("https://github.com/tree-sitter-grammars/tree-sitter-markdown"
                                    nil "tree-sitter-markdown-inline/src")))
  :custom
  (markdown-ts-inline-images t)
  (markdown-ts-image-max-width 600)
  :config
  (setq markdown-ts-code-block-modes
        '((el emacs-lisp-mode) (elisp emacs-lisp-mode)
          (sh sh-mode) (bash sh-mode) (powershell powershell-mode)
          (bat bat-mode) (powershell sh-mode) (vbs js-mode)
          (html web-mode) (css css-mode) (scss scss-mode)
          (javascript js-mode) (js js-mode) (jsx js-mode)
          (typescript typescript-ts-mode) (ts typescript-ts-mode) (tsx typescript-tsx-mode)
          (java java-mode) (go go-ts-mode) (rust rust-ts-mode) (python python-mode)
          (c c-mode) (c++ c++-mode) (cpp c++-mode))))

(provide 'lang-markdown)
