;;; -*- lexical-binding: t -*-
(require 'cl-lib)
(require 'json)

(defvar simple-mpv--ipc-seq 0)
(defvar simple-mpv--observe-seq 0)
(defvar simple-mpv--process nil)
(defvar simple-mpv--bridge nil)
(defvar simple-mpv--bridge-buffer nil)
(defvar simple-mpv--bridge-events nil)
(defvar simple-mpv--bridge-timeout 30
  "Seconds after which a pending IPC request is considered abandoned.")
(defvar simple-mpv--audio-list nil
  "Flat, ordered list of absolute paths to all audio files.")
(defvar simple-mpv--current-index nil
  "Index into `simple-mpv--audio-list' of the current track, or nil.")
(defvar simple-mpv--audio-list-buffer nil)
(defvar simple-mpv--audio-control-buffer nil)
(defvar simple-mpv--audio-control-play-flag nil
  "Non-nil when mpv is currently playing (pause == false).")
(defvar simple-mpv--render-timer nil
  "Pending timer used to coalesce frequent redraws.")
(defvar simple-mpv--button-keymap-cache nil
  "Alist of (COMMAND . KEYMAP) used by audio control buttons.")
(defconst simple-mpv--audio-control-initial-state
  '((title    . "")
    (author   . "")
    (time-pos . 0)
    (duration . 0)))
(defvar simple-mpv--audio-control-state
  (copy-tree simple-mpv--audio-control-initial-state))
(defvar-keymap simple-mpv--audio-list-map
  "q"        #'delete-window
  "<return>" #'simple-mpv--audio-list-buffer-play)



(defgroup simple-mpv nil
  "Simple external mpv media player."
  :prefix "simple-mpv-"
  :group 'multimedia)

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
  "Extra command line arguments passed to the one-off mpv process."
  :type '(repeat string)
  :group 'simple-mpv)

(defcustom simple-mpv-audio-directory "~/Music"
  "Directory where audio files are stored."
  :type 'directory
  :group 'simple-mpv)

(defcustom simple-mpv-audio-ext-rg
  "\\.\\(mp3\\|wav\\|m4a\\|flac\\|aac\\|ogg\\|wma\\)$"
  "Regular expression matching audio file extensions.
`.m4s' is intentionally excluded, since it is a DASH fragment
that needs its accompanying init segment to decode correctly."
  :type 'string
  :group 'simple-mpv)

(defcustom simple-mpv-audio-bridge-script
  (expand-file-name
   "simple-mpv-bridge.ps1"
   (file-name-directory load-file-name))
  "Path to the PowerShell bridge script for simple-mpv IPC."
  :type 'file
  :group 'simple-mpv)


;;; IPC plumbing

(defun simple-mpv--ipc-begin ()
  "Start mpv in idle mode and connect the PowerShell IPC bridge."
  (setq simple-mpv--observe-seq 0
        simple-mpv--current-index nil
        simple-mpv--process
        (apply #'make-process
               (append
                (list :coding '(utf-8-dos . gbk-dos)
                      :name "simple-mpv-process"
                      :command
                      (append
                       (list simple-mpv-exe
                             "--idle=yes"
                             "--no-video")
                       (unless simple-mpv-debug '("--no-terminal"))
                       (list "--input-ipc-server=simple-mpv")))
                (when simple-mpv-debug
                  (list :buffer "*Simple mpv process*"))))
        simple-mpv--bridge
        (make-process
         :coding 'utf-8-emacs-unix
         :name "simple-mpv-bridge"
         :command `("powershell" "-File" ,simple-mpv-audio-bridge-script)
         :filter #'simple-mpv--ipc-filter))
  (cl-loop for prop in '("metadata" "pause" "media-title" "duration" "time-pos")
           do (simple-mpv--ipc-dispatch
               nil "observe_property" (cl-incf simple-mpv--observe-seq) prop)))

(defun simple-mpv--ipc-end ()
  "Kill mpv and the IPC bridge."
  (when simple-mpv--process
    (when-let* ((buf (process-buffer simple-mpv--process)))
      (when (buffer-live-p buf)
        (kill-buffer buf)))
    (delete-process simple-mpv--process)
    (setq simple-mpv--process nil))
  (when simple-mpv--bridge
    (delete-process simple-mpv--bridge)
    (setq simple-mpv--bridge nil)))

(defun simple-mpv--ipc-sweep-stale ()
  "Drop callbacks whose responses never arrived within the timeout."
  (let ((cutoff (- (float-time) simple-mpv--bridge-timeout)))
    (setq simple-mpv--bridge-events
          (cl-remove-if (lambda (entry) (< (cddr entry) cutoff))
                        simple-mpv--bridge-events))))

(defun simple-mpv--ipc-dispatch (callback &rest args)
  "Send a JSON-RPC command to mpv via the bridge.
CALLBACK is called with the `data' field of the response on success."
  (if (process-live-p simple-mpv--bridge)
      (let ((id (cl-incf simple-mpv--ipc-seq)))
        (when callback
          ;; FIX: store a timestamp so we can sweep abandoned requests.
          (push (cons id (cons callback (float-time)))
                simple-mpv--bridge-events))
        ;; OPT: opportunistically drop stale pending requests.
        (simple-mpv--ipc-sweep-stale)
        (process-send-string
         simple-mpv--bridge
         (concat
          (json-encode
           `((command . ,(vconcat args))
             (request_id . ,id)))
          "\n")))
    (message "simple-mpv: bridge process is not running")))

(defun simple-mpv--ipc-post (parsed)
  "Dispatch a response message to its registered callback."
  (let* ((req-id  (cdr (assq 'request_id parsed)))
         (entry   (assq req-id simple-mpv--bridge-events)))
    (when entry
      (let ((callback (cadr entry))
            (err      (cdr (assq 'error parsed))))
        (when (equal err "success")
          (funcall callback (cdr (assq 'data parsed)))))
      (setq simple-mpv--bridge-events
            (assq-delete-all req-id simple-mpv--bridge-events)))))

(defun simple-mpv--ipc-filter (_proc output)
  "Parse newline-delimited JSON from mpv and route each message."
  (setq simple-mpv--bridge-buffer
        (concat simple-mpv--bridge-buffer output))
  (while (string-match "\n" simple-mpv--bridge-buffer)
    (let* ((pos  (match-beginning 0))
           (line (substring simple-mpv--bridge-buffer 0 pos)))
      (setq simple-mpv--bridge-buffer
            (substring simple-mpv--bridge-buffer (1+ pos)))
      (unless (string-empty-p (string-trim line))
        (condition-case err
            (let ((parsed (json-read-from-string line)))
              (if (assq 'event parsed)
                  (simple-mpv--handle-event parsed)
                (simple-mpv--ipc-post parsed)))
          (error
           (message "simple-mpv: bad IPC line (%S): %s" err line)))))))

(defun simple-mpv--cleanup ()
  "Tear down all simple-mpv state.  Runs on the list buffer's kill hook."
  (simple-mpv--ipc-end)
  (when (buffer-live-p simple-mpv--audio-control-buffer)
    (when-let* ((win (get-buffer-window simple-mpv--audio-control-buffer t)))
      (delete-window win))
    (kill-buffer simple-mpv--audio-control-buffer))
  (when (timerp simple-mpv--render-timer)
    (cancel-timer simple-mpv--render-timer))
  (setq simple-mpv--audio-list-buffer nil
        simple-mpv--audio-control-buffer nil
        simple-mpv--current-index nil
        simple-mpv--audio-control-play-flag nil
        simple-mpv--bridge-buffer nil
        simple-mpv--bridge-events nil
        simple-mpv--ipc-seq 0
        simple-mpv--observe-seq 0
        simple-mpv--render-timer nil
        simple-mpv--audio-control-state
        (copy-tree simple-mpv--audio-control-initial-state)))


;;; Playback controls

(defun simple-mpv--audio-control-auto-play ()
  "Toggle play / pause."
  (interactive)
  (simple-mpv--ipc-dispatch
   nil "set_property" "pause"
   (if simple-mpv--audio-control-play-flag "yes" "no")))

(defun simple-mpv--play-relative (delta)
  "Play the track DELTA positions away from the current one (wrapping)."
  (when simple-mpv--current-index
    (let* ((len  (length simple-mpv--audio-list))
           (next (mod (+ simple-mpv--current-index delta) len)))
      (simple-mpv--play-index next))))

(defun simple-mpv--audio-control-last ()
  "Play the previous track."
  (interactive)
  (simple-mpv--play-relative -1))

(defun simple-mpv--audio-control-next ()
  "Play the next track."
  (interactive)
  (simple-mpv--play-relative +1))

(defun simple-mpv--audio-control-random ()
  "Play a random track from the list."
  (interactive)
  (let ((len (length simple-mpv--audio-list)))
    (when (> len 0)
      (simple-mpv--play-index (random len)))))

(defun simple-mpv--audio-control-loop ()
  "Toggle single-track looping."
  (interactive)
  (simple-mpv--ipc-dispatch nil "cycle-values" "loop-file" "inf" "no")
  (message "Track loop toggled"))

(defun simple-mpv--audio-control-seek ()
  "Prompt for a position and seek there absolutely."
  (interactive)
  (let ((target (read-string "Seek to (mm:ss or seconds): ")))
    (unless (string-empty-p target)
      (simple-mpv--ipc-dispatch nil "seek" target "absolute"))))


;;; Control-bar state & rendering

(defun simple-mpv--audio-control-state-update (key value &optional soon)
  "Set KEY to VALUE in the control state, redrawing if it changed.
When SOON is non-nil, the redraw is coalesced via a short timer."
  (unless (equal (alist-get key simple-mpv--audio-control-state) value)
    (setf (alist-get key simple-mpv--audio-control-state) value)
    (if soon
        (simple-mpv--audio-control-render-soon)
      (simple-mpv--audio-control-render))))

(defun simple-mpv--audio-control-metadata-lookup (value key)
  (cdr
   (cl-find-if
    (lambda (entry)
      (let ((name (car-safe entry)))
        (and name
             (string=
              (downcase
               (if (symbolp name)
                   (symbol-name name)
                 name))
              key))))
    value)))

(defun simple-mpv--audio-control-property-change (prop value)
  "Update control-bar state in response to a mpv property change."
  (pcase prop
    ("media-title"
     (when (and (stringp value) (not (string-empty-p value)))
       (simple-mpv--audio-control-state-update
        'title (file-name-sans-extension value))))
    ("metadata"
     (let ((author (or (simple-mpv--audio-control-metadata-lookup value "author")
                       (simple-mpv--audio-control-metadata-lookup value "artist"))))
       (when (and (stringp author) (not (string-empty-p author)))
         (simple-mpv--audio-control-state-update 'author author))))
    ("time-pos"
     (simple-mpv--audio-control-state-update 'time-pos (or value 0) 'soon))
    ("duration"
     (simple-mpv--audio-control-state-update 'duration (or value 0) 'soon))
    ("pause"
     (setq simple-mpv--audio-control-play-flag (eq value :json-false))
     (simple-mpv--audio-control-render))))

(defun simple-mpv--audio-control-ensure ()
  "Make sure the control buffer, its window, and its timer exist."
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
      (set-window-text-height win 2)
      (set-window-parameter win 'no-other-window        t)
      (set-window-parameter win 'no-delete-other-windows t)
      (set-window-dedicated-p win t)
      (window-preserve-size win t t))))

(defun simple-mpv--audio-control-format-time (seconds)
  "Format SECONDS as a compact `mm:ss' or `h:mm:ss' timestamp."
  (if (>= seconds 3600)
      (format "%d:%02d:%02d"
              (/ seconds 3600)
              (/ (% seconds 3600) 60)
              (% seconds 60))
    (format "%02d:%02d" (/ seconds 60) (% seconds 60))))

(defun simple-mpv--audio-control-button-keymap (command)
  "Return a cached keymap binding <down-mouse-1> to COMMAND."
  (or (cdr (assq command simple-mpv--button-keymap-cache))
      (let ((map (make-sparse-keymap)))
        (keymap-set map "<down-mouse-1>" command)
        (push (cons command map) simple-mpv--button-keymap-cache)
        map)))

(defun simple-mpv--audio-control-button (text help command height)
  (propertize
   text
   'face `(:height ,height)
   'mouse-face 'highlight
   'help-echo help
   'pointer 'hand
   'keymap (simple-mpv--audio-control-button-keymap command)))

(defun simple-mpv--audio-control-render-soon ()
  "Request a redraw, merging multiple requests within ~150ms."
  (unless (timerp simple-mpv--render-timer)
    (setq simple-mpv--render-timer
          (run-with-timer
           0.15 nil
           (lambda ()
             (setq simple-mpv--render-timer nil)
             (when (buffer-live-p simple-mpv--audio-control-buffer)
               (simple-mpv--audio-control-render)))))))

(defun simple-mpv--audio-control-render ()
  "Redraw the control bar."
  (when (buffer-live-p simple-mpv--audio-control-buffer)
    (with-current-buffer simple-mpv--audio-control-buffer
      (setq tabulated-list-format
            [("Track"    50 nil)
             ("Controls" 40 nil)
             ("Progress" 20 nil)
             ("Time"     10 nil)])
      (let* ((s simple-mpv--audio-control-state)
             (pos (truncate (or (alist-get 'time-pos s) 0)))
             (dur (truncate (or (alist-get 'duration s) 0)))
             (n simple-mpv-audio-progress-width)
             (k (floor (* n (if (> dur 0) (/ (float pos) dur) 0)))))
        (setq tabulated-list-entries
              `((nil
                 ,(vector
                   (format
                    "%s - %s"
                    (alist-get 'title  s)
                    (alist-get 'author s))
                   (mapconcat
                    (lambda (spec)
                      (apply #'simple-mpv--audio-control-button spec))
                    `(("🙏" "Random" simple-mpv--audio-control-random 1.3)
                      ("👈" "Prev" simple-mpv--audio-control-last 1.3)
                      (,(if simple-mpv--audio-control-play-flag "👌" "✋")
                       "Play" simple-mpv--audio-control-auto-play 1.6)
                      ("👉" "Next" simple-mpv--audio-control-next 1.3)
                      ("🤏" "Loop" simple-mpv--audio-control-loop 1.3))
                    " ")
                   (concat (make-string k simple-mpv-audio-progress-filled-char)
                           (make-string (- n k) simple-mpv-audio-progress-empty-char))
                   (concat (simple-mpv--audio-control-button
                            (simple-mpv--audio-control-format-time pos)
                            "Seek" #'simple-mpv--audio-control-seek 1.0)
                           "/"
                           (simple-mpv--audio-control-format-time dur)))))))
      (tabulated-list-print t))))


;;; Events

(defun simple-mpv--handle-end-file (parsed)
  "Advance to the next track when the current one reaches EOF."
  (when (string= (or (cdr (assq 'reason parsed)) "") "eof")
    (when (and simple-mpv--current-index
               (> (length simple-mpv--audio-list) 1))
      (simple-mpv--play-relative +1))))

(defun simple-mpv--handle-event (parsed)
  "Route a mpv event to the appropriate handler."
  (pcase (cdr (assq 'event parsed))
    ("property-change"
     (simple-mpv--audio-control-property-change
      (cdr (assq 'name parsed))
      (cdr (assq 'data parsed))))
    ("end-file"
     (simple-mpv--handle-end-file parsed))))

(defun simple-mpv--play-index (index)
  "Load `simple-mpv--audio-list' entry at INDEX into mpv and play it."
  (let ((file (nth index simple-mpv--audio-list)))
    (unless file
      (user-error "No audio track at index %s" index))
    (setf (alist-get 'title simple-mpv--audio-control-state) "Unknown"
          (alist-get 'author simple-mpv--audio-control-state) "Unknown"
          (alist-get 'time-pos simple-mpv--audio-control-state) 0
          (alist-get 'duration simple-mpv--audio-control-state) 0)
    (setq simple-mpv--current-index index)
    (simple-mpv--audio-control-ensure)
    (simple-mpv--audio-control-render)
    (simple-mpv--ipc-dispatch
     (lambda (_)
       ;; Only unpause once the file has actually been loaded.
       (simple-mpv--ipc-dispatch nil "set_property" "pause" "no")
       (simple-mpv--audio-control-refresh))
     "loadfile" file "replace")))

(defun simple-mpv--audio-control-refresh ()
  "Force a redraw of the control bar (for callbacks)."
  (when (buffer-live-p simple-mpv--audio-control-buffer)
    (simple-mpv--audio-control-render)))

(defun simple-mpv--audio-list-buffer-play ()
  "Play the track under point in the audio list buffer."
  (interactive)
  (let* ((file  (tabulated-list-get-id))
         (index (cl-position file simple-mpv--audio-list :test #'equal)))
    (unless index
      (user-error "No audio track selected"))
    (simple-mpv--play-index index)))

(defun simple-mpv--audio-list-buffer-render ()
  "Populate the audio list buffer with the current track list."
  (with-current-buffer simple-mpv--audio-list-buffer
    (erase-buffer)
    (add-hook 'kill-buffer-hook #'simple-mpv--cleanup nil t)
    (setq tabulated-list-format
          [("Idx"  4 nil)
           ("Name" 40 nil)
           ("Tag"  0 nil)])
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


;;; Entry points

;;;###autoload
(defun simple-mpv-audio-browse ()
  "Scan `simple-mpv-audio-directory' and open the audio list buffer."
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

;;;###autoload
(defun simple-mpv-play-file (file)
  "Play FILE with a throwaway mpv process (independent of the IPC one)."
  (interactive "fPlay with mpv: ")
  (apply #'start-process
         "simple-mpv-call" "*simple-mpv-call*"
         simple-mpv-exe
         (cons file simple-mpv-call-extra-args)))

(provide 'simple-mpv)
;;; simple-mpv.el ends here
