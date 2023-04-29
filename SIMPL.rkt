#lang racket

(provide vars iif while
         (rename-out [display print] [begin seq] [set! set] 
                     [void skip] [quotient div] [modulo mod])
         > >= < <= = and or not + - * true false
         #%module-begin #%datum #%app #%top #%top-interaction)

(define-syntax-rule 
  (vars [(id init) ...] exp ...)
    (let [(id init) ...] 
      exp ...))

(define-syntax-rule
  (iif test texp fexp) 
    (if test texp fexp))

(define-syntax-rule 
  (while test exp ...)
    (let loop () 
      (when test 
        exp ... (loop))))
