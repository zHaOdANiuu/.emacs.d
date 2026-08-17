;;; -*- lexical-binding: t -*-

;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=81506
;; (setq w32-ime-preedit t)

(put 'if-let 'byte-obsolete-info nil)
(put 'when-let 'byte-obsolete-info nil)

(defvar my--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil
      native-comp-jit-compilation t
      read-process-output-max (* 64 1024)
      gc-cons-percentage 1.0
      gc-cons-threshold most-positive-fixnum
      package-enable-at-startup nil
      auto-mode-case-fold nil
      load-suffixes `(".elc" ".el")
      load-prefer-newer t
      inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name
      inhibit-redisplay t
      inhibit-message t
      frame-inhibit-implied-resize t
      menu-bar-mode -1
      tool-bar-mode -1
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

(when (eq system-type 'windows-nt)
  (w32-set-console-codepage 65001)
  (setenv "LANG" "en_US.UTF-8")

  (when (boundp 'w32-get-true-file-attributes)
    (setq w32-get-true-file-attributes nil
          w32-pipe-read-delay 0
          w32-pipe-buffer-size (* 64 1024)))

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
    (setenv "TERM" "xterm-256color")
    (setenv "SHELL" bash)))
