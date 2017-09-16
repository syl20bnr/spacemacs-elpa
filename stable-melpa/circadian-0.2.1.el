;;; circadian.el --- Theme-switching based on daytime

;; Copyright (C) 2017 Guido Schmidt

;; Author: Guido Schmidt
;; Maintainer: Guido Schmidt <guido.schmidt.2912@gmail.com>
;; URL: https://github.com/GuidoSchmidt/circadian
;; Package-Version: 0.2.1
;; Version: 0.2.1
;; Keywords: circadian, themes
;; Package-Requires: ((emacs "24.4"))

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; Circadian provides automated theme switching based on daytime.
;;
;; Example usage (with `use-package') featuring `nyx-theme' and `hemera-theme':
;;
;; (use-package circadian
;;   :config
;;   (setq circadian-themes '(("8:00" . hemera)
;;                            ("19:30" . nyx)))
;;   (circadian-setup))

;;; Change Log:

;; 0.2.1
;; - Add function to load the latest overdue theme to `circadian-setup'
;;
;; 0.2
;; - nyx-theme and hemera-theme live in their own repos from now on:
;;   nyx: https://github.com/GuidoSchmidt/emacs-nyx-theme
;;   hemera: https://github.com/GuidoSchmidt/emacs-hemera-theme
;; - Use default themes for default configuration of `circadian-themes'
;; - Re-implemented configuration using associated list and timers
;;   (thanks to Steve Purcell for pointing me into this direction)
;;
;; 0.1
;; - Initial release
;; - Variables for day/night hour
;; - Themes included: hemera-theme, nyx-theme

;;; Code:
(defcustom circadian-themes '(("7:30" . leuven)
                              ("19:30" . wombat))
  "List of themes mapped to the time they should be loaded."
  :type 'alist
  :group 'circadian)

(defun circadian-enable-theme (theme)
  "Clear previous `custom-enabled-themes' and load THEME."
  (setq custom-enabled-themes '())
  (load-theme theme t))

(defun circadian-mapcar (entry)
  "Map over `circadian-themes' to run a timer for each ENTRY."
  (let ((time (first entry)))
    (let ((theme (cdr (assoc time circadian-themes)))
          (repeat-after 86400))
      (run-at-time time repeat-after 'circadian-enable-theme theme))))

;;; --- TIME COMPARISONS
(defun circadian-time-string-from-list (time-list)
  "Concat list items from TIME-LIST to a time string separated by ':'."
  (mapconcat 'identity time-list ":"))

(defun circadian-now-time-string ()
  "Get the current time as string in the format 'HH:MM'."
  (let ((only-time (split-string (fourth (split-string (current-time-string))) ":")))
    (circadian-time-string-from-list (butlast only-time 1))))

(defun circadian-compare-hours (hour-a hour-b)
  "Compare two hours HOUR-A and HOUR-B."
  (>= hour-a hour-b))

(defun circadian-compare-minutes (min-a min-b)
  "Compare two minutes MIN-A and MIN-B."
  (>= min-a min-b))

(defun circadian-compare-time-strings (time-a time-b)
  "Compare to time strings TIME-A and TIME-B by hour and minutes."
  (let ((parsed-time-a (parse-time-string time-a))
        (parsed-time-b (parse-time-string time-b)))
    (and (circadian-compare-hours (third parsed-time-b) (third parsed-time-a))
         (circadian-compare-minutes (second parsed-time-b) (second parsed-time-a)))))

(defun circadian-filter-inactivate-themes ()
  "Find themes that need to be activated due to time is before now."
  (remove-if (lambda (entry)
               (let ((theme-time (first entry))
                     (now-time (circadian-now-time-string)))
                 (not (circadian-compare-time-strings theme-time now-time))))
             circadian-themes))

(defun circadian-activate-latest-theme ()
  "Check which themes are overdue to be activated and load the last.
`circadian-themes' is expected to be sorted by time for now."
  (let ((entry (first (last (circadian-filter-inactivate-themes)))))
    (let ((time (first entry)))
      (let ((theme (cdr (assoc time circadian-themes))))
        (load-theme theme t)))))

;;;###autoload
(defun circadian-setup ()
  "Setup circadian based on `circadian-themes'."
  (mapcar 'circadian-mapcar circadian-themes)
  (circadian-activate-latest-theme))

(provide 'circadian)
;;; circadian.el ends here