;;; -*- lexical-binding: t -*-
(defgroup magit-fast nil
  "Magit fast."
  :prefix "magit-fast-"
  :group 'magit)

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

(defcustom magit-fast--section-pairs
  '((magit-insert-unstaged-changes . magit-fast-insert-unstaged-changes)
    (magit-insert-staged-changes . magit-fast-insert-staged-changes))
  "Alist mapping original section functions to fast replacements.
Each entry is (ORIGINAL . REPLACEMENT).  When `magit-fast-mode'
is enabled, ORIGINAL is replaced by REPLACEMENT in
`magit-status-sections-hook'.  When disabled, the replacement is
reversed."
  :type '(alist :key-type function :value-type function)
  :group 'magit-fast)

(defun magit-fast--replace-sections (forward)
  "Replace section functions.
If FORWARD is non-nil, replace originals with fast versions.
Otherwise restore originals."
  (setf magit-status-sections-hook
        (mapcar (lambda (fn)
                  (let ((pair (if forward
                                  (assq fn magit-fast--section-pairs)
                                (rassq fn magit-fast--section-pairs))))
                    (or (if forward (cdr pair) (car pair)) fn)))
                magit-status-sections-hook)))

(defun magit-fast--insert (lines)
  "Insert file status LINES as Magit file sections."
  (dolist (line lines)
    (let* ((parts (split-string line "\t"))
           (code (car parts))
           (file (car (last parts)))
           (info (and code (assoc (substring code 0 1) magit-fast-status-alist))))
      (magit-insert-section (file file)
        (insert
         (propertize
          (format "%-10s%s\n" (if info (cadr info) code) file)
          'font-lock-face (if info (cddr info) 'magit-diff-file-heading))))))
  (insert "\n"))

(defun magit-fast-insert-unstaged-changes ()
  "Insert compact status entries for unstaged files."
  (when-let* ((lines (magit-git-lines "diff" "--name-status")))
    (magit-insert-section (unstaged)
      (magit-insert-heading t "Unstaged changes")
      (magit-fast--insert lines))))

(defun magit-fast-insert-staged-changes ()
  "Insert compact status entries for staged files."
  (unless (magit-bare-repo-p)
    (when-let* ((lines (magit-git-lines "diff" "--cached" "--name-status")))
      (magit-insert-section (staged)
        (magit-insert-heading t "Staged changes")
        (magit-fast--insert lines)))))

;;;###autoload
(define-minor-mode magit-fast-mode
  "Cache static repository info across a single Magit refresh."
  :global t
  :init-value nil
  :group 'magit-fast
  (if magit-fast-mode
      (magit-fast--replace-sections t)
    (magit-fast--replace-sections nil)))

(provide 'magit-fast)
