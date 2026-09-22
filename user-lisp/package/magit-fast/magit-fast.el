;;; -*- lexical-binding: t -*-
(defvar magit-fast--porcelain-cache nil
  "Cached parsed output of `git status --porcelain'.
Invalidated at the start of each Magit refresh cycle.")

(defgroup magit-fast nil
  "Magit fast."
  :prefix "magit-fast-"
  :group 'magit)

(defcustom magit-fast-section-pairs
  '((magit-insert-untracked-files . magit-fast-insert-untracked-files)
    (magit-insert-unstaged-changes . magit-fast-insert-unstaged-changes)
    (magit-insert-staged-changes . magit-fast-insert-staged-changes)
    (magit-insert-recent-commits . magit-fast-insert-recent-commits))
  "Alist mapping original section functions to fast replacements.
Each entry is (ORIGINAL . REPLACEMENT).  When `magit-fast-mode'
is enabled, ORIGINAL is replaced by REPLACEMENT in
`magit-status-sections-hook'.  When disabled, the replacement is
reversed."
  :type '(alist :key-type function :value-type function)
  :group 'magit-fast)

(defcustom magit-fast-status-alist
  '(("M" "modified" . (:foreground "#f9e2af"))
    ("A" "new file" . (:foreground "#a6e3a1"))
    ("D" "deleted"  . (:foreground "#f38ba8"))
    ("R" "renamed"  . (:foreground "#89b4fa"))
    ("C" "copied"   . (:foreground "#94e2d5"))
    ("U" "unmerged" . (:foreground "#cba6f7")))
  "Alist mapping git status code to label and face.
Each entry is (CODE LABEL . FACE), where CODE is the first
character of the git status output, LABEL is the human-readable
name, and FACE is the face to use when displaying the entry."
  :type 'list
  :group 'magit-fast)

(defun magit-fast--porcelain-parse ()
  "Run `git status --porcelain' once and parse into a plist.
Keys:
  :untracked  list of (\"??\" . FILE)
  :staged     list of (CODE . FILE), CODE is a one-char string
  :unstaged   list of (CODE . FILE)"
  (let (untracked staged unstaged)
    (dolist (line (magit-git-lines "status" "--porcelain" "--no-renames"))
      (when (> (length line) 3)
        (let* ((x    (aref line 0))
               (y    (aref line 1))
               (file (substring line 3))
               (xc   (char-to-string x))
               (yc   (char-to-string y)))
          (if (and (eq x ??) (eq y ??))
              (push (cons "??" file) untracked)
            (unless (memq x '(?\s ??))
              (push (cons xc file) staged))
            (unless (eq y ?\s)
              (push (cons yc file) unstaged))))))
    `(:untracked ,(nreverse untracked)
      :staged    ,(nreverse staged)
      :unstaged  ,(nreverse unstaged))))

(defun magit-fast--porcelain-invalidate ()
  "Clear the porcelain cache.  Run via `magit-pre-refresh-hook'."
  (setq magit-fast--porcelain-cache nil))

(defun magit-fast--git--porcelain (&optional type)
  "Return parsed `git status --porcelain' output, cached per refresh.

TYPE controls the return value:
  nil / `all'  -> plist (:untracked ... :staged ... :unstaged ...)
  `untracked'  -> list of untracked file paths
  `staged'     -> list of (CODE . FILE) for staged entries
  `unstaged'   -> list of (CODE . FILE) for unstaged entries
  `both'       -> cons (STAGED . UNSTAGED)

The cache is cleared at the start of every Magit refresh via
`magit-pre-refresh-hook', so the underlying `git status' runs at
most once per refresh, no matter how many sections call this."
  (unless magit-fast--porcelain-cache
    (setq magit-fast--porcelain-cache (magit-fast--porcelain-parse)))
  (let ((cache magit-fast--porcelain-cache))
    (cond
     ((or (null type) (eq type 'all)) cache)
     ((eq type 'untracked) (plist-get cache :untracked))
     ((eq type 'staged)    (plist-get cache :staged))
     ((eq type 'unstaged)  (plist-get cache :unstaged))
     (t (error "magit-fast: unknown type %S" type)))))

(defun magit-fast--insert (entries)
  "Insert ENTRIES (list of (CODE . FILE)) as Magit file sections."
  (dolist (entry entries)
    (let* ((code (car entry))
           (file (cdr entry))
           (info (assoc code magit-fast-status-alist)))
      (magit-insert-section
       (file file)
       (insert
        (propertize
         (format "%-10s%s\n" (if info (cadr info) code) file)
         'font-lock-face (if info (cddr info) 'magit-diff-file-heading))))))
  (insert "\n"))

(defun magit-fast-insert-untracked-files ()
  (when-let* ((entries (magit-fast--git--porcelain 'untracked)))
    (magit-insert-section
     (untracked) (magit-insert-heading t "Untracked files")
     (magit-fast--insert entries))))

(defun magit-fast-insert-unstaged-changes ()
  (when-let* ((entries (magit-fast--git--porcelain 'unstaged)))
    (magit-insert-section
     (unstaged) (magit-insert-heading t "Unstaged changes")
     (magit-fast--insert entries))))

(defun magit-fast-insert-staged-changes ()
  (when-let* ((entries (magit-fast--git--porcelain 'staged)))
    (magit-insert-section
     (staged) (magit-insert-heading t "Staged changes")
     (magit-fast--insert entries))))

(defun magit-fast-insert-recent-commits (&optional type value)
  (when-let* ((lines (magit-git-lines
                      "log" "--no-color" "--decorate=short"
                      "--pretty=format:%h%x0c%d%x0c%s"
                      (format "-n%d" magit-log-section-commit-count))))
    (magit-insert-section
     ((eval (or type 'recent)) magit-log-section-commit-count t)
     (magit-insert-heading "Recent commits")
     (dolist (line lines)
       (let* ((parts (split-string line "\f"))
              (hash (nth 0 parts))
              (deco (string-trim-left (nth 1 parts)))
              (subj (nth 2 parts)))
         (insert
          (propertize hash 'font-lock-face 'magit-hash)
          " "
          (if (string-empty-p deco)
              ""
            (concat
             (propertize deco 'font-lock-face
                         (if (string-prefix-p "(HEAD" deco)
                             'magit-branch-current
                           'magit-branch-remote))
             " "))
          (propertize subj 'font-lock-face 'magit-log-commit-heading)
          "\n"))))))

(defun magit-fast--replace-sections (forward)
  "Replace section functions.
If FORWARD is non-nil, replace originals with fast versions.
Otherwise restore originals."
  (setf magit-status-sections-hook
        (mapcar (lambda (fn)
                  (let ((pair (if forward
                                  (assq fn magit-fast-section-pairs)
                                (rassq fn magit-fast-section-pairs))))
                    (or (if forward (cdr pair) (car pair)) fn)))
                magit-status-sections-hook)))

;;;###autoload
(define-minor-mode magit-fast-mode
  "Cache static repository info across a single Magit refresh."
  :global t
  :init-value nil
  :group 'magit-fast
  (if magit-fast-mode
      (progn
        (magit-fast--replace-sections t)
        (add-hook 'magit-pre-refresh-hook #'magit-fast--porcelain-invalidate))
    (magit-fast--replace-sections nil)
    (remove-hook 'magit-pre-refresh-hook #'magit-fast--porcelain-invalidate)))

(provide 'magit-fast)
