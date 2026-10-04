;;; -*- lexical-binding: t -*-
(use-package goto-addr
  :ensure nil
  :hook
  (prog-mode . goto-address-prog-mode)
  (text-mode . goto-address-prog-mode))

(use-package elec-pair
  :ensure nil
  :hook (nn-first-input . electric-pair-mode)
  :custom
  (electric-pair-open-newline-between-pairs t)
  (electric-pair-inhibit-predicate 'electric-pair-conservative-inhibit))

(use-package subword
  :ensure nil
  :hook
  (java-mode
   js-mode typescript-ts-mode tsx-ts-mode
   csharp-mode c++-mode simpcc-mode go-mode)
  ((c-mode python-mode rust-mode) . superword-mode))

(use-package delsel
  :ensure nil
  :hook (nn-first-input . delete-selection-mode))

(use-package so-long
  :ensure nil
  :hook (nn-first-file . global-so-long-mode)
  :custom (so-long-threshold 5000)
  :config
  (add-to-list 'so-long-target-modes 'conf-mode)
  (add-to-list 'so-long-target-modes 'text-mode)
  (add-to-list 'so-long-variable-overrides '(font-lock-maximum-decoration . 1))
  (add-to-list 'so-long-variable-overrides '(save-place-alist . nil))
  (cl-callf2 delq 'font-lock-mode so-long-minor-modes)
  (cl-callf2 delq 'display-line-numbers-mode so-long-minor-modes)
  (setf (alist-get 'buffer-read-only so-long-variable-overrides nil t) nil)
  (setq so-long-function #'turn-on-so-long-minor-mode
        so-long-revert-function #'turn-off-so-long-minor-mode))

(use-package hideshow-savefold
  :ensure nil
  :hook prog-mode
  :custom (hideshow-savefold-directory (concat nn-directory "hideshow-savefold")))

(use-package hideshow
  :ensure nil
  :bind
  (:map hs-minor-mode-map
   ("C-c [" . hs-show-all)
   ("C-c ]" . my-hs-hide-level)
   ("S-<return>" . hs-toggle-hiding)
   ("<TAB>" . my-hs-tab))
  :hook
  (prog-mode . hs-minor-mode)
  ((conf-mode
    js-json-mode json-ts-mode
    python-mode python-ts-mode
    yaml-ts-mode sh-mode)
   . hs-indentation-mode)
  ((powershell-mode
    simpcc-mode c-mode c++-mode
    js-mode typescript-ts-mode tsx-ts-mode)
   . (lambda () (setq-local hs-adjust-block-end-function (lambda (p) (1- (line-beginning-position))))))
  :custom
  (hs-allow-nesting t)
  (hs-hide-comments-when-hiding-all nil)
  (hs-set-up-overlay #'my-hs-set-up-overlay)
  :custom-face (hs-ellipsis ((t :inherit nn-ellipsis)))
  :config
  (setq hs-special-modes-alist
        '((web-mode "<!--\\|<[^/>]*[^/]>"
           "-->\\|</[^/>]*[^/]>"
           "<!--" sgml-skip-tag-forward nil)
          (t)))

  (defun my-hs-hide-level ()
    (interactive)
    (hs-hide-level 0))

  (defun my-hs-set-up-overlay (ov)
    (when (eq 'code (overlay-get ov 'hs))
      (overlay-put ov 'face 'hs-ellipsis)
      (overlay-put ov 'display nn-ellipsis)))

  (defun my-hs-tab ()
    (interactive)
    (if (and (not (use-region-p))
             (or (hs-already-hidden-p)
                 (hs-hideable-block-p t)))
        (hs-cycle)
      (indent-for-tab-command))))

(use-package outline
  :ensure nil
  :bind
  (:map outline-minor-mode-map
   ("S-<return>" . outline-toggle-children)
   ("C-c [" . outline-show-all)
   ("C-c ]" . outline-hide-body)
   ("<TAB>" . outline-cycle))
  :hook (outline-minor-mode . my-outline-set-buffer-local-ellipsis)
  :config
  ;; https://www.jamescherti.com/emacs-customize-ellipsis-outline-minor-mode/
  (defun my-outline-set-buffer-local-ellipsis ()
    (let* ((display-table (or buffer-display-table (make-display-table)))
           (face-offset (* (face-id 'shadow) (ash 1 22)))
           (value (vconcat (mapcar (lambda (c) (+ face-offset c))
                                   (string-trim-right nn-ellipsis)))))
      (set-display-table-slot display-table 'selective-display value)
      (setq buffer-display-table display-table))))

(use-package ispell
  :ensure nil
  :custom
  (ispell-program-name (executable-find "aspell"))
  (ispell-local-dictionary "en_US")
  (ispell-extra-args '("--sug-mode=ultra" "--lang=en_US" "--run-together"))
  (ispell-alternate-dictionary nil)
  :config
  (add-to-list 'ispell-skip-region-alist '(":\\(PROPERTIES\\|LOGBOOK\\):" . ":END:"))
  (add-to-list 'ispell-skip-region-alist '("#\\+BEGIN_SRC" . "#\\+END_SRC"))
  (add-to-list 'ispell-skip-region-alist '("#\\+BEGIN_EXAMPLE" . "#\\+END_EXAMPLE"))
  (ispell-set-spellchecker-params))

(use-package flyspell
  :ensure nil
  :bind
  (:map flyspell-mode-map
   ("C-," . nil)
   ("C-M-," . flyspell-goto-next-error))
  :hook (org-mode markdown-ts-mode git-commit-setup)
  :custom
  (flyspell-check-changes t)
  (flyspell-issue-message-flag nil)
  (flyspell-issue-welcome-flag nil))

(use-package flymake
  :ensure nil
  :bind
  (:map flymake-mode-map
   ("<f8>" . flymake-goto-next-error)
   ("<S-f8>" . flymake-goto-prev-error)
   ("<C-f8>" . flymake-show-buffer-diagnostics))
  :hook (flymake-mode . (lambda () (setq-local next-error-function #'flymake-goto-next-error)))
  :custom
  (flymake-no-changes-timeout nil)
  (flymake-wrap-around nil)
  (flymake-fringe-indicator-position nil)
  (flymake-margin-indicators-string
   '((error "" compilation-error)
     (warning "" compilation-warning)
     (note "" compilation-info)))
  (flymake-show-diagnostics-at-end-of-line t)
  :config
  (setq-default next-error-find-buffer-function #'next-error-buffer-unnavigated-current)

  (define-advice elisp-flymake-byte-compile (:before-while (&rest _) check-git-repo)
    "Only enable elisp flymake if inside a git repo."
    (locate-dominating-file default-directory ".git"))

  ;; saveing check
  (cl-defmethod eglot-handle-notification :after
    (_server (_method (eql textDocument/publishDiagnostics)) &key uri
             &allow-other-keys)
    (when-let* ((buffer (find-buffer-visiting (eglot-uri-to-path uri))))
      (with-current-buffer buffer
        (if (and (eq nil flymake-no-changes-timeout)
                 (not (buffer-modified-p)))
            (flymake-start t))))))

(use-package editorconfig
  :ensure nil
  :hook nn-first-file
  :custom
  (editorconfig-trim-whitespaces-mode t)
  (editorconfig-get-properties-function #'editorconfig-get-properties))

(use-package apheleia
  :bind ("<f1>" . apheleia-format-buffer)
  :hook (apheleia-inhibit-functions . my-apheleia-inhibit-p)
  :custom (apheleia-log-only-errors t)
  :config
  (add-to-list 'apheleia-mode-alist '(sh-mode . shfmt))
  (add-to-list 'apheleia-mode-alist '(simpcc-mode . clang-format))
  (add-to-list 'apheleia-mode-alist '(cuda-mode . clang-format))
  (add-to-list 'apheleia-mode-alist '(protobuf-mode . clang-format))

  (dolist (formatter
           '(prettier prettier-css prettier-html prettier-javascript
             prettier-json prettier-scss prettier-svelte
             prettier-typescript prettier-yaml))
    (setf (alist-get formatter apheleia-formatters)
          '("prettier" "--stdin-filepath"
            (or (apheleia-formatters-local-buffer-file-name)
                (apheleia-formatters-mode-extension)
                ".js")))))

(use-package dabbrev
  :ensure nil
  :custom
  (dabbrev-case-replace nil)
  (dabbrev-downcase-means-case-replace nil)
  (dabbrev-case-distinction nil))

(use-package xref
  :autoload xref-show-definitions-completing-read
  :bind
  ("M-g ." . xref-find-definitions)
  ("M-g ," . xref-go-back)
  :custom
  (xref-search-program 'ripgrep)
  (xref-show-definitions-function #'xref-show-definitions-completing-read)
  (xref-show-xrefs-function #'xref-show-definitions-completing-read))

(use-package citre
  :bind
  (("<f12>" . citre-jump)
   ("S-<f12>" . citre-jump-to-reference)
   ("M-<f12>" . citre-peek)
   :map citre-peek-keymap
   ("q" . keyboard-quit))
  :custom-face
  (citre-peek-border-face ((t :inherit font-lock-keyword-face :strike-through t :extend t)))
  :custom
  (citre-readtags-program (executable-find "readtags"))
  (citre-ctags-program (executable-find "ctags"))
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

(use-package eglot
  :ensure nil
  :bind
  ("<f2>" . eglot-rename)
  ("<f12>" . xref-find-definitions)
  ("S-<f12>" . xref-find-references)
  ("C-<f12>" . eglot-find-implementation)
  ("C-S-<f12>" . eglot-find-typeDefinition)
  ("C-." . eglot-code-action-quickfix)
  :custom
  (eglot-autoshutdown t)
  (eglot-code-action-indications '(left-fringe))
  (eglot-events-buffer-config '(:size 0 :format 'short))
  (eglot-documentation-renderer 'markdown-ts-view-mode)
  (eglot-ignored-server-capabilities
   '(:inlayHintProvider
     :documentHighlightProvider
     :foldingRangeProvider))
  (jsonrpc-event-hook nil)
  :config
  (define-fringe-bitmap 'eglot--fringe-action
    [#b0000000000000000
     #b0000001111000000
     #b0000111111110000
     #b0001111111111000
     #b0001100000011000
     #b0001100100011000
     #b0001100110011000
     #b0001100000011000
     #b0001111111111000
     #b0000111111110000
     #b0000111111100000
     #b0000001111000000
     #b0000001111000000
     #b0000001111000000
     #b0000001111000000
     #b0000000000000000]
    16 16 'center)

  ;; ignore jsonrpc log
  (fset #'jsonrpc--log-event #'ignore))

(use-package yasnippet
  :hook
  (nn-first-input . yas-global-mode)
  (yas-minor-mode . my-completion-add-yas-capf-h)
  :init (setq yas-verbosity 2)
  :config
  (defun my-yas-capf ()
    (when (thing-at-point-looking-at "\\(?:\\sw\\|\\s_\\)+")
      (let ((keys (delete-dups
                   (mapcan (lambda (tbl)
                             (copy-sequence (hash-table-keys (yas--table-hash tbl))))
                           (yas--get-snippet-tables)))))
        (when keys
          (list
           (match-beginning 0) (match-end 0) keys
           :company-kind (lambda (_) 'snippet)
           :exit-function (lambda (_ status)
                            (when (string= status "finished")
                              (yas-expand))))))))

  (defun my-completion-add-yas-capf-h ()
    (add-hook 'completion-at-point-functions #'my-yas-capf 30 t)))

(use-package icomplete
  :ensure nil
  :bind ("C-x C-r" . my-recentf-open)
  :custom
  (icomplete-max-delay-chars 2)
  (icomplete-hide-common-prefix nil)
  (icomplete-tidy-shadowed-file-names t)
  (icomplete-show-matches-on-no-input nil)
  :config
  (fido-mode 1)
  (fido-vertical-mode 1)
  (defun my-recentf-open ()
    (interactive)
    (let ((file (completing-read "Find recent file: " recentf-list nil t)))
      (if (and file (file-exists-p file))
          (find-file file)
        (message "File open failed")))))

(use-package completion-preview
  :ensure nil
  :bind
  (:map completion-preview-active-mode-map
   ("C-n" . completion-preview-next-candidate)
   ("C-p" . completion-preview-prev-candidate)
   ("C-<down>" . completion-preview-next-candidate)
   ("C-<up>" . completion-preview-next-candidate)
   ("C-l" . (lambda () (interactive)
              (completion-preview-hide)
              (completion-preview-next-candidate))))
  :hook text-mode
  :custom
  (completion-preview-ignore-case t)
  (completion-preview-minimum-symbol-length nil)
  (completion-preview-completion-styles '(basic partial-completion initials orderless)))

(use-package corfu
  :bind
  (:map corfu-map
   ([tab] . corfu-complete)
   ([backtab] . corfu-previous)
   ("<return>" . corfu-complete)
   ("<escape>" . corfu-quit)
   ("S-SPC" . corfu-insert-separator))
  :hook prog-mode
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0)
  (corfu-auto-prefix 2)
  (corfu-auto-commands
   '("self-insert-command\\'"
     c-electric-colon c-electric-lt-gt
     c-electric-slash c-scope-operator
     lispy-colon))
  (corfu-preselect 'first)
  (corfu-quit-at-boundary nil)
  (corfu-quit-no-match t)
  (corfu-preview-current nil)
  (corfu-count 12)
  (corfu-max-width 120)
  (corfu-left-margin-width 0)
  (corfu-right-margin-width 0)
  (global-corfu-minibuffer nil)
  (global-corfu-modes '((not erc-mode help-mode gud-mode) t))
  :config
  (with-eval-after-load 'corfu
    (defun my-close-multiple-cursors-corfu ()
      (if multiple-cursors-mode
          (corfu-mode -1)
        (corfu-mode 1)))
    (add-hook 'multiple-cursors-mode-hook #'my-close-multiple-cursors-corfu))

  ;; HACK: If you want to update the visual hints after completing minibuffer
  ;;   commands with Corfu and exiting, you have to do it manually.
  (define-advice exit-minibuffer
      (:before () my-corfu--insert-before-exit-minibuffer-a)
    (when (or (and (frame-live-p corfu--frame)
                   (frame-visible-p corfu--frame))
              (and (featurep 'corfu-terminal)
                   (popon-live-p corfu-terminal--popon)))
      (when (member isearch-lazy-highlight-timer timer-idle-list)
        (apply (timer--function isearch-lazy-highlight-timer)
               (timer--args isearch-lazy-highlight-timer)))
      (when (member (bound-and-true-p anzu--update-timer) timer-idle-list)
        (apply (timer--function anzu--update-timer)
               (timer--args anzu--update-timer)))
      (when (member (bound-and-true-p evil--ex-search-update-timer)
                    timer-idle-list)
        (apply (timer--function evil--ex-search-update-timer)
               (timer--args evil--ex-search-update-timer)))))

  ;; HACK: If your dictionaries aren't set up in text-mode buffers, ispell will
  ;;   continuously pester you about errors. This ensures it only happens once
  ;;   per session.
  (define-advice ispell-completion-at-point
      (:around (fn &rest args) my-corfu--auto-disable-ispell-capf-a )
    "If ispell isn't properly set up, only complain once per session."
    (condition-case-unless-debug e
        (apply fn args)
      ('error
       (message "Error: %s" (error-message-string e))
       (message "Auto-disabling `text-mode-ispell-word-completion'")
       (setq text-mode-ispell-word-completion nil)
       (remove-hook 'completion-at-point-functions #'ispell-completion-at-point t)))))

(use-package corfu-popupinfo
  :ensure nil
  :bind
  (:map corfu-map
   ("M-p" . my-corfu-popupinfo-toggle)
   ("M-1" . corfu-popupinfo-scroll-up)
   ("M-2" . corfu-popupinfo-scroll-down))
  :custom (corfu-popupinfo-delay '(0 . 0.2))
  :config
  (defun my-corfu-popupinfo-toggle ()
    (interactive)
    (corfu-popupinfo-mode (not corfu-popupinfo-mode)))

  (define-advice corfu-quit (:after (&rest _) my-corfu-popupinfo-quit)
    (when corfu-popupinfo-mode
      (corfu-popupinfo-mode -1))))

(use-package symbol-overlay
  :bind
  ("M-n" . symbol-overlay-jump-next)
  ("M-p" . symbol-overlay-jump-prev)
  ("M-r" . symbol-overlay-rename)
  :hook prog-mode
  :custom (symbol-overlay-idle-time 0.5))

(use-package multiple-cursors
  :bind
  (("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   ("C-M->" . mc/skip-to-next-like-this)
   ("C-M-<" . mc/skip-to-previous-like-this)
   :map mc/keymap
   ("C-c M-w" . my-mc/copy)
   ("C-c C-w" . my-mc/cat)
   ("C-;" . mc/vertical-align-with-space)
   ("<escape>" . multiple-cursors-mode))
  :hook (nn-first-input . multiple-cursors-mode)
  :custom
  (mc/always-run-for-all t)
  (mc/list-file (concat nn-directory ".mc-lists.el"))
  :config
  (add-to-list 'mc--default-cmds-to-run-once #'swiper-mc)

  (defun my-mc/get-line-with-indent (beg end)
    (save-excursion
      (goto-char beg)
      (concat (buffer-substring-no-properties (line-beginning-position) beg)
              (buffer-substring-no-properties beg end))))

  (defun my-mc/lines-get ()
    (let ((pairs
           `(,`(,(region-beginning) ,(region-end)
                ,(my-mc/get-line-with-indent
                  (region-beginning) (region-end))))))
      (mc/for-each-fake-cursor
       cursor
       (let* ((pt (marker-position (overlay-get cursor 'point)))
              (mk (marker-position (overlay-get cursor 'mark)))
              (beg (min pt mk))
              (end (max pt mk)))
         (push `(,beg ,end ,(my-mc/get-line-with-indent beg end))
               pairs)))
      (sort pairs (lambda (a b) (< (nth 0 a) (nth 0 b))))))

  (defun my-mc/copy ()
    (interactive)
    (kill-new (string-join (mapcar (lambda (r) (nth 2 r)) (my-mc/lines-get)) "\n"))
    (mc/keyboard-quit)
    (multiple-cursors-mode -1))

  (defun my-mc/cat ()
    (interactive)
    (let ((pairs (my-mc/lines-get)))
      (kill-new (string-join (mapcar (lambda (r) (nth 2 r)) pairs) "\n"))
      (dolist (r (reverse pairs))
        (delete-region (nth 0 r) (nth 1 r)))
      (mc/keyboard-quit)
      (multiple-cursors-mode -1))))

(use-package viper
  :ensure nil
  :if nn-vim-mode
  :bind
  (:map viper-vi-global-user-map
   ;; Movements by references and LSP
   ("gd" . xref-find-references)
   ("SPC c a" . eglot-code-actions)
   ("SPC s g" . project-find-regexp)
   ("SPC s f" . project-find-file)
   ;; Map `C-w` followed by specific keys to window commands in Viper
   ("C-w s" . viper-window-split-horizontally)
   ("C-w v" . viper-window-split-vertically)
   ("C-w c" . viper-window-close)
   ("C-w o" . viper-window-maximize)
   ;; Add navigation commands to mimic Vim's `C-w hjkl`
   ("C-w h" . windmove-left)
   ("C-w l" . windmove-right)
   ("C-w k" . windmove-up)
   ("C-w j" . windmove-down)
   ;; Indent region
   ("==" . indent-region)
   ;; Word spelling
   ("z=" . ispell-word)
   ;; Keybindings for buffer navigation and switching in Viper mode
   ("] b" . next-buffer)
   ("[ b" . previous-buffer)
   ("b l" . switch-to-buffer)
   ("SPC SPC" . switch-to-buffer))
  :init
  (setq viper-inhibit-startup-message t
        viper-expert-level 5)
  :config
  (when _WIN32
    (add-hook 'viper-vi-state-hook (lambda () (w32-set-ime-open-status nil)))))

(provide 'init-editor)
