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

(use-package simpcc-mode
  :vc (:url "https://github.com/zHaOdANiuu/simpcc-mode" :rev :newest)
  :mode "\\.\\(c\\|h\\|cc\\|hh\\|cpp\\|hpp\\|cppm\\|ixx\\|rc\\)\\'"
  :config
  (setq simpcc-types
        (append
         simpcc-types
         '("f16" "f32" "f64" "f128"
           "i8" "i16" "i32" "i64"
           "u8" "u16" "u32" "u64"
           "char8" "char16" "char32")))
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '(simpc++-mode . my-clangd-args))))

(provide 'lang-cc)
