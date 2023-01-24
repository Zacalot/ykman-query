;;; ykman-query.el --- An interface for copying OATH codes from a yubikey.

;; Author: Zacalot
;; Url: https://github.com/Zacalot/ykman-query
;; Version: 1.0.0
;; Package-Requires: ((emacs "24.1"))
;; Keywords: yubikey, authentication, password, interface

;;; Commentary:

;; This package uses the `ykman' program to access a YubiKey's OATH codes

;;; Usage:

;; First install `ykman'.  This can be acquired by getting the YubiKey Manager, then adding the directory to PATH.
;; Use M-x `ykman-query-query-code' and enter your YubiKey's password.

;; You may customize `ykman-query-cache-password' to disable password caching in memory.

;;; Code:

;;;; Requirements
(require 'simple)

;;;; Variables

(defgroup ykman-query nil
  "Settings for `ykman-query'."
  :link '(url-link "https://github.com/Zacalot/ykman-query"))

(defcustom ykman-query-cache-password
  t
  "Caches YubiKey password if set to t"
  :type 'boolean
  :local t
  :group 'ykman-query)

(defvar ykman-query-password nil)

(defun ykman-query-exec(args)
  "Executes `ykman' program with specified arguments."
  (let
      (
       (pass (if (and ykman-query-cache-password ykman-query-password) ykman-query-password (read-passwd "Password: ")))
       out)
    (setq ykman-query-password (if ykman-query-cache-password pass))
    (if (> (length pass) 0) ;seems to freeze if nothing is input, so avoid this
        (progn
          (setq out (s-trim (with-temp-buffer
                              (insert pass)
                              (apply 'call-process-region (point-min) (point-max) "ykman" t (current-buffer) nil (split-string args " "))
                              (buffer-string))))
          (if (or (string= out "Error: Authentication to the YubiKey failed. Wrong password?") (string= out "Error: No YubiKey detected!"))
              (setq ykman-query-password nil)
            out))
      (setq ykman-query-password nil))))


(defun ykman-query-get-code(account)
  "Retrieves OATH code for a given account name"
  (message "Getting code for %s: Waiting for tap..." account)
  (ykman-query-exec (concat "oath accounts code " account)))

(defun ykman-query-get-accounts()
  "Returns list of accounts on YubiKey"
  (let* (
         (list (ykman-query-exec "oath accounts list"))
         accounts)
    (if list
        (progn
          (dolist (account (split-string list "\n"))
            (setq accounts (cons ;Append
                            (cons ;Entry
                             account ;Name
                             account) ;Output
                            accounts)))
          accounts))))


(defun ykman-query-query-account()
  "Query the connected YubiKey for an account"
  (let (
        (accounts (ykman-query-get-accounts)))
    (if accounts
        (completing-read "Account: " accounts nil t))))

(defun ykman-query-query-code()
  "Query to copy a OATH code from the connected YubiKey"
  (interactive)
  (let
      (
       (account (ykman-query-query-account))
       code)
    (if account
        (progn
          (setq code (ykman-query-get-code account))
          (if code
              (progn
                (setq code (split-string code " ")
                      code (nth (- (length code) 1) code))
                (if (> (string-to-number code) 0)
                    (progn
                      (funcall interprogram-cut-function code)
                      (run-at-time "30 sec" nil (lambda () (funcall interprogram-cut-function "")))
                      (message "Code for %s copied to clipboard." account)))))))))

(provide 'ykman-query)
;;; ykman-query.el ends here
