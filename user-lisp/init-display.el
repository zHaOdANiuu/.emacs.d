;;; -*- lexical-binding: t -*-
(use-package material-icons
  :hook
  (dired-mode . material-icons-dired-icons-mode)
  (ibuffer-mode . material-icons-ibuffer-icons-mode)
  :init
  (setq material-icons-size 22)
  (with-eval-after-load 'speedbar
    (require 'material-icons-speedbar)
    (material-icons-speedbar-icons-mode 1)))

(use-package nerd-icons
  :commands
  (nerd-icons-octicon
   nerd-icons-faicon
   nerd-icons-flicon
   nerd-icons-wicon
   nerd-icons-mdicon
   nerd-icons-codicon
   nerd-icons-devicon
   nerd-icons-ipsicon
   nerd-icons-pomicon
   nerd-icons-powerline))

(use-package nerd-icons-corfu
  :after corfu
  :init
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)
  (setq
   nerd-icons-corfu-mapping
   `((array :style "cod" :icon "symbol_array" :face nerd-icons-lblue)
     (boolean :style "cod" :icon "symbol_boolean" :face nerd-icons-lcyan)
     (class :style "cod" :icon "symbol_class" :face nerd-icons-lorange)
     (color :style "cod" :icon "symbol_color" :face nerd-icons-lorange)
     (command :style "cod" :icon "terminal" :face nerd-icons-purple)
     (constant :style "cod" :icon "symbol_constant" :face nerd-icons-lsilver)
     (constructor :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (enummember :style "cod" :icon "symbol_enum_member" :face nerd-icons-lblue)
     (enum-member :style "cod" :icon "symbol_enum_member" :face nerd-icons-lblue)
     (enum :style "cod" :icon "symbol_enum" :face nerd-icons-lyellow)
     (event :style "cod" :icon "symbol_event" :face nerd-icons-lorange)
     (field :style "cod" :icon "symbol_field" :face nerd-icons-lblue)
     (file :style "cod" :icon "file" :face nerd-icons-lsilver)
     (folder :style "cod" :icon "folder" :face nerd-icons-lyellow)
     (interface :style "cod" :icon "symbol_interface" :face nerd-icons-lcyan)
     (keyword :style "cod" :icon "symbol_keyword" :face nerd-icons-lblue)
     (macro :style "cod" :icon "symbol_misc" :face nerd-icons-pink)
     (magic :style "cod" :icon "wand" :face nerd-icons-purple)
     (method :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (function :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (module :style "cod" :icon "json" :face nerd-icons-lyellow)
     (numeric :style "cod" :icon "symbol_numeric" :face nerd-icons-lcyan)
     (operator :style "cod" :icon "symbol_operator" :face nerd-icons-lblue)
     (param :style "cod" :icon "symbol_parameter" :face nerd-icons-lsilver)
     (property :style "cod" :icon "symbol_property" :face nerd-icons-lblue)
     (reference :style "cod" :icon "references" :face nerd-icons-lblue)
     (snippet :style "cod" :icon "symbol_snippet" :face nerd-icons-lgreen)
     (string :style "cod" :icon "symbol_string" :face nerd-icons-lmaroon)
     (struct :style "cod" :icon "symbol_structure" :face nerd-icons-lorange)
     (text :style "cod" :icon "text_size" :face nerd-icons-lsilver)
     (typeparameter :style "cod" :icon "list_unordered" :face nerd-icons-lcyan)
     (type-parameter :style "cod" :icon "list_unordered" :face nerd-icons-lcyan)
     (unit :style "cod" :icon "symbol_ruler" :face nerd-icons-lsilver)
     (value :style "cod" :icon "symbol_field" :face nerd-icons-lblue)
     (variable :style "cod" :icon "symbol_variable" :face nerd-icons-lblue))))

(use-package minibuffer-frame
  :hook window-setup)

(use-package fringe
  :ensure nil
  :custom
  (fringe-mode '(16 . nil))
  (indicate-buffer-boundaries nil)
  (overflow-newline-into-fringe nil)
  :config
  (setq-default fringes-outside-margins t)
  (setf (cdr (assq 'truncation fringe-indicator-alist)) '(nil nil)))

(use-package nn-fringe-scale
  ;; src url https://github.com/blahgeek/emacs-fringe-scale
  :ensure nil
  :no-require t
  :init
  (defgroup nn-fringe-scale nil
    "Scale fringe bitmap"
    :group 'nn-fringe-scale)

  (defcustom nn-fringe-scale-width 16
    "Target width when scaling fringe bitmaps."
    :type 'number
    :group 'nn-fringe-scale)

  (defun nn-fringe-scale--scale-width (x orig-width new-width)
    "Scale width of fringe bitmap."
    (let ((res 0) (i 0))
      (while (< i new-width)
        (let* ((j (floor (* orig-width (/ (float i) new-width))))
               (bit (logand 1 (lsh x (- j)))))
          (setq res (logior res (lsh bit i))))
        (setq i (1+ i)))
      res))

  (defun nn-fringe-scale--scale-height (v orig-height new-height)
    "Scale height of fringe bitmap."
    (let ((res (make-vector new-height nil)) (i 0))
      (while (< i new-height)
        (let* ((j (floor (* orig-height (/ (float i) new-height))))
               (val (elt v j)))
          (aset res i val))
        (setq i (1+ i)))
      res))

  (defun nn-fringe-scale--define-fringe-bitmap-advice (orig-func &rest r)
    "Advice for define-fringe-bitmap, scale the bitmap if required."
    (let* ((bitmap (nth 0 r))
           (bits (nth 1 r))
           (height (or (nth 2 r) (length bits)))
           (width (or (nth 3 r) 8))
           (align (or (nth 4 r) 'center)))
      (when (and (< width nn-fringe-scale-width))
        ;; (message "Scaling fringe bitmap %s: width %d to %d" bitmap width nn-fringe-scale-width)
        (let* ((new-width nn-fringe-scale-width)
               (new-height (floor (* height (/ (float new-width) width))))
               (bits-w-scaled (mapcar (lambda (x) (nn-fringe-scale--scale-width x width new-width)) bits))
               (bits-h-scaled (nn-fringe-scale--scale-height bits-w-scaled height new-height)))
          (setq bits bits-h-scaled)
          (setq height new-height)
          (setq width new-width)))
      (funcall orig-func bitmap bits height width align)))

  (define-minor-mode nn-fringe-scale-mode
    "Scale fringe bitmaps for HiDPI displays."
    :global t
    :init-value nil
    :group 'nn-fringe-scale
    (if nn-fringe-scale-mode
        (advice-add 'define-fringe-bitmap :around #'nn-fringe-scale--define-fringe-bitmap-advice)
      (advice-remove 'define-fringe-bitmap #'nn-fringe-scale--define-fringe-bitmap-advice)))

  (nn-fringe-scale-mode))

(use-package tooltip
  :ensure nil
  :custom (tooltip-resize-echo-area t))

(use-package display-fill-column-indicator
  :ensure nil
  :hook
  (emacs-startup . adjust-fill-column-indicator-stipple)
  (text-scale-mode . adjust-fill-column-indicator-stipple)
  :init
  (setq-default display-fill-column-indicator-character ?\s)

  (defun adjust-fill-column-indicator-stipple ()
    "Adjust the fill-column-indicator face with stipple using set-face-attribute."
    (let* ((w (window-font-width))
           (stipple `(,w 1 ,(apply #'unibyte-string (append (make-list (ash (1- w) -3) ?\0) '(1))))))
      (set-face-attribute 'fill-column-indicator nil :stipple stipple))))

(use-package display-line-numbers
  :ensure nil
  :hook
  (prog-mode text-mode conf-mode)
  ((org-mode markdown-mode markdown-ts-mode) . (lambda () (display-line-numbers-mode -1)))
  :custom
  (display-line-numbers-grow-only t)
  (display-line-numbers-width 3)
  (display-line-numbers-widen t))

(use-package paren
  :ensure nil
  :hook (prog-mode . show-paren-mode)
  :custom
  (show-paren-delay 0.1)
  (show-paren-highlight-openparen t)
  (show-paren-when-point-inside-paren t)
  (show-paren-when-point-in-periphery t)
  (show-paren-style 'parenthesis)
  (show-paren-context-when-offscreen 'overlay)
  (blink-matching-paren-highlight-offscreen t)
  :config
  (define-advice show-paren--show-context-in-overlay (:after (_text) no-box)
    (when show-paren--context-overlay
      (overlay-put show-paren--context-overlay
                   'face '(:inherit default :box nil :height 0.9)))))

(use-package whitespace
  :ensure nil
  :hook
  (before-save . delete-trailing-whitespace)
  (conf-mode
   emacs-lisp-mode
   simpcc-mode c-mode c++-mode
   js-mode js-json-mode json-ts-mode
   typescript-ts-mode tsx-ts-mode
   web-mode sh-mode powershell-mode
   makefile-mode makefile-gmake-mode)
  :custom
  (whitespace-line-column nil)
  (whitespace-style '(face indentation tabs tab-mark spaces space-mark))
  (whitespace-display-mappings
   '((space-mark ?\ [?·] [?.])
     (tab-mark ?\t [?→ ?\s])))
  :config
  ;; HACK: Suppress space display mapping marks in overlays.
  (set-face-attribute 'nobreak-space nil :underline nil)
  (define-advice overlay-put (:filter-args (args) nn-bypass-whitespace-display)
    (if-let* ((prop (nth 1 args))
              (val (nth 2 args))
              ((eq prop 'display))
              ((stringp val))
              ((string-search " " val)))
        `(,(car args) display ,(string-replace " " "\u00a0" val))
      args))
  ;; HACK: `whitespace-mode' inundates child frames with whitespace markers, so
  ;;   disable it to fix all that visual noise.
  (defun my-whitespace--in-parent-frame-p () (null (frame-parameter nil 'parent-frame)))
  (add-function :before-while whitespace-enable-predicate #'my-whitespace--in-parent-frame-p))

(use-package indent-bars
  :hook python-mode yaml-mode yaml-ts-mode
  :custom
  (indent-bars-display-on-blank-lines nil)
  (indent-bars-highlight-current-depth nil)
  (indent-bars-width-frac 0.2)
  ;; (indent-bars-color '(highlight :blend 0.4))
  (indent-bars-color '(highlight :face-bg t :blend 0.2))
  (indent-bars-zigzag nil)
  (indent-bars-pattern " "))

(use-package rainbow-delimiters
  :hook prog-mode)

(use-package olivetti
  :hook
  (gnus-article-mode
   eww-mode org-mode markdown-ts-mode)
  :custom (olivetti-mode-on-hook nil))

(use-package color-picker
  :vc (:url "https://github.com/zHaOdANiuu/color-picker.el" :rev :newest)
  :commands color-picker
  :custom (color-picker-scale 2.0))

(use-package colorful-mode
  :hook (prog-mode . colorful-mode)
  :custom
  (colorful-use-prefix t)
  (colorful-only-strings 'only-prog)
  :config
  (add-to-list 'global-colorful-modes 'helpful-mode)

  (with-eval-after-load 'web-mode
    (add-hook 'web-mode (lambda () (setq-local colorful-only-strings nil))))

  (when _GUI
    (require 'svg)

    (defun my-colorful--svg-img (color)
      (let* ((sz (frame-char-width))
             (svg (svg-create sz sz)))
        (svg-node svg 'rect
                  :x 1 :y 1 :width  (- sz 2) :height (- sz 2)
                  :fill color :stroke "#ffffff" :stroke-width "1.5")
        (svg-image svg :ascent 'center)))

    (defvar-keymap my-colorful--color-picker-map
      "<mouse-1>"
      (lambda (event)
        (interactive "e")
        (let* ((pos (event-start event))
               (xy  (posn-x-y pos))
               (ov  (colorful--find-overlay (posn-point pos))))
          (when ov
            (color-picker
             :style 'simple :display 'frame
             :x (car xy) :y (cdr xy)
             :ok (lambda (picked)
                   (with-current-buffer (overlay-buffer ov)
                     (delete-region (overlay-start ov) (overlay-end ov))
                     (insert picked)))) ))))

    (defun colorful--colorize-match (color beg end kind face map)
      "Overlay match with a face from BEG to END.
The background uses COLOR color value.  The foreground is obtained
from `readable-foreground-color'."
      (let ((ov (make-overlay beg end)))
        (overlay-put ov 'colorful--overlay t)
        (overlay-put ov 'colorful--color-kind kind)
        (overlay-put ov 'colorful--color color)
        (overlay-put ov 'evaporate t)
        (overlay-put ov
                     'before-string
                     (propertize
                      " "
                      'display (my-colorful--svg-img color)
                      'keymap my-colorful--color-picker-map
                      'pointer 'hand))
        (overlay-put ov 'face nil)))))

(use-package nn-mode-line
  :ensure nil
  :no-require t
  :hook ((prog-mode-hook text-mode-hook conf-mode-hook dired-mode-hook) . nn-mode-line-set)
  :init
  (defconst nn-mode-line--error   (nerd-icons-codicon   "nf-cod-error"))
  (defconst nn-mode-line--warning (nerd-icons-codicon   "nf-cod-warning"))
  (defconst nn-mode-line--info    (nerd-icons-codicon   "nf-cod-info"))
  (defconst nn-mode-line--git     (nerd-icons-powerline "nf-pl-branch"))

  (defun nn-mode-line--viper ()
    "Viper state, or nil when inactive."
    (when (bound-and-true-p viper-mode)
      (if mark-active "VISUAL"
        (pcase viper-current-state
          ('vi-state      "NORMAL")
          ('insert-state  "INSERT")
          ('replace-state "REPLACE")
          ('emacs-state   "EMACS")))))

  (defun nn-mode-line--vc ()
    "VC branch indicator."
    (concat
     nn-mode-line--git
     (if-let* ((root    (vc-root-dir))
               (backend (vc-responsible-backend root)))
         (let ((b (string-trim-left
                   (substring-no-properties
                    (vc-call-backend backend 'mode-line-string root))
                   "[A-Za-z]+[-:] ?")))
           (if (string-empty-p b) "?" b))
       "!")))

  (defun nn-mode-line--flymake ()
    "Flymake counts, or nil when off."
    (when (bound-and-true-p flymake-mode)
      (format
       "%s %d %s %d %s %d"
       nn-mode-line--error
       (string-to-number (format-mode-line flymake-mode-line-error-counter))
       nn-mode-line--warning
       (string-to-number (format-mode-line flymake-mode-line-warning-counter))
       nn-mode-line--info
       (string-to-number (format-mode-line flymake-mode-line-note-counter)))))

  (defun nn-mode-line--eglot ()
    "Eglot server name, or nil when not connected."
    (when (eglot-current-server)
      (pcase (alist-get major-mode eglot-server-programs)
        ((and (pred stringp) name) name)
        (`(,name . ,_)             name)
        (_                         "lsp"))))

  (defun nn-mode-line--position ()
    "Line:column, or nil when line numbers are off."
    (when display-line-numbers-mode
      (format "L%s C%s" (format-mode-line "%l") (format-mode-line "%c"))))

  (defun nn-mode-line--mode ()
    "Major mode name without the trailing \"-mode\"."
    (string-remove-suffix "-mode" (symbol-name major-mode)))

  (defun nn-mode-line-set ()
    "Install `nn-mode-line-format' in the current buffer."
    (setq-local mode-line-format nn-mode-line-format))

  (setq-default mode-line-format nil)

  (defconst nn-mode-line-format
    '("%e"
      "  " (:eval (nn-mode-line--viper))
      "  " (:eval (nn-mode-line--vc))
      "  " "%b"
      "  " (:eval (nn-mode-line--flymake))
      "  " (:eval (nn-mode-line--eglot))
      "  " mode-line-misc-info
      mode-line-format-right-align
      "  " (:eval (nn-mode-line--position))
      "  " (:eval (symbol-name buffer-file-coding-system))
      "  " (:eval (if current-input-method "C" "A"))
      "  " (:eval (nn-mode-line--mode))
      "  ")))

(provide 'init-display)
