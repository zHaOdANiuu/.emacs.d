;;; -*- lexical-binding: t -*-
(defconst my--word-re "[[:word:]]+\\|[^[:word:]\t ]+"
  "A word: a run of word chars or a run of punctuation.")

(defconst my--word-chars
  "[:word:]" "Word chars (skip-chars set).")

(defconst my--sep-chars
  "^[:word:]\t " "Punctuation (skip-chars set).")

(defun my--word-char-p (pos)
  "Non-nil if char at POS is a word char."
  (let ((c (char-after pos))) (and c (eq (char-syntax c) ?w))))

(defun my--next-word (lim)
  "Return (START . END) of the word at/after point, within LIMIT."
  (when (re-search-forward my--word-re lim t)
    (cons (match-beginning 0) (match-end 0))))

(defun my--prev-word (lim)
  "Return (START . END) of the word at/just before point, bounded by LIMIT."
  (save-excursion
    (goto-char (max lim (1- (point))))
    (when (looking-at "[ \t]")
      (skip-chars-backward " \t" lim)
      (when (> (point) lim) (backward-char 1)))
    (when (> (point) lim)
      (let* ((cs (if (my--word-char-p (point)) my--word-chars my--sep-chars))
             (end (save-excursion (skip-chars-forward cs (line-end-position)) (point))))
        (skip-chars-backward cs lim)
        (cons (point) end)))))

(defun my--skip (w lim rev)
  "If word W is one punct char followed by a word char, skip over it:
return next word's END (or previous word's START when REV), else W's end/start."
  (if (and (= (cdr w) (1+ (car w))) (my--word-char-p (cdr w)))
      (let ((w2 (save-excursion
                  (goto-char (if rev (car w) (cdr w)))
                  (if rev (my--prev-word lim) (my--next-word lim)))))
        (if w2 (if rev (car w2) (cdr w2)) lim))
    (if rev (car w) (cdr w))))

(defun my--fwd (&optional skip)
  "Move point to end of current/next word."
  (let ((eol (line-end-position)))
    (if (< (point) eol)
        (let ((w (my--next-word eol)))
          (goto-char (if w (if skip (my--skip w eol nil) (cdr w)) eol)))
      (when (< (point) (point-max))
        (forward-char 1) (my--fwd skip)))))

(defun my--bwd (&optional skip)
  "Move point to start of previous word."
  (let ((bol (line-beginning-position)))
    (if (= (point) bol)
        (when (> (point) (point-min))
          (backward-char 1) (my--bwd skip))
      (let ((w (my--prev-word bol)))
        (goto-char (if w (if skip (my--skip w bol t) (car w)) bol))))))

(defun my-forward-word (&optional arg)
  (interactive "^p")
  (dotimes (_ (or arg 1)) (my--fwd t)))

(defun my-backward-word (&optional arg)
  (interactive "^p")
  (dotimes (_ (or arg 1)) (my--bwd t)))

(defun my-delete-word (dir)
  "Delete word toward DIR (+1 forward, -1 backward)."
  (interactive)
  (if (and mark-active (not (eq (mark) (point))))
      (delete-region (min (mark) (point)) (max (mark) (point)))
    (let* ((pos (point))
           (dst (save-excursion
                  (if (> dir 0)
                      (if (looking-at "[ \t]")
                          (skip-chars-forward " \t" (line-end-position))
                        (my--fwd nil))
                    (if (memq (char-before) '(?\s ?\t))
                        (skip-chars-backward " \t")
                      (my--bwd nil)))
                  (point))))
      (when (if (> dir 0) (> dst pos) (< dst pos))
        (delete-region (min pos dst) (max pos dst))))))

(keymap-global-set "M-f" #'my-forward-word)
(keymap-global-set "M-b" #'my-backward-word)
(keymap-global-set "C-<right>" #'my-forward-word)
(keymap-global-set "C-<left>" #'my-backward-word)
(keymap-global-set "C-<delete>" (lambda () (interactive) (my-delete-word 1)))
(keymap-global-set "C-<backspace>" (lambda () (interactive) (my-delete-word -1)))

(provide 'init-word-move)
