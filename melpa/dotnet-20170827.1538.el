;;; dotnet.el --- Interact with dotnet CLI tool

;; Copyright (C) 2017 by Julien Blanchard

;; Author: Julien BLANCHARD <julien@sideburns.eu>
;; URL: https://github.com/julienXX/dotnet.el
;; Package-Version: 20170827.1538
;; Version: 0.3
;; Keywords: .net, tools

;; This program is free software; you can redistribute it and/or modify
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
;;
;; dotnet CLI minor mode.
;; Provides some key combinations to interact with dotnet CLI.

;;; Code:

(defgroup dotnet nil
  "dotnet group."
  :prefix "dotnet-"
  :group 'tools)

(defcustom dotnet-mode-keymap-prefix (kbd "C-c C-n")
  "Dotnet minor mode keymap prefix."
  :group 'dotnet
  :type 'string)

;;;###autoload
(defun dotnet-add-package (package-name)
  "Add package reference from PACKAGE-NAME."
  (interactive "sPackage name: ")
  (dotnet-command (concat "dotnet add package " package-name)))

;;;###autoload
(defun dotnet-add-reference (reference project)
  "Add a REFERENCE to a PROJECT."
  (interactive (list (read-file-name "Reference file: ")
                     (read-file-name "In Project: ")))
  (dotnet-command (concat "dotnet add " project " reference "  reference)))

;;;###autoload
(defun dotnet-build ()
  "Build a .NET project."
  (interactive)
  (dotnet-command "dotnet build -v n"))

;;;###autoload
(defun dotnet-clean ()
  "Clean build output."
  (interactive)
  (dotnet-command "dotnet clean -v n"))

(defvar dotnet-langs '("c#" "f#"))
(defvar dotnet-templates '("console" "classlib" "mstest" "xunit" "web" "mvc" "webapi"))

;;;###autoload
(defun dotnet-new (project-path template lang)
  "Initialize a new console .NET project.
PROJECT-PATH is the path to the new project, TEMPLATE is a
template (see `dotnet-templates'), and LANG is a supported
language (see `dotnet-langs')."
  (interactive (list (read-directory-name "Project path: ")
                     (completing-read "Choose a template: " dotnet-templates)
                     (completing-read "Choose a language: " dotnet-langs)))
  (dotnet-command (concat "dotnet "
                          (mapconcat 'shell-quote-argument
                                     (list "new" template  "-o" project-path "-lang" lang)
                                     " "))))

;;;###autoload
(defun dotnet-publish ()
  "Publish a .NET project for deployment."
  (interactive)
  (dotnet-command "dotnet publish -v n"))

;;;###autoload
(defun dotnet-restore ()
  "Restore dependencies specified in the .NET project."
  (interactive)
  (dotnet-command "dotnet restore"))

;;;###autoload
(defun dotnet-run ()
  "Compile and execute a .NET project."
  (interactive)
  (dotnet-command "dotnet run"))

;;;###autoload
(defun dotnet-run-with-args (args)
  "Compile and execute a .NET project with ARGS."
  (interactive "sArguments: ")
  (dotnet-command (concat "dotnet run " args)))

;;;###autoload
(defun dotnet-sln-add ()
  "Add a project to a Solution."
  (interactive)
  (let ((solution-file (read-file-name "Solution file: ")))
    (let ((to-add (read-file-name "Project/Pattern to add to the solution: ")))
      (dotnet-command (concat "dotnet sln " solution-file " add " to-add)))))

;;;###autoload
(defun dotnet-sln-remove ()
  "Remove a project from a Solution."
  (interactive)
  (let ((solution-file (read-file-name "Solution file: ")))
    (let ((to-remove (read-file-name "Project/Pattern to remove from the solution: ")))
      (dotnet-command (concat "dotnet sln " solution-file " remove " to-remove)))))

;;;###autoload
(defun dotnet-sln-list ()
  "List all projects in a Solution."
  (interactive)
  (let ((solution-file (read-file-name "Solution file: ")))
    (dotnet-command (concat "dotnet sln " solution-file " list"))))

;;;###autoload
(defun dotnet-sln-new ()
  "Create a new Solution."
  (interactive)
  (let ((solution-path (read-directory-name "Solution path: ")))
    (dotnet-command (concat "dotnet new sln -o " solution-path))))

(defvar dotnet-test-last-test-proj nil
  "Last runned unit test project file.")

;;;###autoload
(defun dotnet-test ()
  "Launch project unit-tests."
  (interactive)
  (let ((project-file (read-file-name "Launch tests for Project file: ")))
    (setq dotnet-test-last-test-proj project-file)
    (dotnet-command (concat "dotnet test " project-file))))

;;;###autoload
(defun dotnet-test-rerun ()
  "Relaunch last project unit-tests."
  (interactive)
  (if dotnet-test-last-test-proj
      (dotnet-command (concat "dotnet test " dotnet-test-last-test-proj))
    (dotnet-command "dotnet test")))

(defun dotnet-command (cmd)
  "Run CMD in an async buffer."
  (async-shell-command cmd "*dotnet*"))

(defun dotnet-find (extension)
  "Search for a EXTENSION file in any enclosing folders relative to current directory."
  (dotnet-search-upwards (rx-to-string extension)
                         (file-name-directory buffer-file-name)))

(defun dotnet-goto (extension)
  "Open file with EXTENSION in any enclosing folders relative to current directory."
  (let ((file (dotnet-find extension)))
    (if file
        (find-file file)
      (error "Could not find any %s file" extension))))

(defun dotnet-goto-sln ()
  "Search for a solution file in any enclosing folders relative to current directory."
  (interactive)
  (dotnet-goto ".sln"))

(defun dotnet-goto-csproj ()
  "Search for a C# project file in any enclosing folders relative to current directory."
  (interactive)
  (dotnet-goto ".csproj"))

(defun dotnet-goto-fsproj ()
  "Search for a F# project file in any enclosing folders relative to current directory."
  (interactive)
  (dotnet-goto ".fsproj"))

(defun dotnet-search-upwards (regex dir)
  "Search for REGEX in DIR."
  (when dir
    (or (car-safe (directory-files dir 'full regex))
        (dotnet-search-upwards regex (dotnet-parent-dir dir)))))

(defun dotnet-parent-dir (dir)
  "Find parent DIR."
  (let ((p (file-name-directory (directory-file-name dir))))
    (unless (equal p dir)
      p)))

(defvar dotnet-mode-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "a p") #'dotnet-add-package)
    (define-key map (kbd "a r") #'dotnet-add-reference)
    (define-key map (kbd "b")   #'dotnet-build)
    (define-key map (kbd "c")   #'dotnet-clean)
    (define-key map (kbd "g c") #'dotnet-goto-csproj)
    (define-key map (kbd "g f") #'dotnet-goto-fsproj)
    (define-key map (kbd "g s") #'dotnet-goto-sln)
    (define-key map (kbd "n")   #'dotnet-new)
    (define-key map (kbd "p")   #'dotnet-publish)
    (define-key map (kbd "r")   #'dotnet-restore)
    (define-key map (kbd "e")   #'dotnet-run)
    (define-key map (kbd "C-e") #'dotnet-run-with-args)
    (define-key map (kbd "s a") #'dotnet-sln-add)
    (define-key map (kbd "s l") #'dotnet-sln-list)
    (define-key map (kbd "s n") #'dotnet-sln-new)
    (define-key map (kbd "s r") #'dotnet-sln-remove)
    (define-key map (kbd "t")   #'dotnet-test)
    (define-key map (kbd "T")   #'dotnet-test-rerun)
    map)
  "Keymap for dotnet-mode commands after `dotnet-mode-keymap-prefix'.")

(defvar dotnet-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd dotnet-mode-keymap-prefix) dotnet-mode-command-map)
    map)
  "Keymap for dotnet-mode.")

;;;###autoload
(define-minor-mode dotnet-mode
  "dotnet CLI minor mode."
  nil
  " dotnet"
  dotnet-mode-map
  :group 'dotnet)


(provide 'dotnet)
;;; dotnet.el ends here
