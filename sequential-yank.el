;;; sequential-yank.el --- Minor mode to copy and paste strings sequentially

;; Copyright (c) 2023 Akinori MUSHA
;;
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:
;; 1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
;; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
;; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
;; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;; SUCH DAMAGE.

;; Author: Akinori MUSHA <knu@iDaemons.org>
;; URL: https://github.com/knu/sequential-yank.el
;; Created: 29 Oct 2023
;; Version: 0.1.0
;; Keywords: killing, convenience

;;; Commentary:
;;
;; In `sequantial-yank-mode', killed strings are stored in a global
;; queue and so they can later be yanked sequentially with the
;; `sequential-yank' command.

;;; Code:

(defvar sequential-yank-queue nil
  "The sequential yank queue.")

(defun sequential-yank:push (string)
  "Internal function to push STRING to the sequential yank queue."
  (setq sequential-yank-queue (cons string sequential-yank-queue)))

(defun sequential-yank:replace (string)
  "Internal function to replace the last sequential yank string with STRING."
  (setcar sequential-yank-queue string))

(defun sequential-yank:pop ()
  "Internal function to pop the last string from the sequential yank queue."
  (let* ((p sequential-yank-queue)
         (c (cdr p))
         (n (cdr c)))
    (while n
      (setq p c
            c n
            n (cdr n)))
    (if c
        (progn
          (setcdr p nil)
          (car c))
      (setq sequential-yank-queue nil)
      (car p))))

(defun sequential-yank:ad:kill-new (string &optional replace)
  "Internal advice function for `kill-new' to push STRING to the sequential yank.

REPLACE is supported."
  (let ((cur-kill (car kill-ring)))
    (if replace
        (sequential-yank:replace cur-kill)
      (sequential-yank:push cur-kill))))

(defvar sequential-yank-mode)

(defun sequential-yank (arg)
  "Yank a string sequentially from the sequential yank queue.

With \\[universal-argument] as ARG, put point at beginning and
mark at end, just like `yank'."
  (interactive "*P")
  (or sequential-yank-mode
      (error "Not in sequential-yank-mode"))
  (let ((string (sequential-yank:pop)))
    (or string
        (error "Sequential yank queue is empty"))
    (setq yank-window-start (window-start))
    (setq this-command t)
    (push-mark)
    (insert-for-yank string)
    (if (consp arg)
        (goto-char (prog1 (mark t)
		     (set-marker (mark-marker) (point) (current-buffer)))))
    (if (eq this-command t)
        (setq this-command 'yank))
    (unless sequential-yank-queue
      (sequential-yank-mode -1)
      (message "Sequential yank finished."))
    nil))

(defvar sequential-yank-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "M-Y") #'sequential-yank)
    map)
  "Keymap used in `sequential-yank-mode'.")

;;;###autoload
(define-minor-mode sequential-yank-mode
  "Toggle sequential yank mode."
  :global t
  :lighter " SeqYank"
  :keymap sequential-yank-mode-map
  :group 'killing
  (setq sequential-yank-queue nil)
  (if sequential-yank-mode
      (advice-add #'kill-new :after #'sequential-yank:ad:kill-new)
    (advice-remove #'kill-new #'sequential-yank:ad:kill-new)))

(with-eval-after-load 'multiple-cursors
  (add-to-list 'mc/cursor-specific-vars 'sequential-yank-queue)
  (add-to-list 'mc--default-cmds-to-run-for-all 'sequential-yank))

(provide 'sequential-yank)
;;; sequential-yank.el ends here