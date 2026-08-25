;;; -*- lexical-binding: t -*-
(use-package elisp-mode
  :ensure nil
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
                (normal-indent))))))

  (define-advice elisp-get-var-docstring
      (:around (fn sym) my-emacs-lisp-append-value-to-eldoc-a)
    "Display variable value next to documentation in eldoc."
    (when-let* ((ret (funcall fn sym)))
      (if (boundp sym)
          (concat
           ret " "
           (let* ((truncated " [...]")
                  (print-escape-newlines t)
                  (str (prin1-to-string (symbol-value sym)))
                  (limit (- (frame-width) (length ret) (length truncated) 1)))
             (format (format "%%0.%ds%%s" (max limit 0)) str
                     (if (< (length str) limit) "" truncated))))
        ret))))

(use-package help-mode
  :ensure nil
  :hook (help-mode . cursor-sensor-mode)
  :bind (:map help-mode-map ("r" . my-remove-hook-at-point))
  :config
  (defun my-function-advices (function)
    "Return FUNCTION's advices."
    (let ((flist (indirect-function function)) advices)
      (while (advice--p flist)
        (setq advices `(,@advices ,(advice--car flist)))
        (setq flist (advice--cdr flist)))
      advices))

  (defun my-help--update ()
    "Update the help buffer."
    (if (eq major-mode 'helpful-mode)
        (helpful-update)
      (revert-buffer nil t)))

  (defun my-add-remove-advice-button (advice function)
    (when (and (functionp advice) (functionp function))
      (let ((inhibit-read-only t)
            (msg (format "Remove advice `%s'" advice)))
        (insert "\t")
        (insert-button
         "Remove"
         'face 'custom-button
         'cursor-sensor-functions `((lambda (&rest _) ,msg))
         'help-echo msg
         'action (lambda (_)
                   (when (yes-or-no-p msg)
                     (message "%s from function `%s'" msg function)
                     (advice-remove function advice)
                     (my-help--update)))
         'follow-link t))))

  (defun my-add-button-to-remove-advice (buffer-or-name function)
    "Add a button to remove advice."
    (with-current-buffer buffer-or-name
      (save-excursion
        (goto-char (point-min))
        (let ((ad-list (my-function-advices function)))
          (while (re-search-forward "^\\(?:This function has \\)?:[-a-z]+ advice: \\(.+\\)$" nil t)
            (let ((advice (car ad-list)))
              (my-add-remove-advice-button advice function)
              (setq ad-list (delq advice ad-list))))))))

  (defun my-remove-hook-at-point ()
    "Remove the hook at the point in the *Help* buffer."
    (interactive)
    (unless (memq major-mode '(help-mode helpful-mode))
      (error "Only for help-mode or helpful-mode"))
    (let ((orig-point (point)))
      (save-excursion
        (when-let*
            ((hook (progn (goto-char (point-min)) (symbol-at-point)))
             (func
              (when (and
                     (or (re-search-forward (format "^Value:?[\s|\n]") nil t)
                         (goto-char orig-point))
                     (thing-at-point 'sexp))
                (thing-at-point--end-of-sexp)
                (backward-char 1)
                (catch 'break
                  (while t
                    (condition-case _err
                        (backward-sexp)
                      (scan-error (throw 'break nil)))
                    (let ((bounds (bounds-of-thing-at-point 'sexp)))
                      (when (<= (car bounds) orig-point (cdr bounds))
                        (throw 'break (thing-at-point 'sexp)))))))))
          (when (yes-or-no-p (format "Remove %s from %s? " func hook))
            (remove-hook hook (intern func))
            (my-help--update))))))

  (define-advice describe-function-1 (:after (f) my-advice-remove-button)
    (my-add-button-to-remove-advice (help-buffer) f))

  (define-advice helpful-update (:after () my-advice-remove-button)
    (when helpful--callable-p
      (my-add-button-to-remove-advice (current-buffer) helpful--sym))))

(provide 'lang-elisp)
