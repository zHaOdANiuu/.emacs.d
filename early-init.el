;;; -*- lexical-binding: t -*-

;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=81506
;; (setq w32-ime-preedit t)

(defvar my--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil
      native-comp-jit-compilation nil
      gc-cons-percentage 1.0
      gc-cons-threshold most-positive-fixnum
      package-enable-at-startup nil
      load-suffixes `(".elc" ".el")
      load-prefer-newer t
      read-process-output-max (* 64 1024)
      process-adaptive-read-buffering nil
      command-line-x-option-alist nil
      select-active-regions 'only
      redisplay-skip-fontification-on-input t
      fast-but-imprecise-scrolling t
      ring-bell-function #'ignore
      idle-update-delay 1.0
      inhibit-compacting-font-caches t
      inhibit-startup-screen t
      inhibit-compacting-font-caches t
      inhibit-startup-echo-area-message user-login-name
      inhibit-redisplay t
      inhibit-message t
      frame-resize-pixelwise t
      frame-inhibit-implied-resize t
      tool-bar-mode -1
      menu-bar-mode -1
      scroll-bar-mode -1
      default-frame-alist
      '((menu-bar-lines . 0)
        (tool-bar-lines . 0)
        (horizontal-scroll-bars)
        (vertical-scroll-bars)
        (fullscreen . maximized)))

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist my--file-name-handler-alist
                  gc-cons-threshold (* 16 1024 1024)  ; 16MB
                  gc-cons-percentage 0.1)))

(add-hook 'window-setup-hook
          (lambda ()
            (setq inhibit-redisplay nil
                  inhibit-message nil)))

(when (boundp 'load-path-filter-function)
  (setq load-path-filter-function #'load-path-filter-cache-directory-files))

(when (boundp 'w32-get-true-file-attributes)
  (setq w32-get-true-file-attributes nil
        w32-pipe-read-delay 0
        w32-pipe-buffer-size (* 64 1024)))

(use-package package
  :ensure nil
  :custom
  (package-quickstart t)
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
  :config
  (setenv "TERM" "xterm-256color")
  (when (eq system-type 'windows-nt)
    (unless (getenv-internal "HOME")
      (when-let* ((home (getenv "USERPROFILE")))
        (setenv "HOME" home)
        (setq abbreviated-home-dir nil)))

    (when-let* ((msys2-root (getenv "MSYS2"))
                (msys2-bin (concat msys2-root "/usr/bin"))
                (ucrt64-bin (concat msys2-root "/ucrt64/bin"))
                (bash (concat msys2-bin "/bash.exe")))
      (add-to-list 'exec-path msys2-bin)
      (add-to-list 'exec-path ucrt64-bin)
      (setenv "PATH" (concat msys2-bin ";" ucrt64-bin ";" (getenv "PATH")))
      (setq shell-file-name bash
            explicit-shell-file-name (concat msys2-root "/msys2_shell.cmd")
            explicit-msys2_shell.cmd-args '("-defterm" "-here" "-full-path"
                                            "-no-start" "-ucrt64" "-i"))
      (setenv "MSYSTEM" "UCRT64")
      (setenv "SHELL" bash))))
