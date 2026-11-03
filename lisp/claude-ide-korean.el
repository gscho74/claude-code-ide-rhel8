;;; claude-ide-korean.el --- Optional Korean setup -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: MIT
(setq default-input-method "korean-hangul")

;; Treat Right Alt / AltGr as a Korean input toggle in PGTK Emacs.
;; pgtk-keysym-table translates these before modifier-only keys are discarded.
(when (boundp 'pgtk-keysym-table)
  (unless (hash-table-p pgtk-keysym-table)
    (setq pgtk-keysym-table (make-hash-table :test 'eql)))
  (puthash #xffea #xe000 pgtk-keysym-table) ; Alt_R
  (puthash #xfe03 #xe000 pgtk-keysym-table) ; ISO_Level3_Shift (AltGr)
  (dolist (modifiers '(nil (meta) (control) (control meta)))
    (define-key key-translation-map
                (vector (event-convert-list (append modifiers (list #xe000))))
                [right-alt-hangul])))
(defun claude-ide-right-alt-toggle-input-method ()
  "Toggle input with right Alt and protect Claude Code from its residual modifier."
  (interactive)
  (toggle-input-method)
  (when (fboundp 'claude-ide-terminal--guard-right-alt)
    (claude-ide-terminal--guard-right-alt))
  (when (fboundp 'codex-ide-terminal--guard-right-alt)
    (codex-ide-terminal--guard-right-alt)))
(global-set-key [right-alt-hangul] #'claude-ide-right-alt-toggle-input-method)
(global-set-key [hangul] #'toggle-input-method)
;; X11 Emacs uses the desktop's Hangul key; C-\ always remains available.
(global-set-key [Hangul] #'toggle-input-method)
(defun claude-ide-korean-font (&optional frame)
  (when (display-graphic-p frame)
    (let* ((frame (or frame (selected-frame)))
           (families (font-family-list frame))
           (family (seq-find (lambda (name) (member name families))
                             '("D2Coding" "Noto Sans Mono CJK KR" "Noto Sans CJK KR"))))
      (when family (set-fontset-font t 'hangul (font-spec :family family) frame)))))
(add-hook 'after-make-frame-functions #'claude-ide-korean-font)
(claude-ide-korean-font)
(provide 'claude-ide-korean)
