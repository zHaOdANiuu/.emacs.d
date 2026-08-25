;;; -*- lexical-binding: t -*-
(use-package json-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'json)
  :mode "\\.json\\'"
  ;; :hook (json-ts-mode . eglot-ensure)
  :init (add-to-list 'treesit-language-source-alist
                     '(json . ("https://github.com/tree-sitter/tree-sitter-json"))))

(provide 'lang-json)
