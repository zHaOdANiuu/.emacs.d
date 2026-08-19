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

(use-package time
  :ensure nil
  :custom
  (world-clock-time-format "%A %d %B %H:%M:%S %Z")
  (world-clock-sort-order "%FT%T") ; EMACS-31
  (display-time-day-and-date t)
  (display-time-default-load-average nil)
  (display-time-mail-string "")
  (zoneinfo-style-world-list ; use `M-x worldclock RET' to see it
   '(("America/Los_Angeles" "Los Angeles")
     ("America/Vancouver" "Vancouver")
     ("Canada/Pacific" "Canada/Pacific")
     ("America/Chicago" "Chicago")
     ("America/Toronto" "Toronto")
     ("America/New_York" "New York")
     ("Canada/Atlantic" "Canada/Atlantic")
     ("Brazil/East" "Brasília")
     ("America/Sao_Paulo" "São Paulo")
     ("UTC" "UTC")
     ("Europe/Lisbon" "Lisbon")
     ("Europe/Brussels" "Brussels")
     ("Europe/Athens" "Athens")
     ("Asia/Riyadh" "Riyadh")
     ("Asia/Amman" "Jordan")
     ("Asia/Tehran" "Tehran")
     ("Asia/Tbilisi" "Tbilisi")
     ("Asia/Yekaterinburg" "Yekaterinburg")
     ("Asia/Kolkata" "Kolkata")
     ("Asia/Singapore" "Singapore")
     ("Asia/Shanghai" "Shanghai")
     ("Asia/Seoul" "Seoul")
     ("Asia/Tokyo" "Tokyo")
     ("Asia/Vladivostok" "Vladivostok")
     ("Australia/Brisbane" "Brisbane")
     ("Australia/Sydney" "Sydney")
     ("Pacific/Auckland" "Auckland"))))

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
     ("DuckDuckGoNoAI" . [simple-query "https://noai.duckduckgo.com"
                                       "https://noai.duckduckgo.com/?q=" ""])
     ("DuckDuckAI"     . [simple-query "https://duck.ai" "https://duck.ai/?q=" ""])
     ("DuckDuckGoImg"  . [simple-query "https://www.duckduckgo.com"
                                       "https://www.duckduckgo.com/?iar=images&q=" ""])
     ("Bing"           . [simple-query "www.bing.com" "www.bing.com/search?q=" ""])
     ("Google"         . [simple-query "https://www.google.com"
                                       "https://www.google.com/search?q=" ""])
     ("YouTube"        . [simple-query "https://www.youtube.com/feed/subscriptions"
                                       "https://www.youtube.com/results?search_query=" ""])
     ("Claude"         . [simple-query "https://claude.ai/new" "https://claude.ai/new?q=" ""])
     ("ChatGPT"        . [simple-query "https://chatgpt.com" "https://chatgpt.com/?q=" ""])
     ("Wikipedia"      . [simple-query "wikipedia.org" "wikipedia.org/wiki/" ""])))
  :config
  (defun my-webjump-eww (&optional arg)
    "Run `webjump' optionally forcing the internal browser (EWW)."
    (interactive "P")
    (require 'eww)
    (let ((webjump-use-internal-browser arg))
      (call-interactively #'webjump))))

(use-package grep
  :ensure nil
  :autoload grep-apply-setting
  :init
  (when (executable-find "rg")
    (grep-apply-setting
     'grep-command "rg --color=auto --null -nH --no-heading -e ")
    (grep-apply-setting
     'grep-template "rg --color=auto --null --no-heading -g '!*/' -e <R> <D>")
    (grep-apply-setting
     'grep-find-command "rg --color=auto --null -nH --no-heading -e '' .")
    (grep-apply-setting
     'grep-find-template "rg --color=auto --null -nH --no-heading -e <R> <D>")))

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
  (add-to-list 'rg-custom-type-aliases '("tmpl" . "*.tmpl"))

  (defun my-rg-current-dir-all (query)
    "Search QUERY in all files under current directory."
    (interactive "sSearch (all files): ")
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
    (text-scale-set -2)
    (calfw-refresh-calendar-buffer)))

(use-package gt
  :bind
  ("C-c t w" . my-translate-word)
  ("C-c t r" . my-translate-region)
  ("C-c t b" . my-translate-buffer)
  :custom
  (gt-default-translator
   (gt-translator
    :taker (gt-taker :langs '(en zh) :text 'word :prompt t)
    :engines (list (gt-youdao-dict-engine)
                   (gt-youdao-suggest-engine))
    :render (gt-buffer-render)))
  :custom-face (gt-overlay-source-face ((t nil)))
  :config
  (defvar my-gt--active nil)

  (defun my-gt-translate (&optional mode)
    (let ((gt-polyglot-p t))
      (gt-start
       (gt-translator
        :taker (gt-taker :langs '(en zh) :text mode)
        :engines (list (if (eq mode 'word)
                           (gt-youdao-dict-engine)
                         (gt-bing-engine)))
        :render (if (eq mode 'word)
                    (gt-buffer-render)
                  (gt-overlay-render))))))

  (defun my-gt-clear ()
    (dolist (ov (gt-overlay-render-get-overlays (point-min) (point-max)))
      (delete-overlay ov)))

  (defun my-gt-auto-translate (&optional mode)
    (setq my-gt--active (not my-gt--active))
    (if my-gt--active
        (my-gt-translate mode)
      (my-gt-clear)))

  (defun my-translate-word   () (interactive) (my-gt-auto-translate 'word))
  (defun my-translate-region () (interactive) (my-gt-auto-translate 'region))
  (defun my-translate-buffer () (interactive) (my-gt-auto-translate 'buffer)))

(use-package simple-mpv
  :ensure nil
  :custom (simple-mpv-debug nil)
  :bind
  (("C-c m" . simple-mpv-audio-browse)
   :map dired-mode-map
   ("C-c p" . simple-mpv-play-file)))

(use-package nn-license-template
  :ensure nil
  :defer nil
  :bind
  ("C-c l f" . nn-license-template-file)
  ("C-c l h" . nn-license-template-header))

(provide 'init-utils)
