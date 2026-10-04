;;; -*- lexical-binding: t -*-
(use-package proced
  :ensure nil
  :custom
  (proced-enable-color-flag t)
  (proced-tree-flag t)
  (proced-auto-update-flag 'visible)
  (proced-auto-update-interval 1)
  (proced-descend t)
  (proced-format 'medium)
  (proced-filter 'user))

(use-package man
  :ensure nil
  :commands man
  :custom (Man-notify-method 'pushy))

(use-package webjump
  :ensure nil
  :bind ("C-c /" . my-webjump-eww)
  :custom
  (webjump-sites
   '(("DuckDuckGo"     . [simple-query "https://www.duckduckgo.com"
                                       "https://www.duckduckgo.com/?q=" ""])
     ("DuckDuckAI"     . [simple-query "https://duck.ai" "https://duck.ai/?q=" ""])
     ("DuckDuckGoImg"  . [simple-query "https://www.duckduckgo.com"
                                       "https://www.duckduckgo.com/?iar=images&q=" ""])
     ("Bing"           . [simple-query "www.bing.com" "www.bing.com/search?q=" ""])
     ("Google"         . [simple-query "https://www.google.com"
                                       "https://www.google.com/search?q=" ""])
     ("YouTube"        . [simple-query "https://www.youtube.com/feed/subscriptions"
                                       "https://www.youtube.com/results?search_query=" ""])
     ("Wikipedia"      . [simple-query "wikipedia.org" "wikipedia.org/wiki/" ""])))
  :config
  (defun my-webjump-eww (&optional arg)
    (require 'eww)
    (let ((webjump-use-internal-browser arg))
      (call-interactively #'webjump))))

(use-package bookmark
  :ensure nil
  :custom (bookmark-default-file (concat nn-directory "bookmark-default.el"))
  :config
  (define-advice bookmark-bmenu--revert (:after (&rest _) my-bookmark-bmenu--icons)
    "Prepend nerd-icons to bookmark names."
    (when _GUI
      (dolist (entry tabulated-list-entries)
        (let* ((rec (car entry))
               (row (cadr entry))
               (loc (bookmark-get-filename rec))
               (file (and (stringp loc)
                          (not (string-empty-p loc))
                          (file-name-nondirectory loc)))
               (icon (cond ((not loc) nil)
                           ((file-remote-p loc)
                            (nerd-icons-codicon "nf-cod-radio_tower"))
                           ((file-directory-p loc)
                            (nerd-icons-icon-for-dir loc))
                           ((and file (not (string-empty-p file)))
                            (nerd-icons-icon-for-file file))))
               (idx (if bookmark-bmenu-toggle-filenames 1 0)))
          (when icon
            (setf (elt row idx)
                  (concat icon "  " (elt row idx))))))
      (tabulated-list-print t))))

(use-package wgrep
  :custom
  (wgrep-auto-save-buffer t)
  (wgrep-change-readonly-file t))

(use-package rg
  :commands rg
  :hook (rg-mode . (lambda () (setq-local compilation-insert-header-function #'ignore)))
  :bind
  (("C-c s" . my-rg-current-dir-all)
   ("C-c C-s" . rg-menu)
   :map rg-global-map
   ("c" . rg-dwim-current-dir)
   ("f" . rg-dwim-current-file)
   ("m" . rg-menu))
  :custom (rg-keymap-prefix nil)
  :config
  (defun my-rg-current-dir-all (query)
    "Search QUERY in all files under current directory."
    (interactive "sSearch: ")
    (rg-literal query "*" default-directory)))

(use-package calfw
  :custom
  (calfw-fchar-junction ?╋)
  (calfw-fchar-vertical-line ?┃)
  (calfw-fchar-horizontal-line ?━)
  (calfw-fchar-left-junction ?┣)
  (calfw-fchar-right-junction ?┫)
  (calfw-fchar-top-junction ?┯)
  (calfw-fchar-top-left-corner ?┏)
  (calfw-fchar-top-right-corner ?┓)
  (calfw-show-holidays nil))

(use-package calfw-org
  :commands calfw-org-open-calendar
  :bind ("C-c C-c" . my-calfw-open)
  :config
  (defun my-calfw-open ()
    (interactive)
    (calfw-org-open-calendar)
    (text-scale-set -1)
    (calfw-refresh-calendar-buffer)))

(use-package simple-mpv
  :ensure nil
  :custom (simple-mpv-debug nil)
  :bind ("C-c m" . simple-mpv-audio-browse)
  :config
  (with-eval-after-load 'dired
    (keymap-set dired-mode-map "C-c p" #'simple-mpv-play-file)))

(use-package nn-license-template
  :ensure nil
  :commands nn-license-template-file nn-license-template-header
  :bind
  ("C-c l f" . nn-license-template-file)
  ("C-c l h" . nn-license-template-header))

(provide 'init-utils)
