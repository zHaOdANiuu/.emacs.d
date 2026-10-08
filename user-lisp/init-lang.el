;;; -*- lexical-binding: t -*-
(require 'treesit)

(use-package syntax
  :ensure nil
  :init (setq syntax-wholeline-max 1000))

(use-package text-mode
  :ensure nil
  :mode "/INSTALL\\'" "/LICENSE\\'"
  :custom (text-mode-ispell-word-completion nil))

(use-package conf-mode
  :ensure nil
  :mode "\\.env\\..*\\'" "\\.env\\'" "/.gitignore\\'" "/..gitmodules\\'"
  :hook (conf-mode . indent-tabs-mode))

(use-package elisp-mode
  :ensure nil
  :bind
  ("<f12>" . find-function-at-point)
  ("C-<f12>" . find-variable-at-point)
  :hook (emacs-lisp-mode . prettify-symbols-mode)
  :custom
  (emacs-lisp-indent-offset nn-indent-offset)
  (lisp-indent-function #'my-lisp-indent-function)
  :config
  (defun my-lisp-indent-function (indent-point state)
    "See https://emacs.stackexchange.com/questions/10230/how-to-indent-keywords-aligned"
    (let ((normal-indent (current-column))
          (orig-point (point)))
      (goto-char (1+ (elt state 1)))
      (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
      (cond
       ((and (elt state 2)
             (or (not (looking-at "\\sw\\|\\s_"))
                 (looking-at ":")))
        (if (not (> (save-excursion (forward-line 1) (point))
                    calculate-lisp-indent-last-sexp))
            (progn (goto-char calculate-lisp-indent-last-sexp)
                   (beginning-of-line)
                   (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)))
        (backward-prefix-chars)
        (current-column))
       ((and (save-excursion
               (goto-char indent-point)
               (skip-syntax-forward " ")
               (not (looking-at ":")))
             (save-excursion
               (goto-char orig-point)
               (looking-at ":")))
        (save-excursion
          (goto-char (+ 2 (elt state 1)))
          (current-column)))
       (t
        (let ((function-name (buffer-substring (point) (progn (forward-sexp 1) (point))))
              method)
          (setq method (or (function-get (intern-soft function-name) 'lisp-indent-function)
                           (get (intern-soft function-name) 'lisp-indent-hook)))
          (cond ((or (eq method 'defun)
                     (and (null method)
                          (length> function-name 3)
                          (string-match "\\`def" function-name)))
                 (lisp-indent-defform state indent-point))
                ((integerp method)
                 (lisp-indent-specform method state indent-point normal-indent))
                (method
                 (funcall method indent-point state))))))))

  (define-advice calculate-lisp-indent
      (:override (&optional parse-start) my-emacs-lisp--calculate-lisp-indent-a)
    "Add better indentation for quoted and backquoted lists.

Intended as :override advice for `calculate-lisp-indent'.

Adapted from URL `https://www.reddit.com/r/emacs/comments/d7x7x8/finally_fixing_indentation_of_quoted_lists/'."
    ;; This line because `calculate-lisp-indent-last-sexp` was defined with
    ;; `defvar` with it's value ommited, marking it special and only defining it
    ;; locally. So if you don't have this, you'll get a void variable error.
    (defvar calculate-lisp-indent-last-sexp)
    (save-excursion
      (beginning-of-line)
      (let ((indent-point (point))
            state
            ;; setting this to a number inhibits calling hook
            (desired-indent nil)
            (retry t)
            calculate-lisp-indent-last-sexp containing-sexp)
        (cond ((or (markerp parse-start) (integerp parse-start))
               (goto-char parse-start))
              ((null parse-start)
               (beginning-of-defun))
              ((setq state parse-start)))
        (unless state
          ;; Find outermost containing sexp
          (while (< (point) indent-point)
            (setq state (parse-partial-sexp (point) indent-point 0))))
        ;; Find innermost containing sexp
        (while (and retry
                    state
                    (> (elt state 0) 0))
          (setq retry nil)
          (setq calculate-lisp-indent-last-sexp (elt state 2))
          (setq containing-sexp (elt state 1))
          ;; Position following last unclosed open.
          (goto-char (1+ containing-sexp))
          ;; Is there a complete sexp since then?
          (if (and calculate-lisp-indent-last-sexp
                   (> calculate-lisp-indent-last-sexp (point)))
              ;; Yes, but is there a containing sexp after that?
              (let ((peek (parse-partial-sexp calculate-lisp-indent-last-sexp
                                              indent-point 0)))
                (if (setq retry (car (cdr peek))) (setq state peek)))))
        (if retry
            nil
          ;; Innermost containing sexp found
          (goto-char (1+ containing-sexp))
          (if (not calculate-lisp-indent-last-sexp)
              ;; indent-point immediately follows open paren. Don't call hook.
              (setq desired-indent (current-column))
            ;; Find the start of first element of containing sexp.
            (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
            (cond ((looking-at "\\s(")
                   ;; First element of containing sexp is a list.  Indent under
                   ;; that list.
                   )
                  ((> (save-excursion (forward-line 1) (point))
                      calculate-lisp-indent-last-sexp)
                   ;; This is the first line to start within the containing sexp.
                   ;; It's almost certainly a function call.
                   (if (or
                        ;; Containing sexp has nothing before this line except the
                        ;; first element. Indent under that element.
                        (= (point) calculate-lisp-indent-last-sexp)

                        (or
                         ;; Align keywords in plists if each newline begins with
                         ;; a keyword. This is useful for "unquoted plist
                         ;; function" macros, like `map!' and `defhydra'.
                         (when-let* ((first (elt state 1))
                                     (char (char-after (1+ first))))
                           (and (eq char ?:)
                                (ignore-errors
                                  (or (save-excursion
                                        (goto-char first)
                                        ;; FIXME: Can we avoid `syntax-ppss'?
                                        (when-let* ((parse-sexp-ignore-comments t)
                                                    (end (scan-lists (point) 1 0))
                                                    (depth (ppss-depth (syntax-ppss))))
                                          (and (re-search-forward "^\\s-*:" end t)
                                               (= (ppss-depth (syntax-ppss))
                                                  (1+ depth)))))
                                      (save-excursion
                                        (cl-loop for pos in (reverse (elt state 9))
                                                 unless (memq (char-after (1+ pos)) '(?: ?\())
                                                 do (goto-char (1+ pos))
                                                 for fn = (read (current-buffer))
                                                 if (symbolp fn)
                                                 return (function-get fn 'indent-plists-as-data)))))))
                         ;; Check for quotes or backquotes around.
                         (let ((positions (elt state 9))
                               (quotep 0))
                           (while positions
                             (let ((point (pop positions)))
                               (or (when-let* ((char (char-before point)))
                                     (cond
                                      ((eq char ?\())
                                      ((memq char '(?\' ?\`))
                                       (or (save-excursion
                                             (goto-char (1+ point))
                                             (skip-chars-forward "( ")
                                             (when-let* ((fn (ignore-errors (read (current-buffer)))))
                                               (if (and (symbolp fn)
                                                        (fboundp fn)
                                                        ;; Only special forms and
                                                        ;; macros have special
                                                        ;; indent needs.
                                                        (not (functionp fn)))
                                                   (setq quotep 0))))
                                           (cl-incf quotep)))
                                      ((memq char '(?, ?@))
                                       (setq quotep 0))))
                                   ;; If the spelled out `quote' or `backquote'
                                   ;; are used, let's assume
                                   (save-excursion
                                     (goto-char (1+ point))
                                     (and (looking-at-p "\\(\\(?:back\\)?quote\\)[\t\n\f\s]+(")
                                          (cl-incf quotep 2)))
                                   (setq quotep (max 0 (1- quotep))))))
                           (> quotep 0))))
                       ;; Containing sexp has nothing before this line except the
                       ;; first element.  Indent under that element.
                       nil
                     ;; Skip the first element, find start of second (the first
                     ;; argument of the function call) and indent under.
                     (progn (forward-sexp 1)
                            (parse-partial-sexp (point)
                                                calculate-lisp-indent-last-sexp
                                                0 t)))
                   (backward-prefix-chars))
                  (t
                   ;; Indent beneath first sexp on same line as
                   ;; `calculate-lisp-indent-last-sexp'.  Again, it's almost
                   ;; certainly a function call.
                   (goto-char calculate-lisp-indent-last-sexp)
                   (beginning-of-line)
                   (parse-partial-sexp (point) calculate-lisp-indent-last-sexp
                                       0 t)
                   (backward-prefix-chars)))))
        ;; Point is at the point to indent under unless we are inside a string.
        ;; Call indentation hook except when overridden by lisp-indent-offset or
        ;; if the desired indentation has already been computed.
        (let ((normal-indent (current-column)))
          (cond ((elt state 3)
                 ;; Inside a string, don't change indentation.
                 nil)
                ((and (integerp lisp-indent-offset) containing-sexp)
                 ;; Indent by constant offset
                 (goto-char containing-sexp)
                 (+ (current-column) lisp-indent-offset))
                ;; in this case calculate-lisp-indent-last-sexp is not nil
                (calculate-lisp-indent-last-sexp
                 (or
                  ;; try to align the parameters of a known function
                  (and lisp-indent-function
                       (not retry)
                       (funcall lisp-indent-function indent-point state))
                  ;; If the function has no special alignment or it does not apply
                  ;; to this argument, try to align a constant-symbol under the
                  ;; last preceding constant symbol, if there is such one of the
                  ;; last 2 preceding symbols, in the previous uncommented line.
                  (and (save-excursion
                         (goto-char indent-point)
                         (skip-chars-forward " \t")
                         (looking-at ":"))
                       ;; The last sexp may not be at the indentation where it
                       ;; begins, so find that one, instead.
                       (save-excursion
                         (goto-char calculate-lisp-indent-last-sexp)
                         ;; Handle prefix characters and whitespace following an
                         ;; open paren. (Bug#1012)
                         (backward-prefix-chars)
                         (while (not (or (looking-back "^[ \t]*\\|([ \t]+"
                                                       (line-beginning-position))
                                         (and containing-sexp
                                              (>= (1+ containing-sexp) (point)))))
                           (forward-sexp -1)
                           (backward-prefix-chars))
                         (setq calculate-lisp-indent-last-sexp (point)))
                       (> calculate-lisp-indent-last-sexp
                          (save-excursion
                            (goto-char (1+ containing-sexp))
                            (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
                            (point)))
                       (let ((parse-sexp-ignore-comments t)
                             indent)
                         (goto-char calculate-lisp-indent-last-sexp)
                         (or (and (looking-at ":")
                                  (setq indent (current-column)))
                             (and (< (line-beginning-position)
                                     (prog2 (backward-sexp) (point)))
                                  (looking-at ":")
                                  (setq indent (current-column))))
                         indent))
                  ;; another symbols or constants not preceded by a constant as
                  ;; defined above.
                  normal-indent))
                ;; in this case calculate-lisp-indent-last-sexp is nil
                (desired-indent)
                (normal-indent)))))))



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

    (add-to-list 'eglot-server-programs '(simpcc-mode . my-clangd-args))))



(use-package js
  :ensure nil
  :custom
  (js-chain-indent t)
  (js-indent-level nn-indent-offset))

(use-package js-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'json)
  :mode "\\.[mc]?js\\'")

(use-package typescript-ts-mode
  :ensure nil
  :if (or (treesit-language-available-p 'typescript)
          (treesit-language-available-p 'tsx))
  :mode
  ("\\.ts\\'" . typescript-ts-mode)
  ("\\.tsx\\'" . tsx-ts-mode)
  :hook
  (tsx-ts-mode . my-add-jsdoc-in-typescript-ts-mode)
  (typescript-ts-mode . my-add-jsdoc-in-typescript-ts-mode)
  :init
  (add-to-list 'treesit-language-source-alist
               '(typescript . ("https://github.com/tree-sitter/tree-sitter-typescript"
                               nil "typescript/src")))
  (add-to-list 'treesit-language-source-alist
               '(tsx . ("https://github.com/tree-sitter/tree-sitter-typescript"
                        nil "tsx/src")))

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

  :custom (typescript-indent-level nn-indent-offset))

(use-package css-mode
  :ensure nil
  :init
  (add-to-list 'find-sibling-rules '("/\\([^/]+\\)\\.\\(\\(s[ac]\\|le\\)ss\\|styl\\)\\'" "\\1\\.css\\'"))
  (add-to-list 'find-sibling-rules '("/\\([^/]+\\)\\.css\\'" "\\1\\.\\(\\(s[ac]\\|le\\)ss\\|styl\\)\\'"))
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



(use-package python
  :ensure nil
  :mode ("/\\(?:Pipfile\\|\\.?flake8\\)\\'" . conf-mode)
  :custom
  (python-check-command nil)
  (python-indent-guess-indent-offset-verbose nil)
  :config
  ;; HACK: Python 3.13's pyrepl mishandles SIGINT under Emacs's comint
  ;;   (TERM=dumb), particularly on macOS. The ^C character is treated as
  ;;   literal input rather than triggering an interrupt signal. Disabling
  ;;   pyrepl forces the classic readline-based REPL which handles signals
  ;;   correctly. See #8391, also used by VS Code's Python extension.
  (add-to-list 'python-shell-process-environment "PYTHON_BASIC_REPL=1"))

(use-package sh-script
  :ensure nil
  :mode "\\.\$$?:bats\\|zunit\\|env\\\'" "/bspwmrc\\'"
  :hook
  ;; 1. Fontifies variables in double quotes
  ;; 2. Fontify command substitution in double quotes
  ;; 3. Fontify built-in/common commands (see `+sh-builtin-keywords')
  (sh-mode . my-sh-init-extra-fontification-h)
  :custom
  (sh-basic-offset nn-indent-offset)
  (sh-indent-after-continuation 'always)
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
  :custom (powershell-indent-level nn-indent-offset))



(use-package yaml-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'yaml)
  :mode "\\.clangd\\'" "\\.clang-format\\'" "\\.clang-tidy\\'" "\\.ya?ml\\'"
  :init
  (add-to-list 'treesit-language-source-alist
               '(yaml . ("https://github.com/tree-sitter-grammars/tree-sitter-yaml"))))

(use-package json-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'json)
  :mode "\\.json\\'"
  :init (add-to-list 'treesit-language-source-alist
                     '(json . ("https://github.com/tree-sitter/tree-sitter-json"))))



(use-package markdown-ts-mode
  :ensure nil
  :if (treesit-language-available-p 'markdown)
  :mode "\\.md\\'" "/README\\'"
  :hook
  (markdown-ts-mode . display-fill-column-indicator-mode)
  (markdown-ts-mode . markdown-ts-toggle-hide-markup)
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


(use-package ol
  :ensure nil
  :config
  (org-link-set-parameters
   "file"
   :face
   (lambda (path)
     (if (or (if _WIN32
                 (string-prefix-p "//" path))
             (file-remote-p path)
             (if _WIN32
                 (string-prefix-p "\\\\" path))
             (file-exists-p path))
         'org-link
       '(warning org-link)))))

(use-package org
  :ensure nil
  :bind
  (("C-c o a" . org-agenda)
   ("C-c o b" . org-switchb)
   ("C-c o x" . org-capture)
   (:map org-mode-map
    ("M-<up>"       . my-org-move-line-up)
    ("M-<down>"     . my-org-move-line-down)
    ("M-{"          . org-shiftmetaleft)
    ("M-}"          . org-shiftmetaright)
    ("M-S-<left>"   . nil)
    ("M-S-<right>"  . nil)
    ("C-S-<up>"     . nil)
    ("C-S-<down>"   . nil)
    ("C-<return>"   . org-insert-heading-respect-content)
    ("C-S-<return>" . org-insert-todo-heading-respect-content)
    ("C-M-<return>" . org-insert-subheading)
    ("C-c '"        . org-edit-special)
    ("C-c ."        . org-time-stamp)
    ("C-c !"        . org-time-stamp-inactive)
    ("C-c @"        . org-cite-insert)
    ("C-c *"        . org-ctrl-c-star)
    ("C-c -"        . org-ctrl-c-minus)
    ("C-c C-l"      . org-toggle-link-display)
    ("C-c C-,"      . org-insert-structure-template)
    ("C-c C-t"      . org-todo)
    ("C-c C-q"      . org-set-tags-command)
    ("C-c C-d"      . org-deadline)
    ("C-c C-s"      . org-schedule)
    ("C-c C-o"      . org-open-at-point)
    ("C-c C-x e"    . org-export-dispatch)
    ("C-c C-x C-w"  . org-cut-subtree)
    ("C-c C-x C-a"  . org-archive-subtree-default)))
  :hook
  (org-mode . display-fill-column-indicator-mode)
  ((org-babel-after-execute org-mode) . org-redisplay-inline-images)
  :custom-face (org-ellipsis ((t :inherit nn-ellipsis)))
  :custom
  (org-persist-directory (concat nn-directory "org/persist/"))
  (org-id-locations-file (concat nn-directory "org/id-locations.el"))
  (org-modules nil)
  (org-modules-loaded t)
  (org-ellipsis nn-ellipsis)
  (org-startup-indented t)
  (org-adapt-indentation 'headline-data)
  (org-startup-folded 'fold)
  (org-src-tab-acts-natively t)
  (org-src-fontify-natively t)
  (org-pretty-entities t)
  (org-hide-emphasis-markers t)
  (org-hide-leading-stars nil)
  (org-support-shift-select t)
  (org-auto-align-tags nil)
  (org-log-done 'time)
  (org-enforce-todo-dependencies t)
  (org-tags-column 0)
  (org-confirm-babel-evaluate nil)
  (org-catch-invisible-edits 'show-and-error)
  (org-image-actual-width nil)
  (org-special-ctrl-a/e t)
  (org-M-RET-may-split-line nil)
  (org-insert-heading-respect-content t)
  (org-indirect-buffer-display 'current-window)
  (org-fontify-done-headline t)
  (org-fontify-quote-and-verse-blocks t)
  (org-use-sub-superscripts '{})
  (org-todo-keywords
   '((sequence
      "TODO(t)" "PROJ(p)" "LOOP(r)" "STRT(s)"
      "WAIT(w)" "HOLD(h)" "IDEA(i)"
      "|" "DONE(d)" "KILL(k)")
     (sequence
      "[ ](T)" "[-](S)" "[?](W)"
      "|" "[X](D)")
     (sequence
      "|" "OKAY(o)" "YES(y)" "NO(n)")))
  (org-babel-load-languages
   '((emacs-lisp . t) (python . t)
     (shell . t) (perl . t)
     (C . t) (java . t)
     (js . t) (css . t)
     (plantuml . t)))
  :config
  (add-to-list 'org-structure-template-alist '("n" . "note"))
  (add-to-list 'org-tags-exclude-from-inheritance "crypt")
  (add-to-list 'org-file-apps
               '("\\.\\(x?html?\\|pdf\\)\\'"  .
                 (lambda (file _link)
                   (centaur-browse-url-of-file (browse-url-file-url file)))))

  (defun my-org--at-movable-node-p ()
    (or (org-at-table-p)
        (and (featurep 'org-inlinetask)
             (org-inlinetask-in-task-p))
        (org-at-heading-p)
        (org-at-item-p)))

  (defun my-org-move-line-up ()
    (interactive)
    (if (my-org--at-movable-node-p)
        (org-metaup)
      (my-move-line-up)))

  (defun my-org-move-line-down ()
    (interactive)
    (if (my-org--at-movable-node-p)
        (org-metadown)
      (my-move-line-down)))

  (dolist (abbrev '(("github"     . "https://github.com/%s")
                    ("youtube"    . "https://youtube.com/watch?v=%s")
                    ("google"     . "https://google.com/search?q=%s")
                    ("gimages"    . "https://google.com/images?q=%s")
                    ("gmap"       . "https://maps.google.com/maps?q=%s")
                    ("kagi"       . "https://kagi.com/search?q=%s")
                    ("duckduckgo" . "https://duckduckgo.com/?q=%s")
                    ("wikipedia"  . "https://en.wikipedia.org/wiki/%s")
                    ("wolfram"    . "https://wolframalpha.com/input/?i=%s")
                    ("emacsdir"   . ,(expand-file-name "%s" user))))
    (add-to-list 'org-link-abbrev-alist abbrev)))

(use-package org-agenda
  :ensure nil
  :bind
  (:map org-agenda-mode-map
   ("t" . org-agenda-todo)
   ("r" . org-agenda-refile)
   ("q" . org-agenda-set-tags)
   ("d" . org-agenda-deadline)
   ("s" . org-agenda-schedule)
   ("C-SPC" . org-agenda-show-and-scroll-up))
  :custom
  (org-agenda-files '("~/agenda.org"))
  (org-agenda-window-setup 'current-window)
  (org-agenda-skip-unavailable-files t)
  (org-agenda-span 10)
  (org-agenda-start-on-weekday nil)
  (org-agenda-start-day "-3d")
  (org-agenda-inhibit-startup t))

(use-package org-src
  :ensure nil
  :custom
  (org-src-preserve-indentation t)
  (org-src-lang-modes
   '(("el" . emacs-lisp) ("elisp" . emacs-lisp)
     ("sh" . sh) ("bash" . sh) ("powershell" . powershell)
     ("bat" . bat) ("vbs" . js)
     ("html" . web) ("css" . css) ("scss" . scss)
     ("javascript" . js) ("js" . js) ("jsx" . js)
     ("typescript" . typescript-ts) ("ts" . typescript-ts) ("tsx" . tsx-ts)
     ("java" . java) ("go" . go-ts) ("rust" . rust-ts) ("python" . python)
     ("c" . c) ("c++" . c++) ("cpp" . c++) ("glsl" . c))))

(use-package org-capture
  :ensure nil
  :custom
  (org-capture-templates
   `(("i" "Idea" entry (file ,(concat org-directory "/idea.org"))
      "*  %^{Title} %?\n%U\n%a\n")
     ("t" "Todo" entry (file ,(concat org-directory "/gtd.org"))
      "* TODO %?\n%U\n%a\n" :clock-in t :clock-resume t)
     ("n" "Note" entry (file ,(concat org-directory "/note.org"))
      "* %? :NOTE:\n%U\n%a\n" :clock-in t :clock-resume t)
     ("j" "Journal" entry (file+olp+datetree
                           ,(concat org-directory "/journal.org"))
      "*  %^{Title} %?\n%U\n%a\n" :clock-in t :clock-resume t)
     ("b" "Book" entry (file+olp+datetree
                        ,(concat org-directory "/book.org"))
      "* Topic: %^{Description} %^g %? Added: %U"))))

(use-package org-entities
  :ensure nil
  :custom
  (org-entities-user
   '(("flat"  "\\flat" nil "" "" "266D" "♭")
     ("sharp" "\\sharp" nil "" "" "266F" "♯"))))

(use-package org-clock
  :ensure nil
  :commands org-clock-save
  :init  (setq org-clock-persist-file (concat nn-directory "org/clock-persist.el"))
  :custom
  (org-clock-persist 'history)
  (org-clock-in-resume t)
  (org-clock-out-remove-zero-time-clocks t)
  :config
  (add-hook 'kill-emacs-hook #'org-clock-save)
  (dolist (cmd '(org-clock-in org-clock-out org-clock-goto org-clock-cancel))
    (advice-add cmd :before #'org-clock-load)))

(use-package org-crypt
  :ensure nil
  :commands org-encrypt-entries org-encrypt-entry org-decrypt-entries org-decrypt-entry
  :hook (org-load . org-crypt-use-before-save-magic)
  :config (org-crypt-use-before-save-magic))

(use-package org-faces
  :ensure nil
  :custom
  (org-priority-faces
   '((?A . error)
     (?B . warning)
     (?C . success)))
  (org-agenda-deadline-faces
   '((1.0 . error)
     (1.0 . org-warning)
     (0.5 . org-upcoming-deadline)
     (0.0 . org-upcoming-distant-deadline))))

(use-package org-modern
  :hook
  (org-mode . org-modern-mode)
  (org-agenda-finalize . org-modern-agenda)
  :custom
  (org-modern-table t)
  (org-modern-table-vertical 1)
  (org-modern-table-horizontal 1)
  (org-modern-star 'replace)
  (org-modern-replace-stars "◉⦿⊚⊙∘"))

(provide 'init-lang)
