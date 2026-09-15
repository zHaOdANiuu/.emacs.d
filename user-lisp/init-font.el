;;; -*- lexical-binding: t -*-

;; Font download link
;; [IBM Plex Mono](https://github.com/IBM/plex)
;; [Iosevka SS13](https://github.com/be5invis/Iosevka)
;; [LXGW WenKai Mono](https://github.com/lxgw/LxgwWenKai)
;; [Maple Mono](https://github.com/subframe7536/maple-font)
;; [Sarasa Mono SC](https://github.com/be5invis/Sarasa-Gothic)

(require 'cl-lib)

(defun nn-font-init ()
  ;; Default
  (cl-loop for font in '("IBM Plex Mono" "JetBrains Mono" "Iosevka SS13" "Cascadia Mono")
           when (find-font (font-spec :family font))
           return (set-face-attribute 'default nil :family font :height 140))
  ;; Unicode
  (cl-loop for font in '("Segoe UI" "Arial Unicode MS")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'unicode spec nil))
  ;; Chinese
  (cl-loop for font in '("LXGW WenKai Mono" "Sarasa Mono SC"
                         "Microsoft YaHei" "DengXian" "Simhei")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (progn
                    (add-to-list 'face-font-rescale-alist (cons font 1.3))
                    (set-fontset-font t 'han spec)))
  ;; Symbol
  (cl-loop for font in '("Segoe UI Symbol" "Apple Symbols" "Symbol")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'symbol spec))
  ;; Emoji
  (cl-loop for font in '("Segoe UI Emoji" "Apple Color Emoji" "Noto Color Emoji")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'emoji spec nil 'prepend))
  ;; Nerd Fonts
  (cl-loop for font in '("Symbols Nerd Font Mono")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (progn
                    (set-fontset-font t '(#xe000 . #xf8ff) spec)
                    (set-fontset-font t '(#xf0000 . #xfffff) spec)))
  ;; Extra
  (cl-loop for font in '("Maple Mono NL NF CN")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (progn
                    (add-to-list 'face-font-rescale-alist (cons font 0.95))
                    (cl-loop for char in '(?λ ?┌ ?─ ?│ ?├ ?╰ ?►)
                             do (set-fontset-font t char spec nil 'prepend))))
  ;; Font Ligature
  ;; (cl-loop for chars in '("::" "..." "->" "=>" "<=" ">=" "!==" "!=" "===" "==")
  ;;          for key = (aref chars 0)
  ;;          do (set-char-table-range
  ;;              composition-function-table  key
  ;;              (nconc (char-table-range composition-function-table key)
  ;;                     `(,(vector (regexp-quote chars) 0 'font-shape-gstring)))))
  )

(defun nn-print-install-font ()
  (interactive)
  (with-current-buffer (scratch-buffer)
    (let ((sorted
           (sort (delete-dups (delete "" (font-family-list)))
                 #'string<))
          prev)
      (dolist (f sorted)
        (unless (and prev (string-prefix-p (concat prev " ") f))
          (insert f "\n")
          (setq prev f))))
    (goto-char (point-min))))

(provide 'init-font)
