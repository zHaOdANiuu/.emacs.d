;;; nn-license-template.el --- Generate LICENSE file from templates -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defgroup nn-license-template nil
  "Generate LICENSE file from built-in templates."
  :group 'tools)

(defcustom nn-license-template-directory
  (expand-file-name "templates" (file-name-directory (or load-file-name buffer-file-name)))
  "Directory containing license template files."
  :type 'directory
  :group 'nn-license-template)

;;;###autoload
(defun nn-license-template-header ()
  "Insert a license file header at the beginning of the current buffer.
The header is wrapped in the major-mode's comment syntax."
  (interactive)
  (let* ((choices (nn-license-template--list))
         (name (completing-read "Header license: " choices nil t))
         (content (nn-license-template--read name)))
    (save-excursion
      (goto-char (point-min))
      (let ((beg (point)))
        (insert content)
        (unless (bolp) (insert "\n"))
        (comment-region beg (point))
        (insert "\n")))))

(defun nn-license-template--list ()
  "Return list of available license names (without .txt extension)."
  (mapcar (lambda (f)
            (file-name-base f))
          (directory-files nn-license-template-directory t "\\.txt\\'")))

(defun nn-license-template--read (name)
  "Read template NAME, substituting placeholders."
  (let ((template (expand-file-name (concat name ".txt") nn-license-template-directory)))
    (with-temp-buffer
      (insert-file-contents template)
      (goto-char (point-min))
      (while (search-forward "{{ year }}" nil t)
        (replace-match (format-time-string "%Y")))
      (goto-char (point-min))
      (while (search-forward "{{ organization }}" nil t)
        (replace-match (or user-full-name "Author")))
      (buffer-string))))

;;;###autoload
(defun nn-license-template-file ()
  "Prompt for a license and write it to LICENSE in `default-directory'."
  (interactive)
  (let* ((choices (nn-license-template--list))
         (name (completing-read "License: " choices nil t))
         (content (nn-license-template--read name))
         (dest (expand-file-name "LICENSE" default-directory)))
    (when (file-exists-p dest)
      (unless (y-or-n-p (format "%s exists. Overwrite? " dest))
        (user-error "Aborted")))
    (write-region content nil dest)
    (message "LICENSE (%s) written to %s" name dest)))

(provide 'nn-license-template)
;;; nn-license-template.el ends here
