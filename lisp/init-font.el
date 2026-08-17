;;; -*- lexical-binding: t -*-

;; Font download link
;; [IBM Plex Mono](https://github.com/IBM/plex)

(when (display-graphic-p)
  ;; Default
  (cl-loop for font in '("IBM Plex Mono" "Jetbrains Mono" "Cascadia Code")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-face-attribute 'default nil :family font :height 150))
  ;; Unicode
  (cl-loop for font in '("Segoe UI" "Arial Unicode MS")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'unicode spec))
  ;; Chinese
  (cl-loop for font in '("Sarasa Term SC Nerd" "Microsoft YaHei" "DengXian" "Simhei")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'han spec nil 'prepend))
  ;; Symbol
  (cl-loop for font in '("Segoe UI Symbol" "Apple Symbols" "Symbola" "Symbol")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'symbol spec nil 'prepend))
  ;; Emoji
  (cl-loop for font in '("Noto Color Emoji" "Segoe UI Emoji" "Apple Color Emoji")
           for spec = (font-spec :family font)
           when (find-font spec)
           return (set-fontset-font t 'emoji spec nil 'prepend))
  ;; Greek alphabet
  (set-fontset-font t '(#x0370 . #x03FF) (face-attribute 'default :family)))

;; If your font supports ligatures, uncomment it
;; (cl-loop for chars in '("::" "..." "->" "=>" "<=" ">=" "!==" "!=" "===" "==")
;;          for key = (aref chars 0)
;;          do (set-char-table-range
;;              composition-function-table  key
;;              (nconc (char-table-range composition-function-table key)
;;                     `(,(vector (regexp-quote chars) 0 'font-shape-gstring)))))

(provide 'init-font)
