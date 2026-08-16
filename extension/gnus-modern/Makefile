.PHONY: all lint byte-compile package-lint checkdoc docquotes run clean
MAKEFLAGS := -rR

EMACS ?= emacs

test-entry :=
el-args := gnus-modern.el gnus-modern-core.el gnus-modern-custom.el \
           gnus-modern-renderer.el \
           gnus-modern-group-format.el gnus-modern-group.el \
           gnus-modern-summary-format.el \
           gnus-modern-summary.el
elc-args := $(el-args:.el=.elc)

elisp-string-list = $(patsubst %,\"%\",$(1))

all: byte-compile lint

lint: package-lint checkdoc docquotes

run: $(elc-args)
	$(EMACS) -Q --batch \
	   -L . \
	   --eval "(progn (require 'gnus-modern) (kill-emacs 0))"

$(elc-args): %.elc : %.el
	$(EMACS) -Q --batch \
	   --eval "(setq byte-compile-error-on-warn t)" \
	   -L . \
	   -f batch-byte-compile $<

byte-compile: $(elc-args)

package-lint: $(el-args)
	$(EMACS) --batch -Q -L . \
	   --eval "(progn\
  (package-initialize)\
  (require 'package-lint)\
  (let ((command-line-args-left '($(call elisp-string-list,$(el-args)))))\
    (package-lint-batch-and-exit)))"

checkdoc: $(el-args)
	$(EMACS) --batch -Q \
	   --eval "(progn\
  (require 'checkdoc)\
  (let ((sentence-end-double-space nil)\
        (checkdoc-proper-noun-list nil)\
        (checkdoc-verb-check-experimental-flag nil)\
        (ok t))\
    (dolist (f '($(call elisp-string-list,$(el-args))))\
      (when (get-buffer \"*Warnings*\") (kill-buffer \"*Warnings*\"))\
      (let ((inhibit-message t))\
        (checkdoc-file f))\
      (when (get-buffer \"*Warnings*\")\
        (setq ok nil)\
        (with-current-buffer \"*Warnings*\"\
          (message \"%s\" (buffer-string)))))\
    (unless ok (kill-emacs 1))))"

docquotes: $(el-args)
	$(EMACS) --batch -Q \
	   --eval "(progn\
  (let ((ok t))\
    (dolist (f '($(call elisp-string-list,$(el-args))))\
      (with-temp-buffer\
        (insert-file-contents f)\
        (setq case-fold-search nil)\
        (goto-char (point-min))\
        (while (re-search-forward \"\`[A-Z_]+'\" nil t)\
          (setq ok nil)\
          (message \"%s:%d:%d: Only use back/front quotes to link to top-level elisp symbols (%s)\"\
                   f (line-number-at-pos)\
                   (1+ (- (match-beginning 0) (line-beginning-position)))\
                   (match-string 0)))))\
    (unless ok (kill-emacs 1))))"

clean:
	rm -f *.elc
