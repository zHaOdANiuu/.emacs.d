;;; -*- lexical-binding: t -*-
(use-package ol
  :ensure nil
  :config
  (org-link-set-parameters
   "file"
   :face
   (lambda (path)
     (if (or (if (eq system-type 'windows-nt)
                 (string-prefix-p "//" path))
             (file-remote-p path)
             (if (eq system-type 'windows-nt)
                 (string-prefix-p "\\\\" path))
             (file-exists-p path))
         'org-link
       '(warning org-link)))))

(use-package org
  :ensure nil
  :bind
  (("C-c o a" . org-agenda)
   ("C-c o b" . org-switchb)
   ("C-c o x" . org-capture)
   (:map org-mode-map
    ("C-c C-S-l"    . org-toggle-link-display)
    ("C-<return>"   . org-insert-heading-respect-content)
    ("C-S-<return>" . org-insert-todo-heading-respect-content)
    ("C-M-<return>" . org-insert-subheading)
    ("C-c '"        . org-edit-special)
    ("C-c C-,"      . org-insert-structure-template)
    ("C-c C-t"      . org-todo)
    ("C-c C-q"      . org-set-tags-command)
    ("C-c C-d"      . org-deadline)
    ("C-c C-s"      . org-schedule)
    ("C-c ."        . org-time-stamp)
    ("C-c !"        . org-time-stamp-inactive)
    ("C-c C-o"      . org-open-at-point)
    ("C-c @"        . org-cite-insert)
    ("C-c *"        . org-ctrl-c-star)
    ("C-c -"        . org-ctrl-c-minus)
    ("C-c C-x e"    . org-export-dispatch)
    ("C-c C-x C-w"  . org-cut-subtree)
    ("C-c C-x C-a"  . org-archive-subtree-default)))
  :hook ((org-babel-after-execute org-mode) . org-redisplay-inline-images)
  :custom
  (org-persist-directory (concat nn-directory "org/persist/"))
  (org-id-locations-file (concat nn-directory "org/id-locations.el"))
  (org-publish-timestamp-directory (concat nn-directory "org/timestamps/"))
  (org-modules nil)
  (org-support-shift-select t)
  (org-auto-align-tags nil)
  (org-log-done 'time)
  (org-pretty-entities t)
  (org-ellipsis nn-fold-string)
  (org-enforce-todo-dependencies t)
  (org-tags-column 0)
  (org-confirm-babel-evaluate nil)
  (org-catch-invisible-edits 'show-and-error)
  (org-hide-emphasis-markers t)
  (org-hide-leading-stars t)
  (org-image-actual-width nil)
  (org-special-ctrl-a/e t)
  (org-M-RET-may-split-line nil)
  (org-insert-heading-respect-content t)
  (org-indirect-buffer-display 'current-window)
  (org-fontify-done-headline t)
  (org-fontify-quote-and-verse-blocks t)
  (org-fontify-whole-heading-line t)
  (org-src-tab-acts-natively t)
  (org-src-fontify-natively t)
  (org-startup-indented t)
  (org-startup-folded nil)
  (org-use-sub-superscripts '{})
  (org-todo-keywords
   '((sequence
      "TODO(t)" "PROJ(p)" "LOOP(r)" "STRT(s)"
      "WAIT(w)" "HOLD(h)" "IDEA(i)"
      "|" "DONE(d)" "KILL(k)")
     (sequence
      "[ ](T)" "[-](S)" "[?](W)"
      "|" "[X](D)")
     (sequence
      "|" "OKAY(o)" "YES(y)" "NO(n)")))
  (org-babel-load-languages
   '((emacs-lisp . t) (python . t)
     (shell . t) (perl . t)
     (C . t) (java . t)
     (js . t) (css . t)
     (plantuml . t)))
  :config
  (add-to-list 'org-export-backends 'md)
  (add-to-list 'org-structure-template-alist '("n" . "note"))
  (add-to-list 'org-tags-exclude-from-inheritance "crypt")
  (add-to-list 'org-file-apps
               '("\\.\\(x?html?\\|pdf\\)\\'"  .
                 (lambda (file _link)
                   (centaur-browse-url-of-file (browse-url-file-url file)))))

  (dolist (abbrev '(("github"     . "https://github.com/%s")
                    ("youtube"    . "https://youtube.com/watch?v=%s")
                    ("google"     . "https://google.com/search?q=")
                    ("gimages"    . "https://google.com/images?q=%s")
                    ("gmap"       . "https://maps.google.com/maps?q=%s")
                    ("kagi"       . "https://kagi.com/search?q=%s")
                    ("duckduckgo" . "https://duckduckgo.com/?q=%s")
                    ("wikipedia"  . "https://en.wikipedia.org/wiki/%s")
                    ("wolfram"    . "https://wolframalpha.com/input/?i=%s")
                    ("emacsdir"   . ,(expand-file-name "%s" user))))
    (add-to-list 'org-link-abbrev-alist abbrev)))

(use-package org-agenda
  :ensure nil
  :bind
  (:map org-agenda-mode-map
   ("t" . org-agenda-todo)
   ("r" . org-agenda-refile)
   ("q" . org-agenda-set-tags)
   ("d" . org-agenda-deadline)
   ("s" . org-agenda-schedule)
   ("C-SPC" . org-agenda-show-and-scroll-up))
  :custom
  (org-agenda-files '("~/agenda.org"))
  (org-agenda-window-setup 'current-window)
  (org-agenda-skip-unavailable-files t)
  (org-agenda-span 10)
  (org-agenda-start-on-weekday nil)
  (org-agenda-start-day "-3d")
  (org-agenda-inhibit-startup t))

(use-package org-src
  :ensure nil
  :custom (org-src-preserve-indentation t))

(use-package org-capture
  :ensure nil
  :custom
  (org-capture-templates
   `(("i" "Idea" entry (file ,(concat org-directory "/idea.org"))
      "*  %^{Title} %?\n%U\n%a\n")
     ("t" "Todo" entry (file ,(concat org-directory "/gtd.org"))
      "* TODO %?\n%U\n%a\n" :clock-in t :clock-resume t)
     ("n" "Note" entry (file ,(concat org-directory "/note.org"))
      "* %? :NOTE:\n%U\n%a\n" :clock-in t :clock-resume t)
     ("j" "Journal" entry (file+olp+datetree
                           ,(concat org-directory "/journal.org"))
      "*  %^{Title} %?\n%U\n%a\n" :clock-in t :clock-resume t)
     ("b" "Book" entry (file+olp+datetree
                        ,(concat org-directory "/book.org"))
      "* Topic: %^{Description} %^g %? Added: %U"))))

(use-package org-entities
  :ensure nil
  :custom
  (org-entities-user
   '(("flat"  "\\flat" nil "" "" "266D" "♭")
     ("sharp" "\\sharp" nil "" "" "266F" "♯"))))

(use-package org-clock
  :ensure nil
  :commands org-clock-save
  :custom
  (org-clock-persist-file (concat nn-directory "org/clock-persist.el"))
  (org-clock-persist 'history)
  (org-clock-in-resume t)
  (org-clock-out-remove-zero-time-clocks t)
  :config
  (add-hook 'kill-emacs-hook #'org-clock-save)
  (dolist (cmd '(org-clock-in org-clock-out org-clock-goto org-clock-cancel))
    (advice-add cmd :before #'org-clock-load)))

(use-package org-crypt
  :ensure nil
  :config (org-crypt-use-before-save-magic))

(use-package org-faces
  :ensure nil
  :custom
  (org-priority-faces
   '((?A . error)
     (?B . warning)
     (?C . success)))
  (org-agenda-deadline-faces
   '((1.0 . error)
     (1.0 . org-warning)
     (0.5 . org-upcoming-deadline)
     (0.0 . org-upcoming-distant-deadline))))

(use-package org-modern
  :hook
  (org-mode . org-modern-mode)
  (org-agenda-finalize . org-modern-agenda)
  :custom
  (org-modern-table t)
  (org-modern-table-vertical 1)
  (org-modern-table-horizontal 1)
  (org-modern-star 'replace)
  (org-modern-replace-stars "◉⦿⊚⊙∘"))

(provide 'lang-org)
