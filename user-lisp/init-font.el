;;; -*- lexical-binding: t -*-

;; Font download link
;; [IBM Plex Mono](https://github.com/IBM/plex)
;; [LXGW WenKai Mono](https://github.com/lxgw/LxgwWenKai)
;; [Maple Mono](https://github.com/subframe7536/maple-font)
;; [Sarasa Mono SC](https://github.com/be5invis/Sarasa-Gothic)

(require 'cl-lib)

(unless nn-font-fallback
  (set-face-attribute 'default nil :family "Maple Mono NL NF CN" :height 146))

(when nn-font-fallback
  ;; Default
  (cl-loop for font in '("IBM Plex Mono" "Jetbrains Mono" "Cascadia Mono")
           when (find-font (font-spec :family font))
           return (set-face-attribute 'default nil :family font :height 146))
  ;; Unicode
  (cl-loop for font in '("Segoe UI" "Arial Unicode MS")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'unicode spec nil))
  ;; Chinese
  (cl-loop for font in '("LXGW WenKai Mono" "Noto Sans SC" "Sarasa Mono SC"
                         "Microsoft YaHei" "DengXian" "Simhei")
           for spec = (font-spec :family font)
           when (find-font (font-spec :family font))
           return (progn
                    (setq face-font-rescale-alist `((,font . 1.3)))
                    (set-fontset-font t 'han (font-spec :family font) nil 'prepend)))
  ;; Symbol
  (cl-loop for font in '("Segoe UI Symbol" "Apple Symbols" "Symbol")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'symbol spec nil 'prepend))
  ;; Emoji
  (cl-loop for font in '("Noto Color Emoji" "Segoe UI Emoji" "Apple Color Emoji")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'emoji spec nil 'prepend))
  ;; Extra
  (cl-loop for font in '("Maple Mono NL NF CN" "Jetbrains Mono")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (cl-loop for char in '(?┌ ?─ ?│ ?├ ?╰ ?►)
                           do (set-fontset-font t char spec nil 'prepend)))
  ;; Greek letters
  (set-fontset-font t '(#x0370 . #x03FF) (face-attribute 'default :family)))

(when nn-font-ligatures
  (cl-loop for chars in '("::" "..." "->" "=>" "<=" ">=" "!==" "!=" "===" "==")
           for key = (aref chars 0)
           do (set-char-table-range
               composition-function-table  key
               (nconc (char-table-range composition-function-table key)
                      `(,(vector (regexp-quote chars) 0 'font-shape-gstring))))))

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
