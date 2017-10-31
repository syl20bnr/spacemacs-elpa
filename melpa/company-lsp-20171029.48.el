;;; company-lsp.el --- Company completion backend for lsp-mode.  -*- lexical-binding: t -*-

;; Version: 1.0
;; Package-Version: 20171029.48
;; Package-Requires: ((emacs "25.1") (lsp-mode "3.1") (company "0.9.0") (s "1.2.0"))
;; URL: https://github.com/tigersoldier/company-lsp

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; `company-lsp' is a `company' completion backend for `lsp-mode'.
;; To use it, add `company-lsp' to `company-backends':

;;     (require 'company-lsp)
;;     (push 'company-lsp company-backends)

;;; Code:

(require 'cl-lib)
(require 'company)
(require 'lsp-mode)
(require 's)

(defgroup company-lsp nil
  "Company completion backend for lsp-mode."
  :prefix "company-lsp-"
  :group 'tools)

(defcustom company-lsp-cache-candidates t
  "Whether or not to cache completion candidates.

When set to non-nil, company caches the completion candidates so
company filters the candidates as completion progresses. If set
to nil, each incremental completion triggers a completion request
to the language server."
  :type 'boolean
  :group 'company-lsp)

(defcustom company-lsp-async nil
  "Whether or not to use async operations to fetch data."
  :type 'boolean
  :group 'company-lsp)

(defvar-local company-lsp--pending-requests (make-hash-table)
  "Hash table where keys are requests id and values are company's callback.")

(defun company-lsp--trigger-characters ()
  "Return a list of completion trigger characters specified by server."
  (when-let (completionProvider (lsp--capability "completionProvider"))
    (gethash "triggerCharacters" completionProvider)))

(defun company-lsp--completion-prefix ()
  "Return the completion prefix.

Return value is compatible with the `prefix' command of a company backend.

Return nil if no completion should be triggered. Return a string
as the prefix to be completed, or a cons cell of (prefix . t) to bypass
`company-minimum-prefix-length' for trigger characters."
  (if-let (trigger-chars (company-lsp--trigger-characters))
      (let* ((max-trigger-len (apply 'max (mapcar (lambda (trigger-char)
                                                    (length trigger-char))
                                                  trigger-chars)))
             (trigger-regex (s-join "\\|" (mapcar #'regexp-quote trigger-chars)))
             (symbol-cons (company-grab-symbol-cons trigger-regex max-trigger-len)))
        ;; Some major modes define trigger characters as part of the symbol. For
        ;; example "@" is considered a vaild part of symbol in java-mode.
        ;; Company will grab the trigger character as part of the prefix while
        ;; the server doesn't. Remove the leading trigger character to solve
        ;; this issue.
        (let* ((symbol (if (consp symbol-cons)
                           (car symbol-cons)
                         symbol-cons))
               (trigger-char (seq-find (lambda (trigger-char)
                                         (s-starts-with? trigger-char symbol))
                                       trigger-chars)))
          (if trigger-char
              (cons (substring symbol (length trigger-char)) t)
            symbol-cons)))
    (company-grab-symbol)))

(defun company-lsp--make-candidate (item)
  "Convert a CompletionItem JSON data to a string.

ITEM is a hashtable representing the CompletionItem interface.

The returned string has a lsp-completion-item property with the
value of ITEM."
  ;; The property has to be the same as added by `lsp--make-completion-item' so
  ;; that `lsp--annotate' can use it.
  (propertize (gethash "label" item) 'lsp-completion-item item))

(defun company-lsp--candidate-item (candidate)
  "Retrieve the CompletionItem hashtable associated with CANDIDATE.

CANDIDATE is a string returned by `company-lsp--make-candidate'."
  (plist-get (text-properties-at 0 candidate) 'lsp-completion-item))

(defun company-lsp--resolve-candidate (candidate &rest props)
  "Resolve a completion candidate to fill some properties.

CANDIDATE is a string returned by `company-lsp--make-candidate'.
PROPS are strings of property names of CompletionItem hashtable
to be resolved.

The completionItem/resolve request will only be sent to the
server if the candidate has not been resolved before, and at lest
one of the PROPS of the CompletionItem is missing.

Returns CANDIDATE with the resolved CompletionItem."
  (unless (plist-get (text-properties-at 0 candidate) 'company-lsp-resolved)
    (let ((item (company-lsp--candidate-item candidate)))
      (when (seq-some (lambda (prop)
                        (null (gethash prop item)))
                      props)
        (let ((resolved-item (lsp--resolve-completion item))
              (len (length candidate)))
          (put-text-property 0 len
                             'lsp-completion-item resolved-item
                             candidate)
          (put-text-property 0 len
                             'company-lsp-resolved t
                             candidate)))))
  candidate)

(defun company-lsp--post-completion (candidate)
  "Replace a CompletionItem's label with its insertText. Apply text edits.

CANDIDATE is a string returned by `company-lsp--make-candidate'."
  (let* ((resolved-candidate (company-lsp--resolve-candidate candidate
                                                             "insertText"
                                                             "textEdit"
                                                             "additionalTextEdits"))
         (item (company-lsp--candidate-item candidate))
         (label (gethash "label" item))
         (start (- (point) (length label)))
         (insert-text (gethash "insertText" item))
         (text-edit (gethash "textEdit" item))
         (additional-text-edits (gethash "additionalTextEdits" item)))
    (cond
     (text-edit (lsp--apply-text-edit text-edit))
     (insert-text
      (cl-assert (string-equal (buffer-substring-no-properties start (point)) label))
      (goto-char start)
      (delete-char (length label))
      (insert insert-text)))
    (when additional-text-edits
      (lsp--apply-text-edits additional-text-edits))))

(defun company-lsp--on-completion (response callback)
  "Give the server RESPONSE to company's CALLBACK."
  (let* ((items (cond ((hash-table-p response) (gethash "items" response nil))
                      ((sequencep response) response))))
    (funcall callback (mapcar #'company-lsp--make-candidate
                              (lsp--sort-completions items)))))

;;;###autoload
(defun company-lsp (command &optional arg &rest _)
  "Define a company backend for lsp-mode.

See the documentation of `company-backends' for COMMAND and ARG."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend #'company-lsp))
    (prefix (and
             (bound-and-true-p lsp-mode)
             (lsp--capability "completionProvider")
             (or (company-lsp--completion-prefix) 'stop)))
    (candidates
     (cons :async
           #'(lambda (callback)
               (lsp--send-changes lsp--cur-workspace)
               (let ((req (lsp--make-request "textDocument/completion"
                                             (lsp--text-document-position-params))))
                 (if company-lsp-async
                     (lsp--send-request-async req
                                              (lambda (resp)
                                                (company-lsp--on-completion resp callback)))
                   (company-lsp--on-completion (lsp--send-request req)
                                               callback))))))
    (sorted t)
    (no-cache (not company-lsp-cache-candidates))
    (annotation (lsp--annotate arg))
    (match (length arg))
    (post-completion (company-lsp--post-completion arg))))

(provide 'company-lsp)
;;; company-lsp.el ends here