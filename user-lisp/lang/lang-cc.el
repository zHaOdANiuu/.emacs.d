;;; -*- lexical-binding: t -*-
(defvar my-clangd--query-driver
  (concat (executable-find "gcc") "," (executable-find "g++")))

(defun my-clangd-args (_interactive)
  (let ((proj (project-current)))
    `("clangd"
      "--clang-tidy"
      "--limit-results=15"
      "--header-insertion=never"
      "--background-index"
      "--pch-storage=memory"
      "--experimental-modules-support"
      ,(concat "--query-driver=" my-clangd--query-driver)
      ,(concat "--compile-commands-dir="
               (expand-file-name (if proj (project-root proj) default-directory))))))

(use-package simpc-mode
  :ensure nil
  :mode "\\.\\(c\\|h\\|cpp\\|hpp\\|cppm\\|ixx\\)\\'"
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '(simpc-mode . my-clangd-args))))

(provide 'lang-cc)
