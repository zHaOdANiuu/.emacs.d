;;; -*- lexical-binding: t -*-
(use-package auth-source
  :ensure nil
  :custom
  (user-full-name "zhaodaniu")
  (user-mail-address "zhaodaniu1@gmail.com"))

(use-package server
  :ensure nil
  :custom (server-auth-dir (concat nn-directory "server/")))

(use-package nsm
  :ensure nil
  :custom (nsm-settings-file (concat nn-directory "network-security.eld")))

(use-package mm-decode
  :ensure nil
  :custom (mm-text-html-renderer 'shr))

(use-package tramp
  :ensure nil
  :init
  (setq tramp-auto-save-directory (concat nn-directory "tramp/auto-save/")
        tramp-persistency-file-name (concat nn-directory "tramp/persistency.el"))
  :custom
  (remote-file-name-inhibit-cache 60)
  (remote-file-name-inhibit-locks t)
  (remote-file-name-inhibit-auto-save-visited t)
  (tramp-verbose 1)
  (tramp-copy-size-limit (* 1024 1024))
  (tramp-use-scp-direct-remote-copying t)
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
  (newsticker-dir (concat nn-directory "newsticker/data/"))
  (newsticker-cache-filename (concat nn-directory "newsticker/cache.el"))
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

(use-package message
  :ensure nil
  :hook (message-mode . auto-fill-mode)
  :custom
  (message-kill-buffer-on-exit t)
  (message-signature user-full-name)
  (message-mail-alias-type 'ecomplete)
  (message-send-mail-function #'message-use-send-mail-function))

(use-package smtpmail
  :ensure nil
  :custom
  (send-mail-function 'smtpmail-send-it)
  (smtpmail-debug-info t)
  (smtpmail-debug-verb t)
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
  :custom
  (gnus-init-file (concat nn-directory ".gnus.el"))
  (gnus-startup-file (concat nn-directory ".newsrc"))
  (gnus-always-read-dribble-file t)
  (gnus-activate-level 3)
  (gnus-use-cache t)
  (gnus-use-scoring nil)
  (gnus-use-full-window nil)
  (gnus-suppress-duplicates t)
  (gnus-novice-user nil)
  (gnus-expert-user t)
  (gnus-interactive-exit 'quiet)
  ;;; Startup functions
  (gnus-save-killed-list nil)
  (gnus-check-new-newsgroups nil)
  ;; No other newsreader is used.
  (gnus-save-newsrc-file nil)
  (gnus-read-newsrc-file nil)
  ;; (gnus-subscribe-newsgroup-method 'gnus-subscribe-interactively)
  (gnus-subscribe-newsgroup-method 'gnus-subscribe-zombies)
  (gnus-search-use-parsed-queries t)
  ;;; Article mode for Gnus
  (gnus-visible-headers
   (rx line-start
       (or "From" "Subject"
           "Mail-Followup-To"
           "Date" "To" "Cc"
           "Newsgroups" "User-Agent"
           "X-Mailer" "X-Newsreader")
       ":"))
  (gnus-article-sort-functions
   '((not gnus-article-sort-by-number)
     (not gnus-article-sort-by-date)))
  (gnus-article-browse-delete-temp t)
  ;; Display more MINE stuff
  (gnus-mime-display-multipart-related-as-mixed t)
  ;;; Asynchronous support for Gnus
  (gnus-asynchronous t)
  (gnus-use-header-prefetch t)
  ;;; Cache interface for Gnus
  (gnus-cache-enter-articles '(ticked dormant unread))
  (gnus-cache-remove-articles '(read))
  (gnus-cacheable-groups "^\\(nntp\\|nnimap\\)")
  :config
  (with-eval-after-load 'gnus-win
    (setf (alist-get 'article gnus-buffer-configuration)
          '((horizontal 1.0 (summary 0.5 point) (article 1.0)))))

  (setq gnus-logo-colors '("#ff5591" "#c0c0c0")
        gnus-select-method '(nnnil "")
        gnus-secondary-select-methods
        '((nntp "news.gmane.io")
          ;; (nntp "nntp.lore.kernel.org")
          (nnimap "imap.gmail.com"
                  (nnimap-expunge t)
                  (nnimap-server-port 993)
                  (nnimap-stream ssl))
          ;; (nnimap "imap.qq.com"
          ;;         (nnimap-expunge t)
          ;;         (nnimap-server-port 993)
          ;;         (nnimap-stream ssl))
          )))

(use-package gnus-group
  :ensure nil
  :hook (gnus-group-mode . gnus-topic-mode)
  :custom
  ;;          indentation ------------.
  ;;  #      process mark ----------. |
  ;;                level --------. | |
  ;;           subscribed ------. | | |
  ;;  %          new mail ----. | | | |
  ;;  *   marked articles --. | | | | |
  ;;                        | | | | | |  Ticked    New     Unread  open-status Group
  (gnus-group-line-format "%M%m%S%L%p%P %1(%7i%) %3(%7U%) %3(%7y%) %4(%B%-45G%) %d\n")
  (gnus-group-sort-function '(gnus-group-sort-by-level gnus-group-sort-by-alphabet))
  :config (require 'gnus-topic))

(use-package gnus-sum
  :ensure nil
  :hook (gnus-select-group . gnus-group-set-timestamp)
  :custom
  ;; Pretty marks
  (gnus-sum-thread-tree-indent          "  ")
  (gnus-sum-thread-tree-single-indent   "◎ ")
  (gnus-sum-thread-tree-root            "┌ ")
  (gnus-sum-thread-tree-false-root      "◌ ")
  (gnus-sum-thread-tree-vertical        "│")
  (gnus-sum-thread-tree-leaf-with-other "├─►")
  (gnus-sum-thread-tree-single-leaf     "╰─►")
  (gnus-summary-line-format "%U%R %3d %[%-23,23f%] %B %s\n")
  ;; Loose threads
  (gnus-summary-make-false-root 'adopt)
  (gnus-simplify-subject-functions '(gnus-simplify-subject-re gnus-simplify-whitespace))
  (gnus-summary-thread-gathering-function 'gnus-gather-threads-by-subject)
  ;; Filling in threads
  ;; Do not fetch extra old headers when opening a group
  (gnus-fetch-old-headers 0)
  (gnus-fetch-old-ephemeral-headers 0)
  (gnus-build-sparse-threads 'some)
  ;; More threading
  (gnus-show-threads t)
  (gnus-thread-indent-level 2)
  (gnus-thread-hide-subtree nil)
  ;; Sorting
  (gnus-thread-sort-functions '(gnus-thread-sort-by-most-recent-date))
  (gnus-subthread-sort-functions '(gnus-thread-sort-by-date))
  ;; Viewing
  (gnus-view-pseudos 'automatic)
  (gnus-view-pseudos-separately t)
  (gnus-view-pseudo-asynchronously t)
  ;; No auto select
  (gnus-auto-select-first nil)
  (gnus-auto-select-next nil)
  (gnus-paging-select-next nil))

(use-package rcirc
  :ensure nil
  :custom
  (rcirc-debug t)
  (rcirc-default-nick user-full-name)
  (rcirc-default-user-name user-full-name)
  (rcirc-log-directory (concat nn-directory "rcirc-log/"))
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
  (make-directory (concat nn-directory "rcirc-log/") t)
  (setq rcirc-authinfo
        `(("irc.libera.chat"
           certfp
           ,(expand-file-name "cert.pem" user-emacs-directory)
           ,(expand-file-name "cert.pem" user-emacs-directory)))))

(use-package erc
  :ensure nil
  :hook (erc-insert-modify . my-erc-colorize-nick)
  :custom
  (erc-image-cache-directory (concat nn-directory "erc/images/"))
  (erc-log-channels-directory (concat nn-directory "erc/log-channels/"))
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

(use-package telega
  :hook
  (telega-before-auth . my-telega-proxy)
  (telega-chat-mode . telega-completions-setup-capf)
  (telega-image-mode . image-transform-fit-to-window)
  :custom
  (telega-server-libs-prefix "D:/local")
  (telega-avatar-workaround-gaps-for (when (display-graphic-p) '(return t)))
  (telega-translate-to-language-by-default "zh")
  (telega-msg-save-dir "~/Downloads")
  (telega-chat-input-markups '("markdown2" "org"))
  (telega-root-keep-cursor 'track)
  (telega-root-buffer-name "*Telega Root*")
  (telega-root-fill-column 70)
  (telega-emoji-use-images nil)
  (telega-filters-custom nil)
  (telega-filter-custom-show-folders nil)
  (telega-symbol-vertical-bar "│")
  (telega-symbol-mark (propertize " " 'face 'telega-button-highlight))
  (telega-symbol-button-close (nerd-icons-mdicon "nf-md-close_box_outline"))
  (telega-symbol-verified (nerd-icons-codicon "nf-cod-verified_filled" :face 'telega-blue))
  (telega-symbol-saved-messages-tag-end (nerd-icons-faicon "nf-fa-tag"))
  (telega-symbol-forum (nerd-icons-mdicon "nf-md-format_list_text"))
  (telega-symbol-reply-quote (nerd-icons-faicon "nf-fa-reply_all"))
  (telega-symbol-forward (nerd-icons-faicon "nf-fa-mail_forward"))
  (telega-symbol-checkmark (nerd-icons-mdicon "nf-md-check"))
  (telega-symbol-heavy-checkmark (nerd-icons-codicon "nf-cod-check_all"))
  (telega-symbol-summarize-in (nerd-icons-octicon "nf-oct-fold"))
  (telega-symbol-summarize-out (nerd-icons-octicon "nf-oct-unfold"))
  :config
  (telega-autoplay-mode 1)
  (telega-notifications-mode 1)
  (setq telega-symbols-emojify
        (cl-reduce
         (lambda (emojify key)
           (assq-delete-all key emojify))
         '(verified vertical-bar
           checkmark forum heavy-checkmark
           reply reply-quote horizontal-bar
           forward button-close summarize-in summarize-out)
         :initial-value telega-symbols-emojify))

  (defun my-telega-proxy ()
    (telega--addProxy
     `(:server "localhost"
       :port ,nn-proxy-port
       :type (:@type "proxyTypeSocks5"))
     :enable-p 'enable))

  (when (eq system-type 'windows-nt)
    (define-advice telega-server--start (:around (fn &rest args) my-telega-server--start)
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
