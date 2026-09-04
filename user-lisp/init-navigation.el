;;; -*- lexical-binding: t -*-
(use-package goto-addr
  :ensure nil
  :hook
  (prog-mode . goto-address-prog-mode)
  (text-mode . goto-address-prog-mode))

(use-package xref
  :autoload xref-show-definitions-completing-read
  :bind
  ("M-g ." . xref-find-definitions)
  ("M-g ," . xref-go-back)
  :custom
  (xref-search-program (if (executable-find "rg") 'ripgrep 'grep))
  (xref-show-definitions-function #'xref-show-definitions-completing-read)
  (xref-show-xrefs-function #'xref-show-definitions-completing-read))

(use-package bookmark
  :ensure nil
  :custom (bookmark-default-file (concat nn-directory "bookmark-default.el"))
  :config
  (define-advice bookmark-bmenu--revert (:after (&rest _) my-bookmark-bmenu--icons)
    "Prepend nerd-icons to bookmark names."
    (when (display-graphic-p)
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

(use-package citre
  :bind
  (("<f12>" . citre-jump)
   ("S-<f12>" . citre-jump-to-reference)
   ("M-<f12>" . citre-peek)
   :map citre-peek-keymap
   ("q" . keyboard-quit))
  :hook (prog-mode . citre-mode)
  :custom-face
  (citre-peek-border-face ((t :inherit font-lock-keyword-face :strike-through t :extend t)))
  :custom
  (citre-readtags-program "readtags")
  (citre-ctags-program "ctags")
  (citre-peek-fill-fringe nil)
  (citre-completion-case-sensitive t)
  (citre-imenu-create-tags-file-threshold (* 20 1024 1024))
  (citre-default-create-tags-file-location 'in-dir)
  (citre-edit-ctags-options-manually nil)
  (citre-auto-enable-citre-mode-backends-for-remote nil)
  :config
  (require 'citre-config)

  (add-to-list 'completion-category-overrides '(citre (styles basic)))

  (defvar-local nn-citre-external-tags nil
    "List of external tags files queried when the project tags returns nothing.")

  (define-advice citre-tags-get-tags (:around (old-fn tagsfile &rest args) nn-ext)
    "Fall back to `nn-citre-external-tags' when project tags returns nothing."
    (or (apply old-fn tagsfile args)
        (cl-loop for f in nn-citre-external-tags
                 for ext = (expand-file-name f)
                 when (file-exists-p ext)
                 thereis (apply old-fn ext args))))

  ;; ctags ext-kind-full → nerd-icons-corfu key
  ;; Also handles single-letter kind fallback.
  (defconst nn-lsp-kind
    '(("function" "function") ("method" "method") ("procedure" "function")
      ("submethod" "method") ("subprogram" "function") ("subroutine" "function")
      ("prototype" "function") ("functor" "function") ("callback" "function")
      ("class" "class") ("struct" "struct") ("structure" "struct")
      ("union" "struct") ("record" "class") ("component" "class")
      ("object" "class") ("role" "class")
      ("interface" "interface") ("trait" "interface") ("protocol" "interface")
      ("annotation" "interface") ("implementation" "class")
      ("enum" "enum") ("enumerator" "enummember")
      ("variable" "variable") ("local" "variable") ("global" "variable")
      ("parameter" "variable") ("instance" "variable") ("macroparam" "variable")
      ("field" "field") ("member" "field") ("slot" "field")
      ("property" "property") ("attribute" "property")
      ("constant" "constant") ("const" "constant")
      ("module" "module") ("namespace" "module") ("package" "module")
      ("library" "module") ("using" "module")
      ("type" "typeparameter") ("template" "typeparameter") ("tparam" "typeparameter")
      ("generic" "typeparameter") ("typedef" "keyword") ("alias" "keyword")
      ("name" "keyword") ("define" "macro") ("macro" "macro")
      ("constructor" "constructor") ("destructor" "constructor")
      ("event" "event") ("signal" "event") ("handler" "event")
      ("file" "file") ("header" "file") ("script" "file")
      ("label" "keyword") ("anchor" "keyword") ("key" "keyword")
      ("operator" "operator") ("string" "string") ("number" "numeric")
      ("boolean" "boolean") ("array" "array") ("exception" "class")))

  (define-advice citre-capf--make-candidate (:filter-return (cand) nn-kind)
    "Rewrite citre-kind to nerd-icons-corfu-compatible key."
    (when-let* ((raw (citre-get-property 'kind cand))
                (mapped (cadr (assoc-string (symbol-name raw) nn-lsp-kind 'case-fold))))
      (citre-put-property cand 'kind (intern mapped)))
    cand))

(provide 'init-navigation)
