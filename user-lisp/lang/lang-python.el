;;; -*- lexical-binding: t -*-
(use-package python
  :ensure nil
  :mode ("/\\(?:Pipfile\\|\\.?flake8\\)\\'" . conf-mode)
  :custom
  (python-check-command nil)
  (python-indent-guess-indent-offset-verbose nil)
  :config
  ;; HACK: Python 3.13's pyrepl mishandles SIGINT under Emacs's comint
  ;;   (TERM=dumb), particularly on macOS. The ^C character is treated as
  ;;   literal input rather than triggering an interrupt signal. Disabling
  ;;   pyrepl forces the classic readline-based REPL which handles signals
  ;;   correctly. See #8391, also used by VS Code's Python extension.
  (add-to-list 'python-shell-process-environment "PYTHON_BASIC_REPL=1"))

(provide 'lang-python)
