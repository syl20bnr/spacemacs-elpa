;;; magit-org-todos.el --- Add local todo items to the magit status buffer

;; Copyright (C) 2018 Daniel Ma <github.com/danielma>
;; Author: Daniel Ma
;; URL: http://github.com/danielma/magit-org-todos
;; Created: 2018
;; Version: 0.1.0
;; Keywords: org-mode magit tools
;; Package-Version: 20180316.2245
;; Package-X-Original-Version: 0.1.0
;; Package-Requires: ((magit "2.0.0") (emacs "24"))

;;; Commentary:
;;
;; adds all TODO items from a todo.org file in the magit project's root
;; to the magit status buffer

;;; Code:
(require 'magit)
(require 'org-element)

(defun magit-org-todos--todo-file-path ()
  "Path of the todo file."
  (let* ((toplevel (magit-toplevel))
         (todo (concat toplevel "todo.org")))
    todo))

(defun magit-org-todos--magit-visit-org-todo ()
  "Visits the org todo file."
  (interactive)
  (find-file (magit-org-todos--todo-file-path)))

(defvar magit-org-todos-section-map
  (let ((m (make-sparse-keymap)))
    (define-key m [remap magit-visit-thing] 'magit-org-todos--magit-visit-org-todo)
    m))

;;;###autoload
(defun magit-org-todos-insert-org-todos ()
  "Insert org todos from the local todo.org."
  (when (file-readable-p (magit-org-todos--todo-file-path))
    (let ((todos (with-temp-buffer
                   (insert-file-contents (magit-org-todos--todo-file-path))
                   (org-mode)
                   (org-element-map (org-element-parse-buffer) 'headline
                     (lambda (headline)
                       (let ((todo-type (org-element-property :todo-type headline)))
                         (and (eq todo-type 'todo) headline)))))))
      (magit-insert-section (org-todos-wrapper)
        (magit-insert-heading "Todos:")
        (dolist (todo todos)
          (let ((keyword (org-element-property :todo-keyword todo))
                (title (org-element-property :raw-value todo)))
            (magit-insert-section (org-todos title)
            (insert (concat "* " (propertize keyword 'face 'org-todo) " " title))
            (insert ?\n))))
        (insert ?\n)))))

;;;###autoload
(defun magit-org-todos-autoinsert ()
  "Automatically insert todo section into magit status buffer."
  (magit-add-section-hook
   'magit-status-sections-hook
   'magit-org-todos-insert-org-todos
   'magit-insert-staged-changes
   t))

(provide 'magit-org-todos)

;;; magit-org-todos.el ends here