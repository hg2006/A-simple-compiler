#lang racket

(require test-engine/racket-tests)

;; -------------------------- At the Beginning ------------------------------------------------------

;; This project is available on Github: https://github.com/hg2006/A-simple-compiler

;; This is a compiler that compiles SIMPL, an artificial imperative language to an artificial 
;; assembly language, A-PRIMPL. For a thorough explanations of grammar of SIMPL, its designation,
;; as well as everything about A-PRIMPL and its machine language, PRIMPL, please refer to the
;; README file.

;; Uncomment the following to enable the use of associated assembler and PRIMPL simulator
;; (refer to the Github page for downloading and remember to put these files under the same directory)
；(require "Assembler.rkt")
；(require "PRIMPL.rkt")

;; Several examples of SIMPL programs are provided at the end

;; -------------------------- Helper function: Label generator --------------------------------------

;; acc is to keep track of the label name, i.e. label0, label1 , etc.
;; since we increment acc first and then generate the label, we can start from -1
(define acc -1)

;; label-generate produces one label each time being called,
;; start from label0, and the number is incremented each time.
(define (label-generate)
  ;; increment the acc first
  (set! acc (add1 acc))
  (string->symbol (string-append "label" (number->string acc))))

;; generate a label for the start of the function (Note since this is a psymbol produced in A-PRIMPL,
;; there is no underscore appended to the beginning)
;; E.g. (fcn-start-label 'main) -> START_main
(define (fcn-start-label fcn)
  (string->symbol (string-append "START_" (symbol->string fcn))))

;; --------------------- Helper function: changing variable name to specific format -----------------

;; Please refer to README, function stack to see the explanation for the use of these helpers

;; E.g. There's local variable named n in a function f
;; (add-val-label n f) -> _f_n_val
(define (add-val-label local id)
  (string->symbol (string-append "_" (symbol->string id) "_" (symbol->string local) "_val")))

;; E.g. There's local variable named n in a function f
;; (change-var n f) -> _f_n
(define (change-var sym id)
  (string->symbol (string-append "_" (symbol->string id) "_" (symbol->string sym))))

;; --------------------- Helpers concerning the function table --------------------------------------

;; make the function table global so we do not need to pass it around as parameters
(define fcn-tbl empty)

;; construct-fcn-table consnumes a program and an empty list, produces a list, with each element of
;; list being a reference to a function in the program
;; reference = (list fcn-name (listof parameter) (listof (list local value)))
;; construct-fcn-table will produce a list of such references
;; E.g. 
;(define test1 '((fun (main)
;                    (vars [(n 10) (a 1) (b 2)]
;                          (return 0)))
;               (fun (f x y)
;                    (vars [(v 1)]
;                          (return 0)))))
;; (construct-fcn-table test1 '()) ->
;'((f
;  (x y)
;  ((v 1)))
;  (main
;  ()
;  ((n 10) (a 1) (b 2))))


(define (construct-fcn-table prog tbl)
  (cond [(empty? prog) tbl]
        [else (construct-fcn-table (rest prog)
                         (match (first prog)
                           [(list 'fun (cons id lst-param) (cons 'vars (cons lst-local lst-stmt)))
                            
                            ;; if last statement is not return, report an error
                            (unless (and (not (empty? lst-stmt))
                                         (not (empty? (first (reverse lst-stmt))))
                                         (symbol=? 'return (first (first (reverse lst-stmt)))))                                         
                              (error "return"))
                            
                            ;; lst-var is a (listof Sym), where each element is the name of a
                            ;; variable of the first function of the prog, including both local
                            ;; and parameter
                            (define lst-var (append lst-param
                                                    (map (lambda (x) (first x)) lst-local)))
                            ;; lenx is the length of lst-param, not lst-var 
                            (define lenx (length lst-param))

                            ;; checking if there's duplicated definition of variables inside
                            ;; the function
                            (foldr (lambda (x y)
                                     (map (lambda (z)
                                            (when (symbol=? x z)
                                              (error "duplicate")))
                                          y)
                                     (cons x y))
                                   empty
                                   lst-var)

                            ;; checking if there's duplicated definition of function inside
                            ;; the program
                            (map (lambda (x)
                                   (when (symbol=? (first x) id) (error "duplicate")))
                                 tbl)

                            ;; checking if the function name duplicates the name of a built-in
                            ;; function
                            (unless (false? (optrans id)) (error "duplicate"))
                            
                            (cons (list id lst-param lst-local)
                                  tbl)]))]))

;; ------------- Helper that compile statements/ sequence of statements within functions ------------

;; A simple helper for pattern matching in compile-stmt
(define (aop? aop)
  (define result (optrans aop))
  (if (not result) false true))

;; compile-stmt compiles a statement within a function. Given we need to reference a variable
;; with respect to the function in which it's defined, the function takes two parameters,
;; the program, and the function name as a Symbol.
(define (compile-stmt prog id)
  (match prog
    ;; Please refer to the compiling part of the README for the idea of compiling adopted
    ;; by this compiler. Only necessary explanation regarding compiling certain specific
    ;; statements will be documented here.
    [(? number? prog)
     `((add sp sp 1)
       (move (-1 sp) ,prog))]
    [(? symbol? prog) 
     `((add sp sp 1)
       (move (-1 sp) ,(cond [(symbol=? prog 'true) 'true]
                            [(symbol=? prog 'false) 'false]
                            [else `(,(change-var prog id) fp)])))]
    [`(return ,aexp)
     (define fcn (assoc id fcn-tbl))
     (if (symbol=? id 'main)
         `((halt))
         (append (compile-stmt aexp id)
                 `((move (-1 fp) (-1 sp))
                   (move sp fp)
                   (move fp (RETURN_fp fp))
                   (jump (RETURN_ADDR sp)))))]
    [(cons 'seq seq-stmt)
     (compile-stmt-seq seq-stmt id)]
    [`(set ,var ,exp)
     (append (compile-stmt exp id)
             `((move (,(change-var var id) fp) (-1 sp))
               (sub sp sp 1)))]
    [`(skip) empty]
    [(cons 'while (cons exp seq-stmt))
     (define LABEL0 (label-generate)) ;; using label generator for distinct labels each time
     (define LABEL1 (label-generate))
     (define LABEL2 (label-generate))
     (append `((label ,LABEL0))
             (compile-stmt exp id)
             `((branch (-1 sp) ,LABEL1)
               (sub sp sp 1)   
               (jump ,LABEL2)
               (label ,LABEL1)
               (sub sp sp 1))  
             (compile-stmt-seq seq-stmt id)
             `((jump ,LABEL0)
               (label ,LABEL2)
               ))]
    [`(iif ,exp ,stmt1 ,stmt2)
     (define LABEL0 (label-generate))
     (define LABEL1 (label-generate))
     (define LABEL2 (label-generate))
     (append (compile-stmt exp id)
             `((branch (-1 sp) ,LABEL0)
               (sub sp sp 1)  
               (jump ,LABEL1)
               (label ,LABEL0)
               (sub sp sp 1)) 
             (compile-stmt stmt1 id)
             `((jump ,LABEL2)
               (label ,LABEL1))
             (compile-stmt stmt2 id)
             `((label ,LABEL2)))]
    [(cons 'and seq-stmt)
     (define LABEL0 (label-generate))
     (append `((add sp sp 1))
             (foldr (lambda (x y)
                      (append `((sub sp sp 1))
                              (compile-stmt x id)
                              `((lnot (-1 sp) (-1 sp))
                                (branch (-1 sp) ,LABEL0))
                              y))
                    `((label ,LABEL0)
                      (lnot (-1 sp) (-1 sp)))
                    seq-stmt))]
    [(cons 'or seq-stmt)
     (define LABEL0 (label-generate))
     (append `((add sp sp 1))
             (foldr (lambda (x y)
                      (append `((sub sp sp 1))
                              (compile-stmt x id)
                              `((branch (-1 sp) ,LABEL0))
                              y))
                    `((label ,LABEL0))
                    seq-stmt))]
    [`(not ,bexp)
     (append `((add sp sp 1))
             (compile-stmt bexp id)
             `((lnot (-2 sp) (-1 sp))
               (sub sp sp 1)))]
    [`(print ,(? string? str))
     `((print-string ,str))]
    [`(print ,aexp)
     (append (compile-stmt aexp id)
             `((print-val (-1 sp))
               (sub sp sp 1)))]
    [`(,(? aop? aop) ,aexp1 ,aexp2)
     (append `((add sp sp 1))
             (compile-stmt aexp1 id)
             (compile-stmt aexp2 id)
             `((,(optrans aop) (-3 sp) (-2 sp) (-1 sp))
               (sub sp sp 2)))]
    [(cons fun lst-param)

     ;; assure the function call has correct amount of parameters
     (define fcn (assoc fun fcn-tbl))
     (unless (= (length (second fcn)) (length lst-param)) (error "arguments"))

     
     (append `((add sp sp 1)
               ;; set up RETURN_fp
               ;; (add sp sp 2) since we need to skip RETURN_ADDR as well,
               ;; we will come back later and set up RETURN_ADDR with jsr
               (move (1 sp) fp)
               (add sp sp 2))

             ;; set up the parameters
             (foldr (lambda (x y)
                      (append (compile-stmt x id) y))
                    empty
                    lst-param)

             ;; To place fp to the correct position (since now sp points to
             ;; (# of parameters + 3) ahead of where fp is supposed to be
             ;; for the current stack frame, we need to restore this
             ;; position from calculation, and move fp to the correct place

             ;; Note there could probably be a much neater way of doing this,
             ;; but our design of stack frame forces the situation to be complicated
             ;; A beter design of stack frame (e.g. places the parameters as
             ;; negative offset such as (-1 fp) might help much better)
             `((add sp sp 1)
               (add (-1 sp) ,(* -1 (+ (length (second fcn)) 3)) sp)
               (move fp (-1 sp))
               (sub sp sp 1))
             
             `((jsr (0 fp) ,(fcn-start-label fun))))]))

;; Compiling a list of statements is simply to compile the statements one by one, and
;; here we use simple recursion
(define (compile-stmt-seq seq-stmt id)
  (cond [(empty? seq-stmt) empty]
        [else (append (compile-stmt (first seq-stmt) id)
                      (compile-stmt-seq (rest seq-stmt) id))]))

;; translate operators in SIMPL to corresponding ones in A-PRIMPL
(define (optrans op)
  (match op
    ['+ 'add]
    ['* 'mul]
    ['- 'sub]
    ['div 'div]
    ['mod 'mod]
    ['> 'gt]
    ['>= 'ge]
    ['< 'lt]
    ['<= 'le]
    ['= 'equal]
    ['not 'lnot]
    ['iif 'if]
    ['and 'and]
    ['or 'or]
    ['set 'set]
    ['seq 'seq]
    ['while 'while]
    ['skip 'skip]
    ['vars 'vars]
    ['true 'true]
    ['false 'f]
    [x false]))

;; ------------------- The compiler function: compile simpl -----------------------------------------

(define (compile-simpl prog)
  ;; Mutate the global variable fcn-tbl, for more detail, refer to the function
  ;; definition of construct-fcn-table above
  (set! fcn-tbl (construct-fcn-table prog '()))
  
  (append `((move fp sp)     ;; these ensure the places where fp and sp are held (the top
            (add fp fp 2)    ;; of the stack) will not be accidentally written
            (add sp sp 2))
          
          ;; if there's no main function, we simply halt the program at the beginning.
          ;; Otherwise we jump to the start of main function
          (if (false? (assoc 'main fcn-tbl))
              `((halt))
              `((jump START_main)))
          
          ;; refer to the structure of a function stack
          `((const RETURN_ADDR 0)
            (const RETURN_fp 1))

          ;; compiling list of function definitions (prog)
          (foldr (lambda (x y)
                   (append (match x
                             [(list 'fun
                                    (cons id lst-param)
                                    (cons 'vars (cons lst-local lst-stmt)))

                              ;; acc starts with one since we place return_ADDR at (0 fp)
                              ;; and return_fp at (1 fp)
                              (define acc 1)

                              ;; since no function is calling main, and we set up return_ADDR
                              ;; and return_fp during function call, the acc of main should
                              ;; start with -1
                              (when (symbol=? id 'main) (set! acc -1))
                              
                              (append `((label ,(fcn-start-label id))) ;; label the start of function

                                      ;; setting up the values of locals
                                      ;; (refer to the README, function frame management for detail)
                                      (foldr (lambda (x y)
                                               (append `((move
                                                          (,(change-var (first x) id) fp)
                                                          ,(add-val-label (first x) id))
                                                         (add sp sp 1))
                                                       y))
                                             empty
                                             lst-local)

                                      ;; compile the statements
                                      (compile-stmt-seq lst-stmt id)

                                      ;; setting up how to reference the parameters
                                      ;; (note parameters are already set up during function call)
                                      (foldl (lambda (x y)
                                               (append `((const ,(change-var x id)
                                                                ,(begin (set! acc (add1 acc))
                                                                        acc)))
                                                       y
                                                       ))
                                             empty
                                             lst-param)

                                      ;; setting up how to reference the locals
                                      (foldl (lambda (x y)
                                               (append `((const ,(change-var (first x) id)
                                                                ,(begin (set! acc (add1 acc))
                                                                        acc))
                                                         (data ,(add-val-label (first x) id)
                                                               ,(second x)))
                                                       y))
                                             empty
                                             lst-local))])
                           y))
                   empty
                   prog)
          
                 ;; set up fp and sp
                 `((data fp fp)
                   (data sp sp))))

;; -------------------------- Examples --------------------------------------------------------------

;; Running SIMPL program with the compiler:
;; (load-primp (primpl-assemble (compile-simpl prog)))
;; Then (run-primp), and the output of the SIMPL program should be produced

;; 1. The last statement of a function must be (return aexp), the "return"
;; error will be reported
(define test1 '((fun (f x y)
                     (vars [(n 1)]
                           (return (+ x y))))
                (fun (main )
                     (vars [] (print (f 1 2))))))

(check-error (compile-simpl test1))

;; 2. The # of arguments must match, or else the "arguments" error will be
;; reported
(define test2 '((fun (f x y)
                     (vars [(n 1)]
                           (return (+ x y))))
                (fun (main )
                     (vars [] (print (f 1))))))

(check-error (compile-simpl test2))

;; 3. If a function has duplicate names among the parameters and local
;; variables, or if there are duplicate function names, an "duplicate"
;; error will be reported
(define test3 '((fun (f x y)
                     (vars [(n 1)]
                           (return (+ x y))))
                (fun (f )
                     (vars [] (print (f 1))))))
(check-error (compile-simpl test2))

;; 4. A simple example of a loop to calculate the 10th power of 2, then print it
;; (load-primp (primpl-assemble (compile-simpl test4)))
;; Then (run-primp) should print 10th power of 2
(define test4 '((fun (main )
                     (vars [(x 10) (y 1)] 
                           (while (> x 0) 
                                  (set y (* 2 y)) 
                                  (set x (- x 1))) 
                           (print y)
                           (return 0)))))

;; 5. If main is not present, the program does nothing
(define test5 '((fun (f x y)
                     (vars [(n 1)]
                           (return (+ x y))))))

;; 6. This program calculates the factorial of 5 by accumulative recursion through the function
;; fact-h
(define test6 '((fun (fact-h n acc)
                     (vars []
                           (iif (> n 0)
                                (return
                                 (fact-h
                                  (- n 1)
                                  (* n acc)))
                                (return acc))
                           (return 0)))
                (fun (main )
                     (vars []
                           (print (fact-h 5 1))
                           (return 0)))))

(test)
