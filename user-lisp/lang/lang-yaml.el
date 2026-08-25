;;; -*- lexical-binding: t -*-
(use-package yaml-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'yaml)
  :mode "\\.clangd\\'" "\\.clang-format\\'" "\\.clang-tidy\\'" "\\.ya?ml\\'"
  :init
  (add-to-list 'treesit-language-source-alist
               '(yaml . ("https://github.com/tree-sitter-grammars/tree-sitter-yaml"))))

(provide 'lang-yaml)
