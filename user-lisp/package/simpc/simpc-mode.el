;;; simpc-mode.el --- Simple C mode -*- lexical-binding: t; -*-
(defcustom simpc-indent-width 2
  "Simpc indent width (matches VSCode's default tabSize for C/C++).")

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

(defvar simpc-font-lock-keywords
  `(("^# *\\(warn\\|error\\)" 0 font-lock-warning-face)
    ("^# *[#a-zA-Z0-9_]+" 0 font-lock-preprocessor-face)
    ("^# *include\\(?:_next\\)?\\s-+\\(\\(<\\|\"\\).*\\(>\\|\"\\)\\)" 1 font-lock-string-face)
    (,(regexp-opt simpc-keywords 'words) 0 font-lock-keyword-face)
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

(defun simpc--line-content ()
  "Content of the current line without the trailing newline, as a string
\(never nil, even on an empty line)."
  (buffer-substring-no-properties (line-beginning-position) (line-end-position)))

(defun simpc--previous-non-empty-line ()
  "Return the nearest preceding non-blank line as (CONTENT 0 INDENTATION),
or nil if there is none."
  (save-excursion
    (move-beginning-of-line nil)
    (if (bobp)
        nil
      (forward-line -1)
      (let ((line (string-trim-right (simpc--line-content))))
        (while (and (not (bobp)) (string-empty-p line))
          (forward-line -1)
          (setq line (string-trim-right (simpc--line-content))))
        (if (string-empty-p line)
            nil
          (cons line (current-indentation)))))))

(defun simpc--desired-indentation ()
  (let* ((width (max simpc-indent-width 0))
         (cur-line (string-trim-right (simpc--line-content)))
         (nonblank (simpc--previous-non-empty-line))
         (prev-line (if nonblank (car nonblank) ""))
         (prev-indent (if nonblank (cdr nonblank) 0)))
    (cond ((string-match-p "^\\s-*switch\\s-*(.+)" prev-line)
           (+ prev-indent width))
          (t
           (max (+ prev-indent
                   (if (and nonblank
                            (or
                             (string-match-p
                              "^.*\\({[^}]*\\|([^)]*\\|\\[[^]]*\\)$"
                              prev-line)
                             (string-match-p
                              "^[ \t]*\\(if\\|while\\|for\\|else\\([ \t]+if\\)?\\)[ \t]*([^)]*)[ \t]*$"
                              prev-line)))
                       width 0)
                   (cond ((and nonblank
                               (string-suffix-p ":" prev-line)
                               (not (string-suffix-p ":" cur-line)))
                          width)
                         ((string-match-p ":[ \t]*{?[ \t]*$" cur-line) (- width))
                         (t 0))
                   (if (string-match-p "^[ \t]*[]})]" cur-line) (- width) 0))
                0)))))

(defun simpc-indent-line ()
  (interactive)
  (when (not (bobp))
    (let* ((desired-indentation
            (simpc--desired-indentation))
           (n (max (- (current-column) (current-indentation)) 0)))
      (indent-line-to desired-indentation)
      (forward-char n))))

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
