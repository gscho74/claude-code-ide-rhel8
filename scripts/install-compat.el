;;; Install the GNU compat dependency using the target Emacs.
(require 'package)
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless (package-installed-p 'compat)
  (package-refresh-contents)
  (package-install 'compat))
