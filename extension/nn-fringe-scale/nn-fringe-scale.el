;;; nn-fringe-scale.el --- Scale fringe bitmaps for HiDPI displays -*- lexical-binding: t; -*-
;;; Commentary:
;; src url https://github.com/blahgeek/emacs-fringe-scale
;;; Code:
(defgroup nn-fringe-scale nil
  "Scale fringe bitmap"
  :group 'tools)

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

;;;###autoload
(defun nn-fringe-scale-setup ()
  "Setup fringe scale.
Must be called before other packages calling `define-fringe-bitmap'."
  (interactive)
  (advice-add 'define-fringe-bitmap :around #'nn-fringe-scale--define-fringe-bitmap-advice))

(provide 'nn-fringe-scale)
;;; nn-fringe-scale.el ends here
