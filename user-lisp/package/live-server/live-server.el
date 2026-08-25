;;; live-server.el --- Emacs frontend for the Python Live Server  -*- lexical-binding: t; -*-
(defconst live-server--script
  (expand-file-name "live-server.py" (file-name-directory load-file-name)))
(defvar live-server--process nil)
(defvar live-server--buffer "*Live Server*")

(defgroup live-server nil
  "Control the cross-platform Python Live Server."
  :group 'tools
  :prefix "live-server-")

(defcustom live-server-python "python"
  "Python executable used by Live Server."
  :type 'file :group 'live-server)

(defcustom live-server-port 5500
  "HTTP port."
  :type 'natnum
  :group 'live-server)

(defcustom live-server-host "127.0.0.1"
  "Listen address."
  :type 'string
  :group 'live-server)

(defcustom live-server-root default-directory
  "Directory to serve."
  :type 'directory
  :group 'live-server)

(defun live-server--log (_process output)
  (with-current-buffer (get-buffer-create live-server--buffer)
    (goto-char (point-max))
    (insert output)))

(defun live-server--stopped (_process _event)
  (setq live-server--process nil))

(defun live-server--buffer-killed ()
  (when (process-live-p live-server--process)
    (live-server-stop)))

;;;###autoload
(defun live-server-start (&optional directory)
  "Start the Python server for DIRECTORY."
  (interactive `(,(read-directory-name "Serve directory: " live-server-root nil t)))
  (live-server-stop)
  (setq live-server-root (file-name-as-directory (expand-file-name (or directory live-server-root))))
  (setq live-server--process
        (make-process
         :name "live-server"
         :command `(,live-server-python
                    ,live-server--script
                    "--root" ,live-server-root
                    "--host" ,live-server-host
                    "--port" ,(number-to-string live-server-port))
         :buffer nil
         :filter #'live-server--log
         :sentinel #'live-server--stopped
         :noquery t))
  (with-current-buffer (get-buffer-create live-server--buffer)
    (add-hook 'kill-buffer-hook #'live-server--buffer-killed nil t)
    (erase-buffer))
  (display-buffer live-server--buffer))

;;;###autoload
(defun live-server-stop ()
  "Stop the Python Live Server."
  (interactive)
  (when (process-live-p live-server--process)
    (delete-process live-server--process))
  (setq live-server--process nil))

(provide 'live-server)
;;; live-server.el ends here
