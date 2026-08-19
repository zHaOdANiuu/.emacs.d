;;; -*- lexical-binding: t -*-
(defun my-add-jsdoc-in-typescript-ts-mode ()
  "Add jsdoc treesitter rules to typescript as a host language.
As seen on: https://www.reddit.com/r/emacs/comments/1kfblch/need_help_with_adding_jsdoc_highlighting_to"
  ;; I copied this code from js.el (js-ts-mode), with minimal modifications.
  (when (treesit-ready-p 'typescript)
    (when (treesit-ready-p 'jsdoc t)
      (setq-local treesit-range-settings
                  (treesit-range-rules
                   :embed 'jsdoc
                   :host 'typescript
                   :local t
                   `(((comment) @capture (:match ,(rx bos "/**") @capture)))))
      (setq c-ts-common--comment-regexp (rx (or "comment" "line_comment" "block_comment" "description")))

      (defvar my/treesit-font-lock-settings-jsdoc
        (treesit-font-lock-rules
         :language 'jsdoc
         :override t
         :feature 'document
         '((document) @font-lock-doc-face)

         :language 'jsdoc
         :override t
         :feature 'keyword
         '((tag_name) @font-lock-constant-face)

         :language 'jsdoc
         :override t
         :feature 'bracket
         '((["{" "}"]) @font-lock-bracket-face)

         :language 'jsdoc
         :override t
         :feature 'property
         '((type) @font-lock-type-face)

         :language 'jsdoc
         :override t
         :feature 'definition
         '((identifier) @font-lock-variable-face)))
      (setq-local treesit-font-lock-settings
                  (append treesit-font-lock-settings my/treesit-font-lock-settings-jsdoc)))))

(use-package js
  :ensure nil
  :mode ("\\.[mc]?js\\'" . js-mode)
  :custom
  (js-chain-indent t)
  (js-indent-level 2))

(use-package typescript-ts-mode
  :ensure nil
  :if (or (treesit-language-available-p 'typescript)
          (treesit-language-available-p 'tsx))
  :mode
  ("\\.ts\\'" . typescript-ts-mode)
  ("\\.tsx\\'" . tsx-ts-mode)
  :hook
  (tsx-ts-mode . eglot-ensure)
  (tsx-ts-mode . my-add-jsdoc-in-typescript-ts-mode)
  (typescript-ts-mode . eglot-ensure)
  (typescript-ts-mode . my-add-jsdoc-in-typescript-ts-mode)
  :init
  (add-to-list 'treesit-language-source-alist
               '(typescript . ("https://github.com/tree-sitter/tree-sitter-typescript"
                               nil "typescript/src")))
  (add-to-list 'treesit-language-source-alist
               '(tsx . ("https://github.com/tree-sitter/tree-sitter-typescript"
                        nil "tsx/src")))
  :custom (typescript-indent-level 2))

(provide 'lang-javascript)
