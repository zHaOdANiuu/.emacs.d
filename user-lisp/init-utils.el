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
  (world-clock-sort-order "%FT%T")
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
