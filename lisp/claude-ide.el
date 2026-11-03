;;; claude-ide.el --- Claude Code editor bridge -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: MIT
;; Derived from the user's codex-ide 0.5.0 editor-context helpers.
(require 'cl-lib)
(require 'json)
(require 'project)
(require 'subr-x)
(require 'diff)
(require 'seq)
(require 'vc)
(require 'thingatpt)
(require 'flymake)
(defvar claude-ide-context-mode)
(defgroup claude-ide nil "Claude Code terminal and editor-context integration." :group 'tools)
(defcustom claude-ide-executable "claude"
  "Claude Code CLI program." :type 'string)
(defcustom claude-ide-context-max-chars 12000
  "Maximum source selection characters to send." :type 'integer)
(defcustom claude-ide-display-action
  '((display-buffer-reuse-window display-buffer-in-side-window)
    (side . right) (window-width . 0.43))
  "Buffer display action." :type 'sexp)
(defvar claude-ide--process nil)
(defvar claude-ide--pending (make-hash-table :test 'equal))
(defvar claude-ide--proposed-items (make-hash-table :test 'equal))
(defvar claude-ide--approval-history nil)
(defvar claude-ide--request-id 0)
(defvar claude-ide--partial "")
(defvar claude-ide--initialized nil)
(defvar claude-ide--sessions (make-hash-table :test 'equal))
(defvar claude-ide--active-id nil)
(defvar claude-ide--source nil)
(defvar claude-ide--snapshots nil)
(defvar claude-ide--last-changed nil)
(defvar claude-ide--snapshots-dir nil)
(defvar claude-ide--selection-state nil)
(defvar claude-ide--last-source-state nil)
(defcustom claude-ide-snapshot-limit 400
  "Maximum files per snapshot; large projects should use Git for exhaustive review."
  :type 'integer)
(defcustom claude-ide-file-size-limit 2000000
  "Maximum bytes for a file snapshot." :type 'integer)
(defcustom claude-ide-diagnostics-limit 30
  "Maximum diagnostics included in context." :type 'integer)
(defcustom claude-ide-auto-context t
  "Track active file/region and publish to the session-local MCP snapshot."
  :type 'boolean)
(defcustom claude-ide-include-diagnostics t
  "Include current Emacs diagnostic errors and warnings in prompts."
  :type 'boolean)
(defvar claude-ide--snapshot-root nil)
(defvar claude-ide--debug "*claude-ide-log*")
(defvar-local claude-ide--thread-id nil)
(defvar-local claude-ide--cwd nil)
(defvar-local claude-ide--busy nil)
(defvar-local claude-ide--last-turn nil)
(defvar-local claude-ide--delta-start nil)
(defvar-local claude-ide--input-start nil)
(defvar-local claude-ide--output-end nil)
(defvar-local claude-ide--input-history nil)
(defvar-local claude-ide--history-index nil)
(defvar-local claude-ide--input-draft "")
(defvar-local claude-ide--editor-buffer nil)
(defvar-local claude-ide--tracked-region nil)
(defvar-local claude-ide--dismissed-context nil)
(defvar-local claude-ide--context-overlay nil)
(defvar claude-ide-context-update-hook nil
  "Hook run in each session buffer when its editor context changes.")
(defun claude-ide--log (fmt &rest args)
  (with-current-buffer (get-buffer-create claude-ide--debug)
    (goto-char (point-max))
    (insert (format-time-string "%T ") (apply #'format fmt args) "\n")))
(defun claude-ide--get (object key)
  (and (hash-table-p object) (gethash key object)))
(defun claude-ide--obj (&rest pairs)
  (let ((h (make-hash-table :test 'equal)))
    (while pairs (puthash (pop pairs) (pop pairs) h)) h))
(defun claude-ide--root (&optional b)
  (with-current-buffer (or b (current-buffer))
    (expand-file-name
     (or (when-let* ((p (project-current nil))) (project-root p))
	 default-directory))))
(defun claude-ide--buffer-for (id) (gethash id claude-ide--sessions))
(defun claude-ide--source-buffer nil
  (if
      (and buffer-file-name
	   (not (derived-mode-p 'claude-ide-chat-mode)))
      (current-buffer)
    (let*
	((session
	  (or (and claude-ide--thread-id (current-buffer))
	      (claude-ide--buffer-for claude-ide--active-id)))
	 (local-source
	  (and (buffer-live-p session)
	       (buffer-local-value 'claude-ide--editor-buffer session)))
	 (source
	  (if (buffer-live-p local-source) local-source
	    claude-ide--source))
	 (cwd
	  (and (buffer-live-p session)
	       (buffer-local-value 'claude-ide--cwd session))))
      (when
	  (and (buffer-live-p source)
	       (or (not cwd) (claude-ide--source-in-root-p source cwd)))
	source))))
(defun claude-ide--source-in-root-p (source root)
  "Whether SOURCE visits a file within ROOT."
  (when-let* ((file (buffer-file-name source)))
    (string-prefix-p (file-name-as-directory (expand-file-name root))
		     (expand-file-name file))))
(defun claude-ide--region-bounds nil
  "Return the live selection or its tracked markers in the source buffer."
  (cond ((use-region-p) (cons (region-beginning) (region-end)))
	((and claude-ide--tracked-region
	      (marker-position (car claude-ide--tracked-region))
	      (marker-position (cdr claude-ide--tracked-region))
	      (< (car claude-ide--tracked-region)
		 (cdr claude-ide--tracked-region)))
	 (cons (marker-position (car claude-ide--tracked-region))
	       (marker-position (cdr claude-ide--tracked-region))))))
(defun claude-ide--context-fingerprint (source)
  "Identify SOURCE and its selection, independently of cursor movement."
  (with-current-buffer source
    (list buffer-file-name (claude-ide--region-bounds))))
(defun claude-ide--context-source nil
  "Return the source unless its context was dismissed in this session."
  (let*
      ((session
	(or (and claude-ide--thread-id (current-buffer))
	    (claude-ide--buffer-for claude-ide--active-id)))
       (dismissed
	(and (buffer-live-p session)
	     (buffer-local-value 'claude-ide--dismissed-context session)))
       (source (claude-ide--source-buffer)))
    (unless
	(or (not claude-ide-auto-context)
	    (and source
		 (equal dismissed
			(claude-ide--context-fingerprint source))))
      source)))
(defun claude-ide--context-label nil
  "Describe exactly the editor context available to the current session."
  (if-let* ((source (claude-ide--context-source)))
      (with-current-buffer source
	(if-let* ((bounds (claude-ide--region-bounds)))
	    (format "⧉ %s · L%d–L%d selected"
		    (file-name-nondirectory buffer-file-name)
		    (line-number-at-pos (car bounds))
		    (line-number-at-pos
		     (max (car bounds) (1- (cdr bounds)))))
	  (format "⧉ In %s · L%d"
		  (file-name-nondirectory buffer-file-name)
		  (line-number-at-pos))))
    (if claude-ide--dismissed-context "⧉ Context cleared"
      "⧉ No editor context")))
(defun claude-ide--update-context-display nil
  "Refresh the context row beside this session's composer."
  (when
      (and (markerp claude-ide--output-end)
	   (marker-buffer claude-ide--output-end))
    (unless (overlayp claude-ide--context-overlay)
      (setq claude-ide--context-overlay
	    (make-overlay claude-ide--output-end claude-ide--output-end
			  nil t t)))
    (move-overlay claude-ide--context-overlay claude-ide--output-end
		  claude-ide--output-end)
    (overlay-put claude-ide--context-overlay 'before-string
		 (concat "\n"
			 (propertize (claude-ide--context-label) 'face
				     'font-lock-comment-face)
			 "\n")))
  (run-hooks 'claude-ide-context-update-hook) (force-mode-line-update))
(defun claude-ide--diagnostics (buffer)
  "Extract Flymake/Flycheck diagnostics for BUFFER."
  (with-current-buffer buffer
    (let (rows)
      (when
	  (and claude-ide-include-diagnostics
	       (bound-and-true-p flymake-mode)
	       (fboundp 'flymake-diagnostics))
	(dolist (d (ignore-errors (flymake-diagnostics)))
	  (push
	   (format "Flymake L%d: %s"
		   (line-number-at-pos (flymake-diagnostic-beg d))
		   (flymake-diagnostic-text d))
	   rows)))
      (when
	  (and claude-ide-include-diagnostics
	       (bound-and-true-p flycheck-mode)
	       (boundp 'flycheck-current-errors))
	(dolist (e (symbol-value 'flycheck-current-errors))
	  (push
	   (format "Flycheck L%s: %s"
		   (if (fboundp 'flycheck-error-line)
		       (flycheck-error-line e)
		     "?")
		   (if (fboundp 'flycheck-error-message)
		       (flycheck-error-message e)
		     ""))
	   rows)))
      (seq-take (nreverse rows) claude-ide-diagnostics-limit))))
(defun claude-ide--context nil
  "Capture precise current editor position, selection and diagnostics."
  (if-let* ((b (claude-ide--context-source)))
      (with-current-buffer b
	(let*
	    ((file (or (buffer-file-name) (buffer-name)))
	     (bounds (claude-ide--region-bounds))
	     (start
	      (line-number-at-pos (if bounds (car bounds) (point))))
	     (end
	      (line-number-at-pos
	       (if bounds (max (car bounds) (1- (cdr bounds)))
		 (point))))
	     (selection
	      (when bounds
		(buffer-substring-no-properties (car bounds)
						(min (cdr bounds)
						     (+ (car bounds)
							claude-ide-context-max-chars)))))
	     (diagnostics (claude-ide--diagnostics b)))
	  (concat "\n\n[Emacs editor context]\nFile: " file
		  "\nLines: " (number-to-string start) "-"
		  (number-to-string end)
		  (format
		   "\nCursor column: %d\nSymbol at point: %s\nLanguage server: %s\nUnsaved changes: %s"
		   (current-column)
		   (or (thing-at-point 'symbol t) "none")
		   (if
		       (or (bound-and-true-p eglot--managed-mode)
			   (bound-and-true-p lsp-mode))
		       "active"
		     "inactive")
		   (if (buffer-modified-p) "yes" "no"))
		  (if selection
		      (concat "\nSelected source:\n```\n" selection
			      "\n```")
		    "")
		  (if diagnostics
		      (concat "\nEditor diagnostics:\n"
			      (string-join diagnostics "\n"))
		    "")
		  "\n[/Emacs editor context]")))
    ""))
(defun claude-ide--track nil
  "Remember the latest editing buffer and active selection."
  (when
      (and claude-ide-auto-context buffer-file-name (not (minibufferp)))
    (setq claude-ide--source (current-buffer))
    (when claude-ide--tracked-region
      (set-marker (car claude-ide--tracked-region) nil)
      (set-marker (cdr claude-ide--tracked-region) nil))
    (setq claude-ide--tracked-region
	  (when (use-region-p)
	    (cons (copy-marker (region-beginning))
		  (copy-marker (region-end) t))))
    (setq claude-ide--last-source-state
	  (list (buffer-file-name) (line-number-at-pos)
		(when (use-region-p)
		  (line-number-at-pos (region-beginning)))
		(when (use-region-p)
		  (line-number-at-pos
		   (max (region-beginning) (1- (region-end)))))))
    (let
	((source (current-buffer))
	 (fingerprint
	  (claude-ide--context-fingerprint (current-buffer))))
      (maphash
       (lambda (_id buffer)
	 (when (buffer-live-p buffer)
	   (with-current-buffer buffer
	     (when
		 (or (not claude-ide--cwd)
		     (claude-ide--source-in-root-p source
						  claude-ide--cwd))
	       (setq claude-ide--editor-buffer source)
	       (unless
		   (equal claude-ide--dismissed-context fingerprint)
		 (setq claude-ide--dismissed-context nil))
	       (claude-ide--update-context-display)))))
       claude-ide--sessions))
    (force-mode-line-update t)))
(defun claude-ide--context-indicator nil
  (if (and claude-ide-context-mode claude-ide--last-source-state)
      (format " Claude Code[%s:%s%s]"
	      (file-name-nondirectory
	       (or (nth 0 claude-ide--last-source-state) ""))
	      (or (nth 1 claude-ide--last-source-state) "?")
	      (if (nth 2 claude-ide--last-source-state)
		  (format " sel:%s-%s"
			  (nth 2 claude-ide--last-source-state)
			  (nth 3 claude-ide--last-source-state))
		""))
    ""))
(define-minor-mode claude-ide-context-mode
  "Track the active file and line selection; send context only on prompts."
  :global t :lighter (:eval (claude-ide--context-indicator))
  (if claude-ide-context-mode
      (progn
	(add-hook 'post-command-hook #'claude-ide--track)
	(add-hook 'buffer-list-update-hook #'claude-ide--track)
	(claude-ide--track))
    (remove-hook 'post-command-hook #'claude-ide--track)
    (remove-hook 'buffer-list-update-hook #'claude-ide--track)
    (setq claude-ide--source nil claude-ide--last-source-state nil)
    (maphash
     (lambda (_id buffer)
       (when (buffer-live-p buffer)
	 (with-current-buffer buffer
	   (setq claude-ide--editor-buffer nil)
	   (claude-ide--update-context-display))))
     claude-ide--sessions)))
(defvar claude-ide-chat-mode-map (make-sparse-keymap))
(defun claude-ide-send-region (question)
  "Send a question with selected lines."
  (interactive "sQuestion about selected lines: ")
  (unless (use-region-p) (user-error "Select code first"))
  (claude-ide-send-prompt
   (if (string-empty-p question) "Review selected code" question)))
(defun claude-ide-insert-at-mentioned nil
  "Display current file and line reference, for prompt composition."
  (interactive)
  (let ((ctx (claude-ide--context)))
    (kill-new ctx)
    (message
     "File and selection context copied; will also be included with next prompt")))
(defun claude-ide-clear-selection nil
  "Dismiss this session's file/selection until a new file or region is tracked."
  (interactive)
  (let
      ((source (claude-ide--source-buffer))
       (session (claude-ide--active-buffer)))
    (with-current-buffer session
      (setq claude-ide--dismissed-context
	    (if source (claude-ide--context-fingerprint source)
	      '(cleared)))
      (claude-ide--update-context-display))))
(defun claude-ide--resume-project-root nil
  "Return the canonical project root for a conversation picker.\nIn a Claude Code buffer, keep its saved project even if its terminal changed cwd."
  (file-name-as-directory
   (file-truename
    (if
	(and (stringp claude-ide--cwd)
	     (not (string-empty-p claude-ide--cwd))
	     (or (derived-mode-p 'claude-ide-chat-mode)
		 (bound-and-true-p claude-ide-terminal-mode)))
	claude-ide--cwd
      (claude-ide--root)))))
(defun claude-ide-switch-to-buffer nil
  "Open active Claude Code chat." (interactive)
  (pop-to-buffer (claude-ide--active-buffer)))
(defun claude-ide-toggle nil
  "Toggle chat window." (interactive)
  (let* ((b (claude-ide--active-buffer)) (w (get-buffer-window b)))
    (if w (delete-window w)
      (display-buffer b claude-ide-display-action))))
(defun claude-ide-toggle-recent nil
  "Toggle recent chat window." (interactive) (claude-ide-toggle))
(defun claude-ide-show-all nil
  "Display active chat buffers." (interactive)
  (maphash
   (lambda (_id b) (when (buffer-live-p b) (display-buffer b)))
   claude-ide--sessions))

(defun claude-ide--active-buffer ()
  "Find the active Claude terminal."
  (or (and (bound-and-true-p claude-ide-terminal-mode) (current-buffer))
      (claude-ide--buffer-for claude-ide--active-id)
      (user-error "Start a session with M-x claude-ide")))
(defun claude-ide () (interactive) (claude-ide-terminal))
(defun claude-ide-resume () (interactive) (claude-ide-terminal t))
(defun claude-ide-send-prompt (prompt)
  "Send PROMPT with the current editor context."
  (interactive "sClaude: ")
  (claude-ide-terminal-send-prompt (claude-ide--active-buffer) prompt (claude-ide--context)))
(defun claude-ide-interrupt ()
  (interactive) (claude-ide-terminal-interrupt (claude-ide--active-buffer)))
(defun claude-ide-stop ()
  "Close the active Claude terminal and its editor bridge."
  (interactive)
  (let ((b (claude-ide--active-buffer)))
    (when (yes-or-no-p "Close this Claude session? ")
      (kill-buffer b))))
(defun claude-ide-check-status ()
  (interactive)
  (message "Claude=%s Emacs=%s backend=%s Python=%s"
           (or (executable-find claude-ide-executable) "MISSING") emacs-version
           claude-ide-terminal-backend
           (or (executable-find claude-ide-python-executable) "MISSING")))
(defun claude-ide-menu ()
  (interactive)
  (let* ((choices '(("Start new" . claude-ide) ("Resume" . claude-ide-resume)
                    ("Prompt with context" . claude-ide-send-prompt)
                    ("Send region" . claude-ide-send-region)
                    ("Clear context" . claude-ide-clear-selection)
                    ("Show chat" . claude-ide-switch-to-buffer)
                    ("Toggle chat" . claude-ide-toggle)
                    ("Interrupt" . claude-ide-interrupt)
                    ("Close session" . claude-ide-stop)
                    ("Status" . claude-ide-check-status)))
         (choice (completing-read "Claude IDE: " choices nil t)))
    (call-interactively (cdr (assoc choice choices)))))
(provide 'claude-ide)
(require 'claude-ide-terminal)
;;; claude-ide.el ends here
