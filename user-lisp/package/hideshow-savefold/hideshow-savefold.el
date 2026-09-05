;;; hideshow-savefold.el --- Persist hideshow folds across sessions -*- lexical-binding: t; -*-

;;; Commentary:

;; Persistence for hideshow (hs-minor-mode) folds.  Saves fold state to
;; disk when a buffer is killed or Emacs exits, and restores it when a
;; file is revisited.

;;; Code:

(require 'hideshow)

(defvar hideshow-savefold--fpath-to-attr-table (make-hash-table :test #'equal)
  "Hash table mapping file paths to their attribute hash tables.")

(defconst hideshow-savefold--folds-attr 'hideshow-savefold-folds
  "Key used to store fold data in the attr table.")

(defsubst hideshow-savefold--buffer-file (&optional fpath)
  "Resolve FPATH or return the current buffer's expanded file name."
  (or fpath
      (and (buffer-file-name)
           (expand-file-name (buffer-file-name)))))

(defgroup hideshow-savefold nil
  "Persist hideshow folds across Emacs sessions."
  :group 'convenience
  :group 'hideshow)

(defcustom hideshow-savefold-directory
  (locate-user-emacs-file "hideshow-savefold")
  "Directory where hideshow fold data is persisted."
  :type 'directory
  :group 'hideshow-savefold)

(defun hideshow-savefold--attr-table-fpath (fpath)
  "Return the filesystem path of the attr-table file for FPATH."
  (let* ((fpath (expand-file-name fpath))
         (fpath (string-replace "/" "!" fpath))
         (fpath (string-replace ":" "!" fpath)))
    (expand-file-name fpath hideshow-savefold-directory)))

(defun hideshow-savefold--get-attr-table (fpath)
  "Get the attribute hash table for file FPATH; create if absent."
  (or (gethash fpath hideshow-savefold--fpath-to-attr-table)
      (let ((table (if-let* ((apath (hideshow-savefold--attr-table-fpath fpath))
                             ((file-exists-p apath)))
                       (with-temp-buffer
                         (insert-file-contents apath)
                         (goto-char (point-min))
                         (read (current-buffer)))
                     (make-hash-table))))
        (puthash fpath table hideshow-savefold--fpath-to-attr-table)
        table)))

(defun hideshow-savefold--get-attr (attr &optional fpath)
  "Return attribute ATTR for file FPATH, or current buffer's file."
  (when-let* ((f (hideshow-savefold--buffer-file fpath)))
    (gethash attr (hideshow-savefold--get-attr-table f))))

(defun hideshow-savefold--set-attr (attr value &optional fpath)
  "Set attribute ATTR to VALUE for file FPATH.
Call `hideshow-savefold--write-attrs' afterwards to persist."
  (when-let* ((f (hideshow-savefold--buffer-file fpath)))
    (puthash attr value (hideshow-savefold--get-attr-table f))))

(defun hideshow-savefold--write-attrs (&optional fpath)
  "Persist the attr table for FPATH to disk."
  (when-let* ((f (hideshow-savefold--buffer-file fpath)))
    (unless (file-exists-p hideshow-savefold-directory)
      (make-directory hideshow-savefold-directory t))
    (with-temp-file (hideshow-savefold--attr-table-fpath f)
      (prin1 (gethash f hideshow-savefold--fpath-to-attr-table)
             (current-buffer)))))

(defun hideshow-savefold--set-modtime ()
  "Record the current file's modification time as an attr."
  (hideshow-savefold--set-attr
   'hideshow-savefold-modtime
   (visited-file-modtime)))

(defun hideshow-savefold--file-newer-than-saved-p ()
  "Return t if the current file is newer than the saved fold data."
  (when-let* ((saved-modtime
               (hideshow-savefold--get-attr
                'hideshow-savefold-modtime)))
    (< (float-time saved-modtime) (float-time (visited-file-modtime)))))

(defun hideshow-savefold--collect-folds ()
  "Return a list of (start end kind) for all hs overlays in buffer."
  (let (folds)
    (dolist (ov (overlays-in (point-min) (point-max)))
      (when-let* ((kind (overlay-get ov 'hs)))
        (push (list (overlay-start ov) (overlay-end ov) kind) folds)))
    (nreverse folds)))

(defun hideshow-savefold--save ()
  "Save hideshow fold data for the current buffer to disk."
  (when (and (buffer-file-name)
             (not (buffer-modified-p)))
    (hideshow-savefold--set-attr hideshow-savefold--folds-attr
                                 (hideshow-savefold--collect-folds))
    (hideshow-savefold--set-modtime)
    (hideshow-savefold--write-attrs)))

(defun hideshow-savefold--restore ()
  "Restore saved hideshow folds for the current buffer."
  (when (buffer-file-name)
    (unless (hideshow-savefold--file-newer-than-saved-p)
      (when-let* ((folds (hideshow-savefold--get-attr
                          hideshow-savefold--folds-attr)))
        (dolist (fd folds)
          (hs-make-overlay (car fd) (cadr fd) (caddr fd)))))))

(defun hideshow-savefold--mapc-buffers (fun pred)
  "Call FUN in every live buffer where PRED returns non-nil."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (funcall pred)
        (funcall fun)))))

(defun hideshow-savefold--hs-buffer-p ()
  "Return t if the current buffer has hs-minor-mode active."
  (bound-and-true-p hs-minor-mode))

(defun hideshow-savefold--setup-kill-buffer-hook ()
  "Add save-on-kill to the buffer-local `kill-buffer-hook'."
  (add-hook 'kill-buffer-hook #'hideshow-savefold--save nil t))

(defun hideshow-savefold--teardown-kill-buffer-hook ()
  "Remove save-on-kill from the buffer-local `kill-buffer-hook'."
  (remove-hook 'kill-buffer-hook #'hideshow-savefold--save t))

(defun hideshow-savefold--save-all-buffers ()
  "Save fold data for every hs-minor-mode buffer."
  (hideshow-savefold--mapc-buffers
   #'hideshow-savefold--save
   #'hideshow-savefold--hs-buffer-p))

;;;###autoload
(define-minor-mode hideshow-savefold-mode
  "Toggle persistence of hideshow folds.

When enabled, hideshow fold state is saved to disk when a buffer
is killed or Emacs exits, and restored when a file is re-opened.

This is a global minor mode."
  :global t
  :init-value nil
  :group 'hideshow-savefold
  (if hideshow-savefold-mode
      (progn
        (add-hook 'hs-minor-mode-hook #'hideshow-savefold--restore)
        (add-hook 'hs-minor-mode-hook #'hideshow-savefold--setup-kill-buffer-hook)
        (add-hook 'kill-emacs-hook #'hideshow-savefold--save-all-buffers)
        (hideshow-savefold--mapc-buffers
         #'hideshow-savefold--setup-kill-buffer-hook
         #'hideshow-savefold--hs-buffer-p))
    (remove-hook 'hs-minor-mode-hook #'hideshow-savefold--restore)
    (remove-hook 'hs-minor-mode-hook #'hideshow-savefold--setup-kill-buffer-hook)
    (remove-hook 'kill-emacs-hook #'hideshow-savefold--save-all-buffers)
    (hideshow-savefold--mapc-buffers
     #'hideshow-savefold--teardown-kill-buffer-hook
     #'hideshow-savefold--hs-buffer-p)))

(provide 'hideshow-savefold)
;;; hideshow-savefold.el ends here
