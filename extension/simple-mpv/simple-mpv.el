;;; simple-mpv.el --- Simple mpv media player  -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'json)

(defvar simple-mpv--ipc-seq 0)
(defvar simple-mpv--process nil)
(defvar simple-mpv--bridge nil)
(defvar simple-mpv--bridge-buffer nil)
(defvar simple-mpv--bridge-events nil)
(defvar simple-mpv--audio-control-play-flag nil)
(defvar simple-mpv--audio-list nil)
(defvar simple-mpv--audio-list-buffer nil)
(defvar simple-mpv--audio-control-buffer nil)
(defvar simple-mpv--audio-control-timer nil)
(defvar simple-mpv--audio-control-tick-count 0)
(defconst simple-mpv--audio-control-initial-state
  '((title . "")
    (author . "")
    (time-pos . 0)
    (duration . 0)))
(defvar simple-mpv--audio-control-state
  (copy-tree simple-mpv--audio-control-initial-state))

(defvar-keymap simple-mpv--audio-list-map
  "q" #'delete-window
  "<return>" #'simple-mpv--audio-list-buffer-play)

(defgroup simple-mpv nil
  "Simple external mpv media player."
  :group 'multimedia
  :prefix "simple-mpv-")

(defcustom simple-mpv-audio-progress-filled-char ?█
  "Character used for the filled portion of the audio progress bar."
  :type 'character
  :group 'simple-mpv)

(defcustom simple-mpv-audio-progress-empty-char ?░
  "Character used for the remaining portion of the audio progress bar."
  :type 'character
  :group 'simple-mpv)

(defcustom simple-mpv-audio-progress-width 20
  "Number of cells used by the audio progress bar."
  :type 'natnum
  :group 'simple-mpv)

(defcustom simple-mpv-debug t
  "Show mpv process buffer."
  :type 'boolean
  :group 'simple-mpv)

(defcustom simple-mpv-exe "mpv"
  "Path to the mpv executable."
  :type 'file
  :group 'simple-mpv)

(defcustom simple-mpv-call-extra-args
  '("--autofit=50%" "--no-terminal" "--keep-open=yes")
  "Extra command line arguments passed to mpv process."
  :type '(repeat string)
  :group 'simple-mpv)

(defcustom simple-mpv-audio-directory "~/Music"
  "Directory where audio files are stored."
  :type 'directory
  :group 'simple-mpv)

(defcustom simple-mpv-audio-ext-rg
  "\\.\\(mp3\\|wav\\|m4a\\|m4s\\|flac\\|aac\\|ogg\\|wma\\)$"
  "Regular expression matching audio file extensions."
  :type 'string
  :group 'simple-mpv)

(defcustom simple-mpv-audio-bridge-script
  (expand-file-name
   "simple-mpv-bridge.ps1"
   (file-name-directory load-file-name))
  "Path to the PowerShell bridge script for simple-mpv IPC."
  :type 'file
  :group 'simple-mpv)

(defun simple-mpv--ipc-begin ()
  (setq simple-mpv--process
        (apply
         #'make-process
         :coding '(utf-8-dos . gbk-dos)
         :name "simple-mpv-process"
         :command `(,simple-mpv-exe
                    "--pause" "--loop-playlist"
                    ,@(unless simple-mpv-debug '("--no-terminal"))
                    "--input-ipc-server=simple-mpv"
                    ,@simple-mpv--audio-list)
         (when simple-mpv-debug
           '(:buffer "*Simple mpv process*"))))
  (setq simple-mpv--bridge
        (make-process
         :coding 'utf-8-emacs-unix
         :name "simple-mpv-bridge"
         :command `("powershell" "-File" ,simple-mpv-audio-bridge-script)
         :filter #'simple-mpv--ipc-filter)))

(defun simple-mpv--ipc-end ()
  (when simple-mpv--process
    (when simple-mpv-debug
      (kill-buffer (process-buffer simple-mpv--process)))
    (delete-process simple-mpv--process)
    (setq simple-mpv--process nil))
  (when simple-mpv--bridge
    (delete-process simple-mpv--bridge)
    (setq simple-mpv--bridge nil)))

(defun simple-mpv--ipc-post (parsed)
  (let* ((req-id (cdr (assq 'request_id parsed)))
         (callback (cdr (assq req-id simple-mpv--bridge-events))))
    (when (and callback
               (string= (cdr (assq 'error parsed)) "success"))
      (funcall callback (cdr (assq 'data parsed))))
    (setq simple-mpv--bridge-events
          (assq-delete-all req-id simple-mpv--bridge-events))))

(defun simple-mpv--ipc-filter (_proc output)
  (setq simple-mpv--bridge-buffer (concat simple-mpv--bridge-buffer output))
  (while-let ((pos (string-search "\n" simple-mpv--bridge-buffer)))
    (let ((line (substring simple-mpv--bridge-buffer 0 pos)))
      (setq simple-mpv--bridge-buffer
            (substring simple-mpv--bridge-buffer (1+ pos)))
      (let ((parsed (json-read-from-string line)))
        (if (assq 'event parsed)
            (when (string= (cdr (assq 'event parsed)) "property-change")
              (simple-mpv--audio-control-property-change
               (cdr (assq 'name parsed))
               (cdr (assq 'data parsed))))
          (simple-mpv--ipc-post parsed))))))

(defun simple-mpv--ipc-dispatch (callback &rest args)
  (if (process-live-p simple-mpv--bridge)
      (let ((id (cl-incf simple-mpv--ipc-seq)))
        (when callback
          (push (cons id callback) simple-mpv--bridge-events))
        (process-send-string
         simple-mpv--bridge
         (concat
          (json-encode
           `((command . ,(vconcat args))
             (request_id . ,id)))
          "\n")))
    (message "simple-mpv: bridge process is not running")))

(defun simple-mpv--cleanup ()
  (simple-mpv--ipc-end)
  (when (timerp simple-mpv--audio-control-timer)
    (cancel-timer simple-mpv--audio-control-timer))
  (setq simple-mpv--audio-control-timer nil
        simple-mpv--audio-control-tick-count 0
        simple-mpv--audio-list-buffer nil
        simple-mpv--audio-control-play-flag nil
        simple-mpv--bridge-buffer nil
        simple-mpv--bridge-events nil
        simple-mpv--ipc-seq 0
        simple-mpv--audio-control-state
        (copy-tree simple-mpv--audio-control-initial-state))
  (when (buffer-live-p simple-mpv--audio-control-buffer)
    (when-let* ((win (get-buffer-window simple-mpv--audio-control-buffer t)))
      (delete-window win))
    (kill-buffer simple-mpv--audio-control-buffer)
    (setq simple-mpv--audio-control-buffer nil)))

(defun simple-mpv--audio-list-buffer-render ()
  (with-current-buffer simple-mpv--audio-list-buffer
    (erase-buffer)
    (add-hook 'kill-buffer-hook #'simple-mpv--cleanup nil t)
    (setq tabulated-list-format
          [("Idx" 4 t)
           ("Name" 40 t)
           ("Tag" 0 t)])
    (setq tabulated-list-entries
          (cl-loop for f in simple-mpv--audio-list
                   for i from 1
                   collect
                   `(,f
                     ,(vector
                       (number-to-string i)
                       (file-name-nondirectory
                        (file-name-sans-extension f))
                       (file-name-nondirectory
                        (directory-file-name
                         (file-name-directory f)))))))
    (tabulated-list-init-header)
    (tabulated-list-print)
    (use-local-map simple-mpv--audio-list-map)
    (read-only-mode 1)))

(defun simple-mpv--audio-list-buffer-play ()
  (interactive)
  (let* ((file (tabulated-list-get-id))
         (index (cl-position file simple-mpv--audio-list :test #'equal)))
    (if (null index)
        (user-error "No audio track selected")
      (let ((id 1))
        (dolist (property '("metadata" "pause"))
          (simple-mpv--ipc-dispatch nil "observe_property" (number-to-string id) property)
          (cl-incf id)))
      (simple-mpv--audio-control-ensure)
      (setq simple-mpv--audio-control-tick-count 0)
      (setf (alist-get 'title simple-mpv--audio-control-state)
            (simple-mpv--audio-control-clean-title file)
            (alist-get 'author simple-mpv--audio-control-state) ""
            (alist-get 'time-pos simple-mpv--audio-control-state) 0
            (alist-get 'duration simple-mpv--audio-control-state) 0)
      (simple-mpv--audio-control-render)
      (simple-mpv--ipc-dispatch
       (lambda (_value)
         (simple-mpv--ipc-dispatch nil "set_property" "pause" "no")
         (setq simple-mpv--audio-control-play-flag t)
         (simple-mpv--audio-control-refresh))
       "playlist-play-index" index))))

(defun simple-mpv--audio-control-request-property (property)
  "Request PROPERTY and update the audio control when it arrives."
  (simple-mpv--ipc-dispatch
   (lambda (value)
     (simple-mpv--audio-control-property-change property value))
   "get_property" property))

(defun simple-mpv--audio-control-clean-title (title)
  (let* ((title (or title "Unknown"))
         (title (file-name-nondirectory title))
         (title (car (split-string title "\\?" t)))
         (title (file-name-sans-extension title)))
    (if (string-empty-p title) "Unknown" title)))

(defun simple-mpv--audio-control-format-time (seconds)
  "Format SECONDS as a compact playback timestamp."
  (if (>= seconds 3600)
      (format "%d:%02d:%02d"
              (/ seconds 3600)
              (/ (% seconds 3600) 60)
              (% seconds 60))
    (format "%02d:%02d" (/ seconds 60) (% seconds 60))))

(defun simple-mpv--audio-control-property-change (prop value)
  (pcase prop
    ("media-title"
     (when (and (stringp value) (not (string-empty-p value)))
       (simple-mpv--audio-control-state-update
        'title (simple-mpv--audio-control-clean-title value))))
    ("metadata"
     (let ((author "")
           title
           author-seen
           title-seen)
       (dolist (entry (and (listp value) value))
         (when-let* ((name (car-safe entry)))
           (let ((name (downcase (if (symbolp name) (symbol-name name) name))))
             (cond
              ((and (not author-seen) (string= name "author"))
               (setq author (cdr entry)
                     author-seen t))
              ((and (not title-seen) (string= name "title"))
               (setq title (cdr entry)
                     title-seen t))))))
       (setf (alist-get 'author simple-mpv--audio-control-state)
             (or author ""))
       (when (and title-seen
                  (stringp title)
                  (not (string-empty-p title)))
         (setf (alist-get 'title simple-mpv--audio-control-state)
               (simple-mpv--audio-control-clean-title title)))
       (simple-mpv--audio-control-render)))
    ("time-pos"
     (simple-mpv--audio-control-state-update 'time-pos (or value 0)))
    ("duration"
     (simple-mpv--audio-control-state-update 'duration (or value 0)))
    ("pause"
     (setq simple-mpv--audio-control-play-flag (eq value :json-false))
     (simple-mpv--audio-control-render))))

(defun simple-mpv--audio-control-state-update (key value)
  (unless (equal (alist-get key simple-mpv--audio-control-state) value)
    (setf (alist-get key simple-mpv--audio-control-state) value)
    (simple-mpv--audio-control-render)))

(defun simple-mpv--audio-control-button (text help command height)
  (propertize
   text
   'face `(:height ,height)
   'mouse-face 'highlight
   'help-echo help
   'keymap (let ((map (make-sparse-keymap)))
             (keymap-set map "<mouse-1>" command)
             map)
   'rear-nonsticky '(keymap mouse-face help-echo face)))

(defun simple-mpv--audio-control-progress-fit (progress width)
  (if (<= (string-width progress) width)
      progress
    (let* ((source-cells (max 1 (string-width progress)))
           (cells (max 1 width))
           (filled (cl-count simple-mpv-audio-progress-filled-char progress))
           (scaled-filled
            (min cells (floor (* cells (/ (float filled) source-cells))))))
      (concat
       (make-string scaled-filled simple-mpv-audio-progress-filled-char)
       (make-string (- cells scaled-filled)
                    simple-mpv-audio-progress-empty-char)))))

(defun simple-mpv--audio-control-refresh ()
  (simple-mpv--audio-control-request-property "media-title")
  (simple-mpv--ipc-dispatch
   (lambda (value)
     (simple-mpv--audio-control-property-change "metadata" value))
   "get_property" "metadata")
  (simple-mpv--ipc-dispatch
   (lambda (value)
     (when (and (stringp value) (not (string-empty-p value)))
       (setf (alist-get 'author simple-mpv--audio-control-state) value)
       (simple-mpv--audio-control-render)))
   "get_property" "metadata/author")
  (simple-mpv--audio-control-request-property "time-pos")
  (simple-mpv--audio-control-request-property "duration"))

(defun simple-mpv--audio-control-tick ()
  "Poll mpv for position, title, and duration while the control is visible."
  (cond
   ((not (and (buffer-live-p simple-mpv--audio-control-buffer)
              (process-live-p simple-mpv--bridge)))
    (when (timerp simple-mpv--audio-control-timer)
      (cancel-timer simple-mpv--audio-control-timer))
    (setq simple-mpv--audio-control-timer nil))
   (t
    (simple-mpv--audio-control-request-property "time-pos")
    (setq simple-mpv--audio-control-tick-count
          (1+ simple-mpv--audio-control-tick-count))
    (when (>= simple-mpv--audio-control-tick-count 4)
      (setq simple-mpv--audio-control-tick-count 0)
      (dolist (property '("media-title" "duration"))
        (simple-mpv--audio-control-request-property property))))))

(defun simple-mpv--audio-control-ensure ()
  (unless (buffer-live-p simple-mpv--audio-control-buffer)
    (setq simple-mpv--audio-control-buffer
          (get-buffer-create "*Simple mpv audio control*"))
    (with-current-buffer simple-mpv--audio-control-buffer
      (setq-local truncate-lines t
                  cursor-type nil
                  mode-line-format nil
                  header-line-format nil)))
  (unless (get-buffer-window simple-mpv--audio-control-buffer)
    (let ((win (display-buffer-in-side-window
                simple-mpv--audio-control-buffer
                '((side . bottom) (slot . 0)))))
      (set-window-text-height win 1)
      (set-window-parameter win 'no-other-window t)
      (set-window-parameter win 'no-delete-other-windows t)
      (set-window-dedicated-p win t)
      (window-preserve-size win t t)))
  (unless (timerp simple-mpv--audio-control-timer)
    (setq simple-mpv--audio-control-timer
          (run-at-time 0.25 0.25 #'simple-mpv--audio-control-tick))))

(defun simple-mpv--audio-control-align-space (column)
  "Return a non-interactive space aligned to COLUMN display cells."
  (propertize
   " "
   'display `(space :align-to ,column)
   'keymap nil
   'mouse-face nil
   'help-echo nil))

(defun simple-mpv--audio-control-render-line-content (description progress time width)
  (let* ((button-items
          `(,(simple-mpv--audio-control-button
              "🙏" "Random play" #'simple-mpv--audio-control-random 1.2)
            ,(simple-mpv--audio-control-button
              "👈" "Previous track" #'simple-mpv--audio-control-last 1.2)
            ,(simple-mpv--audio-control-button
              (if simple-mpv--audio-control-play-flag "👌" "✋")
              "Play or pause" #'simple-mpv--audio-control-auto-play 1.6)
            ,(simple-mpv--audio-control-button
              "👉" "Next track" #'simple-mpv--audio-control-next 1.2)
            ,(simple-mpv--audio-control-button
              "🤏" "Toggle loop" #'simple-mpv--audio-control-loop 1.2)))
         (right-full (concat progress " " time))
         (progress-width (- width (string-width time) 1))
         (right
          (cond
           ((>= width (string-width right-full))
            right-full)
           ((> progress-width 0)
            (concat
             (simple-mpv--audio-control-progress-fit progress progress-width)
             " " time))
           ((>= width (string-width time))
            time)
           (t
            (simple-mpv--audio-control-progress-fit progress width))))
         (right-width (string-width right))
         (buttons-with-gap (mapconcat #'identity button-items " "))
         (buttons-compact (mapconcat #'identity button-items ""))
         (buttons
          (cond
           ((>= width (+ (string-width buttons-with-gap)
                         right-width 2))
            buttons-with-gap)
           ((>= width (+ (string-width buttons-compact)
                         right-width))
            buttons-compact)
           (t "")))
         (buttons-width (string-width buttons)))
    (let* ((button-column
            (max 0
                 (min (truncate (/ (- width buttons-width) 2))
                      (- width right-width buttons-width 1))))
           (description-width-limit
            (min (truncate (* width 0.40))
                 (max 0 (1- button-column))))
           (description
            (if (> description-width-limit 0)
                (truncate-string-to-width
                 description description-width-limit 0 nil t)
              "")))
      (concat
       description
       (simple-mpv--audio-control-align-space button-column)
       buttons
       (simple-mpv--audio-control-align-space (- width right-width))
       right))))

(defun simple-mpv--audio-control-render-line (description progress time)
  (when (buffer-live-p simple-mpv--audio-control-buffer)
    (with-current-buffer simple-mpv--audio-control-buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert
         (simple-mpv--audio-control-render-line-content
          description progress time
          (window-body-width (get-buffer-window simple-mpv--audio-control-buffer t))))
        (put-text-property (point-min) (point-max) 'pointer 'arrow)))))

(defun simple-mpv--audio-control-render ()
  (when (buffer-live-p simple-mpv--audio-control-buffer)
    (let* ((position
            (truncate
             (or (alist-get 'time-pos simple-mpv--audio-control-state) 0)))
           (duration
            (truncate
             (or (alist-get 'duration simple-mpv--audio-control-state) 0))))
      (simple-mpv--audio-control-render-line
       (format "%s - %s"
               (or (alist-get 'title simple-mpv--audio-control-state) "Unknown")
               (let ((author (alist-get 'author simple-mpv--audio-control-state)))
                 (if (and (stringp author) (not (string-empty-p author)))
                     author
                   "Unknown")))
       (let* ((inner (max 1 simple-mpv-audio-progress-width))
              (filled
               (min inner
                    (floor
                     (* (if (> duration 0)
                            (min 1.0 (max 0.0 (/ (float position) duration)))
                          0.0)
                        inner)))))
         (concat
          (make-string filled simple-mpv-audio-progress-filled-char)
          (make-string (- inner filled)
                       simple-mpv-audio-progress-empty-char)))
       (concat
        (simple-mpv--audio-control-button
         (simple-mpv--audio-control-format-time position)
         "Seek to a position in the current track"
         #'simple-mpv--audio-control-seek
         1.0)
        "/"
        (simple-mpv--audio-control-format-time duration))))))

(defun simple-mpv--audio-control-auto-play ()
  (interactive)
  (simple-mpv--ipc-dispatch
   nil "set_property" "pause"
   (if simple-mpv--audio-control-play-flag "yes" "no"))
  (setq simple-mpv--audio-control-play-flag (not simple-mpv--audio-control-play-flag))
  (simple-mpv--audio-control-render))

(defun simple-mpv--audio-control-playlist-step (command)
  (simple-mpv--ipc-dispatch
   (lambda (_value)
     (simple-mpv--ipc-dispatch nil "set_property" "pause" "no")
     (setq simple-mpv--audio-control-play-flag t)
     (simple-mpv--audio-control-refresh))
   command "force"))

(defun simple-mpv--audio-control-last ()
  (interactive)
  (simple-mpv--audio-control-playlist-step "playlist-prev")
  (message "Playing previous track"))

(defun simple-mpv--audio-control-next ()
  (interactive)
  (simple-mpv--audio-control-playlist-step "playlist-next")
  (message "Playing next track"))

(defun simple-mpv--audio-control-random ()
  (interactive)
  (simple-mpv--ipc-dispatch nil "playlist-shuffle")
  (simple-mpv--ipc-dispatch nil "playlist-play-index" 0)
  (message "Playlist shuffled, playing from first track"))

(defun simple-mpv--audio-control-loop ()
  (interactive)
  (simple-mpv--ipc-dispatch nil "cycle-values" "loop" "inf" "no")
  (message "Loop mode toggled"))

(defun simple-mpv--audio-control-seek ()
  "Prompt for an absolute position and seek the current track there."
  (interactive)
  (let ((target (read-string "Seek to (mm:ss or seconds): ")))
    (unless (string-empty-p target)
      (simple-mpv--ipc-dispatch nil "seek" target "absolute"))))

;;;###autoload
(defun simple-mpv-play-file (file)
  (interactive "fPlay with mpv: ")
  (apply #'start-process
         "simple-mpv-call" "*simple-mpv-call*"
         simple-mpv-exe
         (cons file simple-mpv-call-extra-args)))

;;;###autoload
(defun simple-mpv-audio-browse ()
  (interactive)
  (unless (buffer-live-p simple-mpv--audio-list-buffer)
    (setq simple-mpv--audio-list
          (mapcar #'expand-file-name
                  (directory-files-recursively
                   simple-mpv-audio-directory
                   simple-mpv-audio-ext-rg
                   nil nil 1)))
    (setq simple-mpv--audio-list-buffer
          (get-buffer-create "*Simple mpv audio list*"))
    (simple-mpv--audio-list-buffer-render)
    (simple-mpv--ipc-begin))
  (switch-to-buffer-other-window simple-mpv--audio-list-buffer))

(provide 'simple-mpv)
;;; simple-mpv.el ends here
