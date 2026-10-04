;;; -*- lexical-binding: t -*-

;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=81506
;; (setq w32-ime-preedit t)

(put 'if-let 'byte-obsolete-info nil)
(put 'when-let 'byte-obsolete-info nil)
(set-default-toplevel-value 'lexical-binding nil)
(run-with-idle-timer 5 t #'garbage-collect)
(load (expand-file-name "nn.el" user-emacs-directory))

(use-package emacs
  :ensure nil
  :hook (window-setup . (lambda () (setq inhibit-redisplay nil inhibit-message nil)))
  :init
  (setq native-comp-jit-compilation nil
        native-comp-deferred-compilation nil
        native-comp-async-on-battery-power nil
        process-adaptive-read-buffering t
        read-process-output-max (* 4 1024 1024)
        load-path-filter-function #'load-path-filter-cache-directory-files
        redisplay-skip-fontification-on-input t
        long-line-threshold 1000
        large-hscroll-threshold 1000
        bidi-inhibit-bpa t
        bidi-display-reordering nil
        default-process-coding-system
        (if (eq system-type 'windows-nt)
            `(utf-8-dos . ,locale-coding-system)
          '(utf-8-unix . utf-8-unix))
        inhibit-message t
        inhibit-redisplay t
        menu-bar-mode -1
        tool-bar-mode -1
        scroll-bar-mode -1
        frame-title-format
        '(:eval (concat
                 (if (and buffer-file-name (buffer-modified-p)) "● " "")
                 (buffer-name))))

  (setq-default tab-width 2
                tab-always-indent 'complete
                fill-column 80
                truncate-lines t
                truncate-partial-width-windows nil
                auto-composition-mode _GUI)

  (let ((default-file-name-handler-alist file-name-handler-alist)
        (default-load-file-rep-suffixes load-file-rep-suffixes))
    (setq file-name-handler-alist nil
          load-suffixes '(".elc" ".el")
          load-file-rep-suffixes '(""))
    (add-hook 'emacs-startup-hook
              (lambda ()
                (setq file-name-handler-alist default-file-name-handler-alist
                      load-file-rep-suffixes default-load-file-rep-suffixes))
              101))

  (when (boundp 'w32-get-true-file-attributes)
    (setq w32-get-true-file-attributes nil
          w32-pipe-read-delay 0
          w32-pipe-buffer-size read-process-output-max))
  :custom
  (user-full-name "zhaodaniu")
  (user-mail-address "zhaodaniu1@gmail.com")
  (user-lisp-auto-scrape nil)
  (gc-cons-percentage (if noninteractive #x8000000 most-positive-fixnum))
  (gc-cons-threshold (if noninteractive #x8000000 most-positive-fixnum))
  (load-prefer-newer t)
  (idle-update-delay 1.0)
  (select-active-regions 'only)
  (fast-but-imprecise-scrolling t)
  (ring-bell-function #'ignore)
  (use-short-answers t)
  (use-dialog-box nil)
  (use-file-dialog nil)
  (cursor-type 'box)
  (visible-bell nil)
  (visible-cursor nil)
  (resize-mini-windows t)
  (delete-by-moving-to-trash t)
  (delete-pair-blink-delay 0)
  (delete-pair-push-mark t)
  (undo-limit (* 13 160000))
  (undo-strong-limit (* 13 240000))
  (undo-outer-limit (* 13 24000000))
  (word-wrap-by-category t)
  (window-combination-resize t)
  (x-underline-at-descent-line t)
  (inhibit-startup-screen t)
  (inhibit-startup-echo-area-message user-login-name)
  (inhibit-compacting-font-caches t)
  (frame-resize-pixelwise t)
  (frame-inhibit-implied-resize t)
  (default-frame-alist
    '((menu-bar-lines . 0)
      (tool-bar-lines . 0)
      (horizontal-scroll-bars)
      (vertical-scroll-bars)
      (fullscreen . maximized)))
  :config
  (setq browse-url-firefox-program nil
        browse-url-chrome-program nil
        browse-url-chromium-program nil
        browse-url-text-browser nil
        browse-url-browser-function 'eww-browse-url
        sgml-validate-command nil)

  ;; exec
  (when _WIN32
    (setq exec-suffixes '("" ".exe" ".bat")))

  (defvar my-executable-find-cache (make-hash-table :test 'equal :size 100))
  (defvar my-executable-find-cache-miss (make-symbol "miss"))

  (defun my-executable-find-clear-cache ()
    (clrhash my-executable-find-cache))

  (define-advice executable-find
      (:around (orig-fun command &optional remote)
       my-executable-find-cache-advice)
    (if remote
        (funcall orig-fun command remote)
      (let ((cached (gethash command my-executable-find-cache my-executable-find-cache-miss)))
        (if (eq cached my-executable-find-cache-miss)
            (puthash command (funcall orig-fun command) my-executable-find-cache)
          cached))))

  ;; dired
  (setq dired-chown-program (not _WIN32)
        shell-command-guess-open nil)

  (with-eval-after-load 'dired
    (define-key dired-mode-map [remap dired-do-open] #'nn-open-in-external-app))

  ;; find-gile
  (remove-hook 'find-file-hook #'vc-refresh-state)
  (remove-hook 'find-file-hook #'epa-file-find-file-hook))

(use-package env
  :ensure nil
  :hook (after-init . nn-set-exec-path-from-shell-PATH)
  :init
  (setenv "TERM" "xterm-256color")
  (when _WIN32
    (setq process-connection-type nil)

    (setenv "GIT_ASKPASS" "git-gui--askpass")

    (unless (getenv-internal "HOME")
      (when-let* ((home (getenv "USERPROFILE")))
        (setenv "HOME" home)
        (setq abbreviated-home-dir nil)))

    (when-let* ((bash (executable-find "bash")))
      (setq shell-file-name bash)
      (setenv "MSYSTEM" "UCRT64")
      (setenv "SHELL" bash)
      ;; (push (file-name-directory bash) exec-path)
      ))

  (defun nn-set-exec-path-from-shell-PATH ()
    "Set up Emacs' `exec-path' and PATH environment the same as the user's shell.
This works with bash, zsh, or fish.

The shell is spawned ASYNCHRONOUSLY so it never blocks startup: PATH is
updated from the sentinel once the shell responds (typically within a
~100ms after init).  Commands issued in that tiny initial window may not
yet see the updated PATH."
    (interactive)
    (let* ((shell (getenv "SHELL"))
           (shell-name (file-name-nondirectory (or shell "")))
           (command
            (cond
             ((string= shell-name "fish")
              "fish -c 'string join : $PATH'")
             ((string= shell-name "zsh")
              "zsh -i -c 'printenv PATH'")
             ((string= shell-name "bash")
              "bash --login -c 'echo $PATH'")
             (t nil))))
      (if (not command)
          (message ">>> nn: `%s' shell is not supported" shell-name)
        (let ((output ""))
          (make-process
           :name "nn-exec-path"
           :buffer nil
           :noquery t
           :connection-type 'pipe
           :command `(,shell-file-name ,shell-command-switch ,command)
           :filter (lambda (_proc chunk) (setq output (concat output chunk)))
           :sentinel
           (lambda (_proc event)
             (when (string-prefix-p "finished" event)
               (let ((path-from-shell
                      (replace-regexp-in-string "[ \t\n]*$" "" output)))
                 (when (and path-from-shell (not (string= path-from-shell "")))
                   (setenv "PATH" path-from-shell)
                   (setq exec-path (split-string path-from-shell path-separator))
                   (message ">>> nn: environment variable PATH loaded from `%s' shell" shell-name)))))))))))

(use-package package
  :ensure nil
  :custom
  (package-quickstart t)
  (package-quickstart-file (expand-file-name "package-quickstart.el" package-user-dir))
  (package-enable-at-startup t)
  (package-install-upgrade-built-in nil)
  (package-check-signature nil)
  (package-archives
   '(("gnu-cn"   . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
     ("melpa-cn" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/"))))

(use-package use-package
  :ensure nil
  :custom
  (use-package-always-ensure t)
  (use-package-always-defer t)
  (use-package-expand-minimally t))

(nn-initialize)
