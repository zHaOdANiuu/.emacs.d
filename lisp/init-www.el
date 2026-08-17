;;; -*- lexical-binding: t -*-
(use-package auth-source
  :ensure nil
  :custom
  (user-full-name "zhaodaniu")
  (user-mail-address "zhaodaniu1@gmail.com"))

(use-package server
  :ensure nil
  :custom (server-auth-dir (expand-file-name "server/" nn-directory)))

(use-package tramp
  :ensure nil
  :custom
  (tramp-auto-save-directory (expand-file-name "tramp/auto-save/" nn-directory))
  (tramp-persistency-file-name (expand-file-name "tramp/persistency.el" nn-directory))
  (remote-file-name-inhibit-cache 60)
  (remote-file-name-inhibit-locks t)
  (remote-file-name-inhibit-auto-save-visited t)
  (tramp-copy-size-limit (* 1024 1024))
  (tramp-use-scp-direct-remote-copying t)
  (tramp-completion-reread-directory-timeout 60)
  :config
  (unless (eq system-type 'windows-nt)
    (setq tramp-default-method "ssh"))
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))
  (connection-local-set-profiles
   '(:application tramp :protocol "scp")
   'remote-direct-async-process))

(use-package eww
  :ensure nil
  :custom (eww-search-prefix "https://lite.duckduckgo.com/lite/?q=")
  :config
  (add-to-list 'eww-url-transformers #'eww-remove-tracking)

  (define-advice eww (:around (fn &rest args) myeww-open-in-fullscreen)
    "Open EWW in fullscreen if called interactively."
    (if (called-interactively-p 'any)
        (let ((display-buffer-alist '(("\\*eww\\*" (display-buffer-full-frame)))))
          (apply fn args))
      (apply fn args)))

  (defun my-eww-page-title-or-url ()
    "Use page title as buffer name, fallback to URL."
    (let ((title (plist-get eww-data :title)))
      (format "*%s # eww*" (if (string-blank-p title)
                               (plist-get eww-data :url)
                             title))))

  (if (boundp 'eww-auto-rename-buffer)
      (setq eww-auto-rename-buffer #'my-eww-page-title-or-url)
    (defun my-eww--rename-buffer-h (&rest _)
      (rename-buffer (my-eww-page-title-or-url)))
    (add-hook 'eww-after-render-hook #'my-eww--rename-buffer-h)
    (advice-add 'eww-back-url :after #'my-eww--rename-buffer-h)
    (advice-add 'eww-forward-url :after #'my-eww--rename-buffer-h)))

(use-package mm-decode
  :ensure nil
  :custom (mm-text-html-renderer 'shr))

(use-package tree-widget
  :ensure nil
  :custom (tree-widget-image-enable nil)
  :config
  (define-widget 'tree-widget-open-icon 'tree-widget-icon
    "Icon for an expanded tree-widget node." :tag "▼ ")
  (define-widget 'tree-widget-close-icon 'tree-widget-icon
    "Icon for a collapsed tree-widget node." :tag "▶ ")
  (define-widget 'tree-widget-empty-icon 'tree-widget-icon
    "Icon for an expanded node with no child." :tag "▼ ")
  (define-widget 'tree-widget-leaf-icon 'tree-widget-icon
    "Icon for a leaf node." :tag "")
  (define-widget 'tree-widget-guide 'item
    "Vertical guide line." :tag " " :format "%t")
  (define-widget 'tree-widget-nohandle-guide 'item
    "Vertical guide line, no handle." :tag " " :format "%t")
  (define-widget 'tree-widget-end-guide 'item
    "End of a vertical guide line." :tag " " :format "%t")
  (define-widget 'tree-widget-no-guide 'item
    "Invisible vertical guide line." :tag "  " :format "%t")
  (define-widget 'tree-widget-handle 'item
    "Horizontal guide line." :tag "" :format "%t")
  (define-widget 'tree-widget-no-handle 'item
    "Invisible handle." :tag " " :format "%t"))

(use-package newsticker
  :ensure nil
  :bind
  (("C-c n" . my-newsticker-show-news)
   :map newsticker-treeview-mode-map
   ("C-x k" . newsticker-treeview-quit))
  :hook (newsticker-start . nn-proxy-enable)
  :custom
  (newsticker-dir (expand-file-name "newsticker/data/" nn-directory))
  (newsticker-cache-filename (expand-file-name "newsticker/cache.el" nn-directory))
  (newsticker-retrieval-interval 0)
  (newsticker-retrieval-method (if (executable-find "wget") 'extern 'intern))
  (newsticker-wget-arguments
   '("--quiet" "--no-hsts" "--output-document=-" "--append-output=/dev/null"))
  (newsticker-automatically-mark-items-as-old nil)
  (newsticker-url-list-defaults nil)
  (newsticker-url-list
   '(("Xkcd" "https://xkcd.com/rss.xml")
     ("Sacha Chua" "https://sachachua.com/blog/category/emacs-news/feed/")
     ("Planet Emacslife" "https://planet.emacslife.com/atom.xml")
     ("Emacs TIL" "https://emacstil.com/feed.xml")
     ("60秒看世界" "https://60s.viki.moe/v2/60s/rss")))
  :config
  (defun my-newsticker-show-news ()
    (interactive)
    (require 'newsticker)
    (cl-letf (((symbol-function 'newsticker-start) #'ignore))
      (newsticker-show-news))))

(use-package rcirc
  :ensure nil
  :custom
  (rcirc-debug t)
  (rcirc-default-nick user-full-name)
  (rcirc-default-user-name user-full-name)
  (rcirc-log-directory (expand-file-name "rcirc-log/" nn-directory))
  (rcirc-default-full-name user-full-name)
  (rcirc-server-alist
   '(("irc.libera.chat"
      :port 6697
      :encryption tls
      :channels ("#emacs" "#systemcrafters"))))
  (rcirc-reconnect-delay 5)
  (rcirc-fill-column 100)
  (rcirc-track-ignore-server-buffer-flag t)
  :config
  (make-directory (expand-file-name "rcirc-log/" nn-directory) t)
  (setq rcirc-authinfo
        `(("irc.libera.chat"
           certfp
           ,(expand-file-name "cert.pem" user-emacs-directory)
           ,(expand-file-name "cert.pem" user-emacs-directory)))))

(use-package erc
  :ensure nil
  :hook (erc-insert-modify . my-erc-colorize-nick)
  :custom
  (erc-image-cache-directory (expand-file-name "erc/images/" nn-directory))
  (erc-log-channels-directory (expand-file-name "erc/log-channels/" nn-directory))
  (erc-join-buffer 'window)
  (erc-hide-list '("JOIN" "PART" "QUIT"))
  (erc-timestamp-format "[%H:%M]")
  (erc-autojoin-channels-alist '((".*\\.libera\\.chat" "#emacs" "#systemcrafters")))
  (erc-server-reconnect-attempts 10)
  (erc-server-reconnect-timeout 3)
  (erc-fill-function 'erc-fill-wrap)
  ;; EMACS-31 and or needs https://debbugs.gnu.org/cgi/bugreport.cgi?bug=79665 patch
  (erc-log-insert-log-on-open
   (if (fboundp 'erc-log-new-target-buffer-p)
       'erc-log-new-target-buffer-p
     t))
  (erc-save-buffer-on-part t)
  (erc-save-queries-on-quit t)
  (erc-log-write-after-send t)
  (erc-log-write-after-insert t)
  (erc-spelling-dictionaries '(("Libera.Chat" "en_US")))
  :config
  (make-directory (expand-file-name "erc/images/" nn-directory) t)
  (make-directory (expand-file-name "erc/log-channels/" nn-directory) t)

  (setopt erc-sasl-mechanism 'external)

  (defun my-erc-get-color-for-nick (nick)
    "Return a Catppuccin Mocha Like color string for NICK based on its hash."
    (let* ((colors '("#f38ba8" "#a6e3a1" "#f9e2af" "#89b4fa"
                     "#cba6f7" "#fab387" "#b4befe" "#eba0ac"
                     "#f5c2e7"))
           (hash (mod (abs (sxhash nick)) (length colors))))
      (nth hash colors)))

  (defun my-erc-colorize-nick ()
    "Colorize nicknames in ERC buffer."
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\(<\\)\\([^ >]+\\)\\(>\\)" nil t)
        (let* ((nick (match-string 2))
               (color (my-erc-get-color-for-nick nick)))
          (put-text-property (match-beginning 2) (match-end 2)
                             'face `(:foreground ,color :weight bold))))))

  (add-to-list 'erc-modules 'log)
  (add-to-list 'erc-modules 'sasl)
  ;; EMACS-31 (no more dependency between scrolltobottom and erc-fill-wrap THX!!!)
  (when (< emacs-major-version 31)
    (add-to-list 'erc-modules 'scrolltobottom))

  (defun erc-liberachat ()
    (interactive)
    (let ((buf
           (erc-tls
            :server "irc.libera.chat"
            :port 6697
            :user user-full-name
            :password ""
            :client-certificate
            `(,(expand-file-name "cert.pem" user-emacs-directory)
              ,(expand-file-name "cert.pem" user-emacs-directory)))))
      (when (bufferp buf)
        (pop-to-buffer buf))))

  (erc-spelling-mode 1))

(use-package smtpmail
  :ensure nil
  :custom
  (smtpmail-debug-info t)
  (smtpmail-debug-verb t)
  (send-mail-function 'smtpmail-send-it)
  (smtpmail-smtp-server "smtp.gmail.com")
  (smtpmail-smtp-service 465)
  (smtpmail-stream-type 'ssl)
  (smtpmail-smtp-user user-mail-address)
  :config
  (defun my-switch-qq-mail ()
    (interactive)
    (setq smtpmail-smtp-server "smtp.qq.com"))

  (defun my-switch-google-mail ()
    (interactive)
    (setq smtpmail-smtp-server "smtp.gmail.com"))

  (my-switch-google-mail))

(use-package gnus
  :ensure nil
  :hook (gnus-group-mode . gnus-topic-mode)
  :custom
  (gnus-mode-line-logo nil)
  (gnus-init-file (expand-file-name "gnus/init.el" nn-directory))
  (gnus-startup-file (expand-file-name "gnus/newsrc" nn-directory))
  (gnus-dribble-directory (expand-file-name "gnus/dribble/" nn-directory))
  (gnus-activate-level 3)
  (gnus-message-archive-group nil)
  (gnus-check-new-newsgroups nil)
  (gnus-check-bogus-newsgroups nil)
  (gnus-show-threads nil)
  (gnus-use-cross-reference nil)
  (gnus-nov-is-evil nil)
  (gnus-group-line-format "%1M%5y : %(%-50,50G%)\12")
  (gnus-logo-colors '("#ff5591" "#c0c0c0"))
  (gnus-permanently-visible-groups ".*")
  (gnus-summary-insert-entire-threads t)
  (gnus-thread-sort-functions
   '(gnus-thread-sort-by-most-recent-number
     gnus-thread-sort-by-subject
     (not gnus-thread-sort-by-total-score)
     gnus-thread-sort-by-most-recent-date))
  (gnus-summary-line-format "%U %R %z : %[%d%] %4{ %-34,34n%} %3{ %}%(%1{%B%}%s%)\12")
  (gnus-user-date-format-alist '((t . "%d-%m-%Y %H:%M")))
  (gnus-summary-thread-gathering-function 'gnus-gather-threads-by-references)
  (gnus-sum--tree-indent " ")
  (gnus-sum-thread-tree-indent " ")
  (gnus-sum-thread-tree-false-root "○ ")
  (gnus-sum-thread-tree-single-indent "◎ ")
  (gnus-sum-thread-tree-leaf-with-other "├► ")
  (gnus-sum-thread-tree-root "● ")
  (gnus-sum-thread-tree-single-leaf "╰► ")
  (gnus-sum-thread-tree-vertical "│")
  (gnus-ignored-newsgroups "^to\\.\\|^[0-9. ]+\\( \\|$\\)\\|^[\"]\"[#'()]")
  (gnus-select-method
   '(nnimap "imap.gmail.com"
            (nnimap-expunge t)
            (nnimap-server-port 993)
            (nnimap-stream ssl)))
  (gnus-secondary-select-methods
   '((nntp "nntp.lore.kernel.org")
     (nnimap "imap.qq.com"
             (nnimap-expunge t)
             (nnimap-server-port 993)
             (nnimap-stream ssl)))))

(use-package gnus-modern
  :ensure nil
  :hook (gnus-mode . gnus-modern-mode))

(use-package telega
  :hook (telega-before-auth . my-telega-proxy)
  :custom
  (telega-server-libs-prefix "D:/local")
  (telega-avatar-workaround-gaps-for (when (display-graphic-p) '(return t)))
  :config
  (defun my-telega-proxy ()
    (telega--addProxy
        '(:server "localhost"
          :port nn-proxy-port
          :type (:@type "proxyTypeSocks5"))
      :enable-p 'enable))

  (when (eq system-type 'windows-nt)
    (define-advice telega-server--start (:around (fn &rest args) isolate-stderr)
      (apply fn args)
      (let* ((buf telega-server--buffer)
             (cmd (process-command (get-buffer-process buf))))
        (delete-process (get-buffer-process buf))
        (make-process
         :coding '(binary . utf-8)
         :name "telega-server"
         :buffer buf
         :command cmd
         :noquery t
         :sentinel #'telega-server--sentinel
         :filter #'telega-server--filter
         :connection-type 'pipe
         :stderr (make-pipe-process
                  :name "telega-server--stderr"
                  :buffer " *telega-server--stderr*" ;; hide buffer
                  :noquery t))))))

(provide 'init-www)
