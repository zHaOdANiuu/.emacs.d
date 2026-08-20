;;; -*- lexical-binding: t -*-
(use-package yaml-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'yaml)
  :mode
  ("\\.clangd\\'" . yaml-ts-mode)
  ("\\.clang-format\\'" . yaml-ts-mode)
  ("\\.clang-tidy\\'" . yaml-ts-mode)
  ("\\.ya?ml\\'" . yaml-ts-mode)
  :init
  (add-to-list 'treesit-language-source-alist
               '(yaml . ("https://github.com/tree-sitter-grammars/tree-sitter-yaml"))))

(provide 'lang-yaml)
