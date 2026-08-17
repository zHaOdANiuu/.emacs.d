;;; -*- lexical-binding: t -*-
(use-package sh-script
  :ensure nil
  :mode "\\.\$$?:bats\\|zunit\\|env\\\'" "/bspwmrc\\'"
  :hook
  ;; 1. Fontifies variables in double quotes
  ;; 2. Fontify command substitution in double quotes
  ;; 3. Fontify built-in/common commands (see `+sh-builtin-keywords')
  (sh-mode . my-sh-init-extra-fontification-h)
  :custom (sh-indent-after-continuation 'always)
  :config
  (add-to-list 'sh-imenu-generic-expression
               '(sh (nil "^\\s-*function\\s-+\\([[:alpha:]_-][[:alnum:]_-]*\\)\\s-*\\(?:()\\)?" 1)
                    (nil "^\\s-*\\([[:alpha:]_-][[:alnum:]_-]*\\)\\s-*()" 1)))

  (defconst my-sh-builtin-keywords
    '("cat" "cd" "chmod" "chown" "cp" "curl" "date" "echo" "find" "git" "grep"
      "kill" "less" "ln" "ls" "make" "mkdir" "mv" "pgrep" "pkill" "pwd" "rm"
      "sleep" "sudo" "touch")
    "A list of common shell commands to be fontified especially in `sh-mode'.")

  (defun my-sh--match-variables-in-quotes (limit)
    "Search for variables in double-quoted strings bounded by LIMIT."
    (with-syntax-table sh-mode-syntax-table
      (let (res)
        (while
            (and (setq res
                       (re-search-forward
                        "[^\\]\\(\\$\\)\\({.+?}\\|\\<[a-zA-Z0-9_]+\\|[@*#!]\\)"
                        limit t))
                 (not (eq (nth 3 (syntax-ppss)) ?\"))))
        res)))

  (defun my-sh--match-command-subst-in-quotes (limit)
    "Search for variables in double-quoted strings bounded by LIMIT."
    (with-syntax-table sh-mode-syntax-table
      (let (res)
        (while
            (and (setq res
                       (re-search-forward
                        "[^\\]\\(\\$(.+?)\\|`.+?`\\)"
                        limit t))
                 (not (eq (nth 3 (syntax-ppss)) ?\"))))
        res)))

  (defun my-sh-init-extra-fontification-h ()
    (font-lock-add-keywords
     nil `((my-sh--match-variables-in-quotes
            (1 'font-lock-constant-face prepend)
            (2 'font-lock-variable-name-face prepend))
           (my-sh--match-command-subst-in-quotes
            (1 'sh-quoted-exec prepend))
           (,(regexp-opt my-sh-builtin-keywords 'symbols)
            (0 'font-lock-type-face append))))))

(use-package powershell
  :custom (powershell-indent-level 2))

(provide 'lang-shell)
