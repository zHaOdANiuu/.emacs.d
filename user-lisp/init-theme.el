;;; -*- lexical-binding: t -*-
(defun nn-theme-init ()
  (require 'nn-world-theme)
  (load-theme 'nn-world t))

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

(provide 'init-theme)
