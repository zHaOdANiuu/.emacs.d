;;; -*- lexical-binding: t -*-

;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=81506
;; (setq w32-ime-preedit t)

(use-package emacs
  :ensure nil
  :hook (window-setup . (lambda () (setq inhibit-redisplay nil inhibit-message nil)))
  :init
  (put 'if-let 'byte-obsolete-info nil)
  (put 'when-let 'byte-obsolete-info nil)
  (set-default-toplevel-value 'lexical-binding t)

  (setq idle-update-delay 1.0
        inhibit-message t
        inhibit-redisplay t
        tool-bar-mode -1
        menu-bar-mode -1
        scroll-bar-mode -1
        default-frame-alist
        '((menu-bar-lines . 0)
          (tool-bar-lines . 0)
          (horizontal-scroll-bars)
          (vertical-scroll-bars)
          (fullscreen . maximized)))

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

  (when (boundp 'load-path-filter-function)
    (setq load-path-filter-function #'load-path-filter-cache-directory-files))

  (when (boundp 'w32-get-true-file-attributes)
    (setq w32-get-true-file-attributes nil
          w32-pipe-read-delay 0
          w32-pipe-buffer-size (* 64 1024)))
  :custom
  (user-lisp-auto-scrape nil)
  (native-comp-jit-compilation nil)
  (native-comp-deferred-compilation nil)
  (gc-cons-percentage (if noninteractive #x8000000 most-positive-fixnum))
  (gc-cons-threshold (if noninteractive #x8000000 most-positive-fixnum))
  (load-prefer-newer t)
  (redisplay-skip-fontification-on-input t)
  (read-process-output-max (* 64 1024))
  (process-adaptive-read-buffering nil)
  (command-line-x-option-alist nil)
  (select-active-regions 'only)
  (redisplay-skip-fontification-on-input t)
  (fast-but-imprecise-scrolling t)
  (ring-bell-function #'ignore)
  (use-short-answers t)
  (use-dialog-box nil)
  (use-file-dialog nil)
  (inhibit-compacting-font-caches t)
  (inhibit-startup-screen t)
  (inhibit-startup-echo-area-message user-login-name)
  (frame-resize-pixelwise t)
  (frame-inhibit-implied-resize t)
  (frame-title-format
   '(:eval (concat
            (if (and buffer-file-name (buffer-modified-p)) "● " "")
            (buffer-name)))))

(use-package package
  :ensure nil
  :custom
  (package-quickstart t)
  (package-quickstart-file (expand-file-name "package-quickstart.el" package-user-dir))
  (package-enable-at-startup t)
  (package-install-upgrade-built-in nil)
  (package-check-signature nil)
  (package-archives
   '(("melpa-cn" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
     ("gnu-cn"   . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/"))))

(use-package use-package
  :ensure nil
  :custom
  (use-package-always-ensure t)
  (use-package-always-defer t)
  (use-package-expand-minimally t))

(use-package env
  :ensure nil
  :init
  (setenv "TERM" "xterm-256color")
  (when (eq system-type 'windows-nt)
    (setenv "GIT_TERMINAL_PROMPT" "0")
    (setenv "GIT_ASK_YESNO" "false")
    (setenv "GIT_PAGER" "cat")
    (setenv "GIT_ASKPASS" "git-gui--askpass")

    (unless (getenv-internal "HOME")
      (when-let* ((home (getenv "USERPROFILE")))
        (setenv "HOME" home)
        (setq abbreviated-home-dir nil)))

    (when-let* ((bash (executable-find "bash.exe")))
      (setq shell-file-name bash)
      (setenv "MSYSTEM" "UCRT64")
      (setenv "SHELL" bash))))
