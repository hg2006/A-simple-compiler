#lang racket

;; ----------------------------- At the Beginning ---------------------------------------------------

;; Uncomment this to enable the use of PRIMPL simulator
;; (require "PRIMPL.rkt")

;; Uncomment this to provide the assembler to other racket files
;;(provide primpl-assemble)

;; This is an assembler that assembles A-PRIMPL to the virtual machine language, PRIMPL. For a
;; thorough explanations of grammar of PRIMPL, its designation, and new features supported in
;; A-PRIMPL, please refer to the README file.

;; An A-PRIMPL program should be put into the function primpl-assemble as a list, with each element
;; of the list being an A-PRIMPL instruction/data, presented in list form.
;; E.g.
;; '((add (2) (3) (4))
;;   (halt)
;;    0
;;    1
;;    2)

;; Several examples of assembling are provided at the end in the form of check-expect

;; ----------------------------- Helper: Expand -----------------------------------------------------

;; (expand inst-lst revs-store acc) consumes a list of A-PRIMPL instructions. It turns all 
;; higher-level features of A-PRIMPL instruction into corresponding PRIMPL-instruction, with
;; the exception of substitution of psymbols with their bounded values. The substitution of psymbols
;; with their bounded value will take place in the main assembler function. As for expand, it
;; produces a list containing two elements, the first being the list of instructions with the
;; higher-level features of A-PRIMPL instruction converted. The second being the assoc-list
;; of all psymbols defined in the list of A-PRIMPL instructions with their corresponding definition.
;; expand handles circular, duplicate, and part of undefined & incorrect errors in the definition
;; & use of psymbols
;; Below some examples of how higher-level features of A-PRIMPL instructions are converted by expand
;; (Note we've ignored the assoc-list produced in the following examples)
;;   (halt) -> 0
;;   (data (3 5)) -> '(5 5 5) (assume it will be appended to the instr-list)
;;   (data A B) -> B (and (A X) will be added to the assoc-list with X being
;;                   value of the index of the memory vector location where the first data item)
;;   (lit 4) -> 4
;;   (label A) -> '() (append it to the instr-list, so this is basically nothing,
;;                     and (A X) will be added to the assoc-list with X being the
;;                     index of the memory vector where the next actual instruction would be loaded)
;;   (const A 5) -> '()
;;                     and (A 5) will be added to the assoc-list


;; expand : (listof instr) empty empty -> (list (listof instr) (assoc-list of psymbol defn))
(define (expand inst-lst revs-store acc)
  (cond [(empty? inst-lst) (list (reverse revs-store) acc)]
        [else
         (define v (first inst-lst))
         (define l (length revs-store))
         (match v
           [`(halt)
            (expand (rest inst-lst)
                    (cons 0 revs-store)
                    acc)]
           [`(lit ,dest)
            (expand (rest inst-lst)
                    (cons dest revs-store)
                    acc)]
           [`(const ,(? symbol? sym) ,dest)
            (expand (rest inst-lst)
                    revs-store
                    (duplicate-cons `(,sym (,dest const)) acc))]
           [`(data ,(? symbol? sym) (,nat ,dest))
            (unless (and (integer? nat) (> nat 0)) (error "incorrect"))
            (expand (rest inst-lst)
                    (append (build-list nat (lambda (x) dest)) revs-store)
                    (duplicate-cons `(,sym (,l data)) acc))]
           [(cons 'data (cons (? symbol? sym) lst-var))
            (expand
             (rest inst-lst)
             (foldl cons revs-store (if (empty? lst-var) (error "incorrect") lst-var))
             (duplicate-cons `(,sym (,l data)) acc))]
           [`(label ,(? symbol? sym))
            (expand (rest inst-lst)
                    revs-store
                    (duplicate-cons `(,sym (,l label)) acc))]
           ;; A psymbol should not appear alone in an A-PRIMPL instruction list,
           ;; this is incorrect grammar.
           [(? symbol? x) (error "incorrect")]
           ;; If it's not part of the new feature in A-PRIMPL, leave it as it is.
           [x (expand (rest inst-lst)
                      (cons x revs-store)
                      acc)])]))

;; -------------------------- Helper Group 1 --------------------------------------------------------

;; These helper functions are for the use of constructing an assoc-list of psymbol definitions while
;; the function expand is going through the program. Each of them will be responsible for checking
;; some kind of error related to the psymbol definitions. These functions will ensure the
;; final assoction list of psymbol definitions produced by the function expand will be free of 
;; circular, undefined and duplicate errors. The assoc-list will then be turned into a hash-table
;; for future reference when assembling.

;; (duplicate-cons x lst) is like cons but prevents duplicate from appearing
;;  in the resulting association list
;; duplicate-cons : psymbol assoc-list -> assoc-list
(define (duplicate-cons x lst)
  (map (lambda (y)
         (when (symbol=? (first x) (first y))
           (error "duplicate")))
       lst)
  (cons x lst))

;; (replace tbl len) removes occuring nested referencing in an association list
;; E.g. it will change '((A B) (B 2)) to '((A 2) (B 2))
;; It will also report "circular" error, such as '((A B) (B A))
;; replace : assoc-list -> assoc-list
(define (replace tbl len)
  (for [(i len)]
    (match (list-ref tbl i) ;; Racket built-in list-ref is almost O(1).
                            ;; For improvement, change this to a vector.
      [`(,key1 (,val1 ,type1))
       (when (equal? key1 val1) (error "circular"))
       (for [(j len)]
         (if (= i j)
             (void)
             (match (list-ref tbl j)
               [`(,key2 (,val2 ,type2))
                (cond[ (equal? key1 val2)                     
                       (set! tbl (list-set tbl j `(,key2 (,val1 ,type2))))]
                     [else (void)])])))]))
  tbl)

;; (error-check assoc-list) checks if a psymbol is defined by another undefined psymbol
;;  in the assoc list, if so, reports an "undefined" error
;; E.g. '((A B) (B 2)) is good, but '((A B)) has an undefined error since B undefined.
;; error-check : assoc-list -> assoc-list
(define (error-check assoc-list)
  (map (lambda (x)
         (match x
           [`(,key (,val ,type))
            (when (symbol? val) (error "undefined" val))
            x]))
       assoc-list))


;; -------------------------- Helper Group 2 --------------------------------------------------------
;; These helper functions are for the use of replacing operands in the main assembler function.
;; Note an operand can be imm, ind or (imm ind). Since imm and ind have different restrictions
;; regarding substitution of psymbol (see README), two different helpers match-opd and match-ind
;; will be used. match-opd will deal with all three possible cases of an operand, while  match-ind
;; will only deal with indirect.
;; When encountering a psymbol, match-opd and match-ind will replace them with the definition,
;; referencing to the hash-table, and respecting the restriction of the context those psymbols are
;; placed in. They will also report the error of undefined or incorrect when encountering them.

;; (match-opd opd hash-tbl label?) replaces psymbol in instruction with
;;  what it refers to, with respect to the hash-table and the context the psymbol
;; is placed in.
;; match-opd : (anyof num (num) sym) hash-table bool -> opd
(define (match-opd opd hash-tbl label?)
  (match opd
    [(? number? opd) opd]
    [`(,(? number? i)) opd]
    [(? symbol? opd)
     (define res (hash-ref hash-tbl opd 'unbound))
     (match res
       ['unbound (error "undefined" opd)]
       [`((,dest label)) (if label?
                             dest
                             (error "incorrect" opd))]
       [`((,dest const)) (if label?
                             (error "incorrect" opd)
                             dest)]
       [`((,dest data)) (list dest)])]
    [`(,i ,j)
     (list (match i
             [(? symbol? v)
              (define res (hash-ref hash-tbl v 'unbound))
              (match res
                ['unbound (error "undefined" v)]
                [`((,dest 'label)) (error "incorrect")]
                [x (first (first x))])]
             [x x])
           (match-ind j hash-tbl))]))



;; (match-ind ind hash-tbl) replaces psymbol in instruction with what it 
;;  refers to, with respect to the hash-table and the context the psymbol
;; match-ind : (anyof num (num) sym) hash-table -> ind
(define (match-ind opd hash-tbl)
  (match opd
    [`(,(? number? i)) opd]
    [`(,(? number? i) (,(? number? j))) opd]
    [`(,(? number? i) ,(? symbol? j))
     (define res (hash-ref hash-tbl j 'unbound))
     (match res
       ['unbound (error "undefined" j)]
       [`((,dest 'label)) (error "incorrect")]
       [x (list i (list (first (first x))))])]
    [(? symbol? opd)
     (define res (hash-ref hash-tbl opd 'unbound))
     (match res
       ['unbound (error "undefined" opd)]
       [`((,dest data)) (list dest)]
       [x (error "incorrect")])]
    [`(,i ,j)
     (list (match i
             [(? symbol? v)
              (define res (hash-ref hash-tbl v 'unbound))
              (match res
                ['unbound (error "undefined" v)]
                [`((,dest 'label)) (error "incorrect")]
                [x (first (first x))])]
             [x x])
           (match-ind j hash-tbl))]))


;; -------------------------- Assembler -------------------------------------------------------------


;; primpl-assemble : (listof a-prim-inst) -> (listof prim-inst)
(define (primpl-assemble inst-lst)
  (define expand-result (expand inst-lst empty empty))
  (define expanded-lst-instr (first expand-result))
  (define assoc-psymbol-defn (second expand-result))
  (define hash-tbl (make-hash (error-check (replace assoc-psymbol-defn
                                                    (length assoc-psymbol-defn)))))
  (map (lambda (v)
         (match v
           [(? number? v) v]
           [(? symbol? v)
            (define res (hash-ref hash-tbl v 'unbound))
            (match res
              ['unbound (error "undefined" v)]
              [x (first (first x))])]
           ;; Note we do not allow label to be as the target of branch
           [`(branch ,opd1 ,opd2)
            `(branch ,(match-opd opd1 hash-tbl false)
                     ,(match-opd opd2 hash-tbl true))]
           [`(jump ,opd)
            `(jump ,(match-opd opd hash-tbl true))]
           [`(jsr ,dest ,pc)
            `(jsr ,(match-ind dest hash-tbl)
                  ,(match-opd pc hash-tbl true))]
           [`(,op ,dest ,opd1 ,opd2)
            `(,op ,(match-ind dest hash-tbl)
                  ,(match-opd opd1 hash-tbl false)
                  ,(match-opd opd2 hash-tbl false))]
           [`(,op ,dest ,opd)
            `(,op ,(match-ind dest hash-tbl)
                  ,(match-opd opd hash-tbl false))]
           [`(print-val ,opd)
            `(print-val ,(match-opd opd hash-tbl false))]
           [`(print-string ,str)
            `(print-string ,str)]))
       expanded-lst-instr))

;; -------------------------- Example ---------------------------------------------------------------

;; This A-PRIMPL program below calculates and prints the powers of 2, from 1 to 10, each separated
;; a newline:
(define aprimpl1  '((label LOOP-TOP)        ; loop-top:
                    (gt TMP1 X 0)           ;  tmp1 <- (x > 0)
                    (branch TMP1 LOOP-CONT) ;  if tmp1 goto loop-cont
                    (jump LOOP-DONE)        ;  goto loop-done
                    (label LOOP-CONT)       ; loop-cont:
                    (mul Y 2 Y)             ;  y <- 2 * y
                    (sub X X 1)             ;  x <- x - 1
                    (print-val Y)           ;  print y
                    (print-string "\n")     ;  print "\n"
                    (jump LOOP-TOP)         ;  goto loop-top
                    (label LOOP-DONE)       ; loop-done:
                    (halt)                  ;  halt
                    (data X 10)
                    (data Y 1)
                    (data TMP1 0)))

;; (primpl-assemble aprimpl1) should produce primpl1
(define primpl1 '((gt (11) (9) 0)
                  (branch (11) 3)
                  (jump 8)
                  (mul (10) 2 (10))
                  (sub (9) (9) 1)
                  (print-val (10))
                  (print-string "\n")
                  (jump 0)
                  0
                  10
                  1
                  0))

;; (load-primp primpl1), and then
;; (run-primp)
;; should produce the desired result
