;;; rex-mode.el --- Generic mode for rex/rexical/oedipus_lex files

;; Copyright (c) Ryan Davis, seattle.rb
;;
;; Author: Ryan Davis <ryand-ruby@zenspider.com>
;; Keywords: languages

;; (The MIT License)
;;
;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; 'Software'), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
;; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
;; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Commentary:

;; woot

;;; Code:

(define-generic-mode rex-mode
  ;; comments
  '(?#)

  ;; keywords
  nil

  ;; font-lock-faces
  '(("/\\(\\\\.\\|[^/]\\)*/"                        . font-lock-string-face)
    (":[a-zA-Z_][a-zA-Z0-9_]*"                      . font-lock-variable-name-face)
    ("^ *\\([A-Z][A-Z0-9_]*\\)"                     1 font-lock-variable-name-face)
    ("^\\(?:end\\|inner\\|macro\\|option\\|rule\\)" . font-lock-keyword-face)
    ("class [A-Z][a-zA-Z_]+"                        . font-lock-keyword-face))

  ;; auto-mode
  '("\\.rex$")

  ;; functions
  nil

  "Simple generic mode for rex/rexical/t-rex files")

(provide 'rex-mode)
;;; rex-mode.el ends here
