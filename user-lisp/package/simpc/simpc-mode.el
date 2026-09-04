;;; simpc-mode.el --- Simple C mode -*- lexical-binding: t; -*-

;; ref https://github.com/rexim/simpc-mode/blob/master/simpc-mode.el

(defcustom simpc-indent-width 2
  "Simpc indent width"
  :type 'number)

(defconst simpc-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?# "." table)
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?% "." table)
    table))

(defconst simpc-types
  '("char" "int" "long" "short" "void" "bool" "float" "double" "signed" "unsigned"
    "char16_t" "char32_t" "char8_t" "wchar_t"
    "int8_t" "uint8_t" "int16_t" "uint16_t"
    "int32_t" "uint32_t" "int64_t" "uint64_t"
    "uintptr_t" "size_t" "ptrdiff_t" "va_list"))

(defconst simpc-keywords
  '("module" "export" "import"
    "class" "struct" "union" "enum" "typedef" "using"
    "decltype" "sizeof" "alignas" "alignof" "typeid"
    "auto" "const" "constexpr" "consteval" "constinit" "volatile"
    "extern" "static" "thread_local" "register"
    "operator" "inline" "explicit" "virtual" "override" "noexcept"
    "public" "protected" "private" "final" "friend" "mutable"
    "new" "delete" "this"
    "template" "typename" "requires" "concept"
    "static_cast" "dynamic_cast" "const_cast" "reinterpret_cast"
    "if" "else" "switch" "case" "default"
    "while" "do" "for" "break" "continue"
    "goto" "return"
    "try" "catch" "throw"
    "co_await" "co_return" "co_yield"
    "and" "and_eq" "or" "or_eq" "not" "not_eq" "xor" "xor_eq"
    "bitand" "bitor" "compl"
    "namespace" "asm" "static_assert" "reflexpr" "synchronized" "atomic_cancel"
    "atomic_commit" "atomic_noexcept"))

(defconst simpc-font-lock-keywords
  `(("^# *\\(warn\\|error\\)" 0 font-lock-warning-face)
    ("^# *[#a-zA-Z0-9_]+" 0 font-lock-preprocessor-face)
    ("^# *include\\(?:_next\\)?\\s-+\\(\\(<\\|\"\\).*\\(>\\|\"\\)\\)" 1 font-lock-string-face)
    (,(regexp-opt simpc-keywords 'symbols) 0 font-lock-keyword-face)
    (,(regexp-opt simpc-types 'symbols) 0 font-lock-type-face)
    ("\\_<\\(?:true\\|false\\|nullptr\\)\\_>" 0 font-lock-constant-face)
    ("\\_<0[xX][0-9a-fA-F_]+\\_>" 0 font-lock-constant-face)
    ("\\_<0[bB][01_]+\\_>" 0 font-lock-constant-face)
    ("\\_<[0-9][0-9_]*\\(?:\\.[0-9_]*\\)?\\(?:[eE][+-]?[0-9_]*\\)?[uUlLfF]*\\_>" 0 font-lock-constant-face)
    ("\\([a-zA-Z_][a-zA-Z0-9_]*\\)::" 1 font-lock-constant-face)
    ("\\<\\(?:enum\\|using\\|struct\\|class\\)\\s-+\\([a-zA-Z0-9_]+\\)" 1 font-lock-type-face)
    ("\\<typedef\\b\\s-+[a-zA-Z_][a-zA-Z0-9_]*\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s-*;" 1 font-lock-type-face)
    ("\\<typedef\\b[^}]*}\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)" 1 font-lock-type-face)
    ("\\<\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\([*&][ \t]*\\|[ \t]+[*&]\\)\\([a-zA-Z_][a-zA-Z0-9_]*\\b\\|[][;,}>\n)]\\)"
     1 font-lock-type-face)
    ("\\_<\\([A-Za-z_][A-Za-z0-9_]*\\)[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*[;=,({)]" 1 font-lock-type-face)
    ;; c++ func () -> return type
    (")\\s-*->\\s-*\\([^{\n]+\\)\\s-*{" 1 font-lock-type-face)
    ("\\b\\([a-zA-Z_][a-zA-Z0-9_]*\\)[ \t]*(" 1 font-lock-function-name-face)
    ;; function pointer
    ("(\\*\\([A-Za-z_][A-Za-z0-9_]*\\)\\s-*)\\s-*(" 1 font-lock-function-name-face)
    (")[ \t]*(" ("\\_<\\([A-Za-z_][A-Za-z0-9_]*\\)[*& \t]*[,)]" nil nil (1 font-lock-type-face)))))

(defun simpc--proper-indentation (parse-status)
  (let ((depth (nth 0 parse-status))             ; Depth in parens
        (paren-start (nth 1 parse-status))       ; Position of the paren that started this list
        ;; (paren-prev (nth 2 parse-status))     ; Position of the previous sibling paren
        ;; (in-string (nth 3 parse-status))      ; Non-nil if inside a string
        (in-comment (nth 4 parse-status))        ; Non-nil if inside a comment
        ;; (string-start (nth 5 parse-status))   ; Start position of string or comment
        ;; (string-end (nth 6 parse-status))     ; End position of string or comment
        ;; (string-type (nth 7 parse-status))    ; Type of string or comment
        ;; (string-content (nth 8 parse-status)) ; Content of string or comment
        ;; (in-block (nth 9 parse-status))       ; Non-nil if inside a code block
        )
    ;; Print all information for debugging
    ;; (message "=== Parse Status ===")
    ;; (message "Depth: %S" depth)
    ;; (message "Paren start: %S" paren-start)
    ;; (message "Paren prev: %S" paren-prev)
    ;; (message "In string: %S" in-string)
    ;; (message "In comment: %S" in-comment)
    ;; (message "String start: %S" string-start)
    ;; (message "String end: %S" string-end)
    ;; (message "String type: %S" string-type)
    ;; (message "String content: %S" string-content)
    ;; (message "In block: %S" in-block)
    (save-excursion
      (back-to-indentation)
      (cond
       (in-comment (current-indentation))

       ((save-excursion
          (forward-line -1)
          (back-to-indentation)
          (looking-at "\\_<\\(if\\|while\\|for\\|else\\|do\\|try\\|catch\\)\\_>"))
        (save-excursion
          (forward-line -1)
          (back-to-indentation)
          (+ (current-indentation) simpc-indent-width)))

       (paren-start
        (let ((close-p (looking-at "[]})]"))
              (case-label-p (looking-at "\\_<\\(case\\|default\\)\\_>")))
          (goto-char paren-start)
          (back-to-indentation)
          (if close-p
              (current-column)
            (+ (current-column)
               (* simpc-indent-width
                  (if (looking-at "\\_<switch\\_>")
                      (if case-label-p 1 2)
                    1))))))

       (t (prog-first-column))))))

(defun simpc-indent-line ()
  (interactive)
  (let* ((parse-status
          (save-excursion (syntax-ppss (line-beginning-position))))
         (offset (- (point) (save-excursion (back-to-indentation) (point)))))
    (unless (nth 3 parse-status)
      (indent-line-to (simpc--proper-indentation parse-status))
      (when (> offset 0) (forward-char offset)))))

(define-derived-mode simpc-mode prog-mode "Simple C"
  "Simple major mode for editing C files."
  :syntax-table simpc-mode-syntax-table
  (setq-local font-lock-defaults '(simpc-font-lock-keywords))
  (setq-local indent-line-function #'simpc-indent-line)
  (setq-local comment-start "// ")
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width simpc-indent-width))

(provide 'simpc-mode)
;;; simpc-mode.el ends here
