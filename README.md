# A SIMPL to A-PRIMPL Compiler, CS 146, W23
This compiler was done as two consecutive assignment questions of CS 146, W23 offering, instructed by Brad Lushman, at the University of Waterloo. Relevant assignments are [Q9:Compile SIMPL](https://github.com/hg2006/A-simple-compiler/issues/1#issue-1689627528) and [Q10:Compile SIMPL-F](https://github.com/hg2006/A-simple-compiler/issues/2#issue-1689627569)

## Table of Contents
- [A Simple Imperative Language: SIMPL](#a-simple-imperative-language-simpl) <br>
&emsp;[Motivation](#motivation) <br>
&emsp;[Grammar](#grammar) <br>
&emsp;[SIMPL-F: Supporting Functions](#simpl-f-supporting-functions) <br>
- [The Project](#the-project) <br>
- [Compiling](#compiling) <br>
&emsp;[Variables](#variables) <br>
&emsp;[Stack Frame](#stack-frame) <br>
&emsp;[Compiling statements within function](#compiling-statements-within-function) <br>
&emsp;[Compiling a Function Definition](#compiling-a-function-definition) <br>
&emsp;[Return](#return) <br>
&emsp;[Compiling a Function Call](#compiling-a-function-call) <br>


---
## A simple imperative language: SIMPL
### Motivation
SIMPL is an artificial imperative language, designed by the instructor team of CS 146, that only supports a very small subset of features of imperative programming. To avoid complicated parsing issues and only focus on the core concepts of imperative programming, S-expression syntax is used.
The following are the elements of imperative programming based on which SIMPL is developed:
- Statements that produce no useful value, but get things done through side effects.
- Expressions only as part of statements. (Note since in CS 146 we proceeded into imperative programming from functional programming, namely Racket, distinguishing between statements and expressions are thus important)
- Sequencing of two or more statements
- Conditional evaluation
- Repetition

### Grammar
Below is the grammar of a simpler version of SIMPL, written in Haskell. We have excluded everything about function in here and will introduce them later in [SIMPL-F: Supporting Functions](#simpl-f-supporting-functions)  <br> <br>

program	 	=	 	(vars [(id number) ...]   stmt ...) <br> <br>


  stmt = (print aexp)  <br>
 &emsp;&emsp;    | (print string) <br>
 &emsp;&emsp;    | (set id aexp) <br>
 &emsp;&emsp; 	  | (seq stmt ...) <br>
 &emsp;&emsp;     | (iif bexp stmt stmt) <br>
 &emsp;&emsp;     | (skip) <br>
 &emsp;&emsp;	 	  | (while bexp stmt ...) <br> <br>

 aexp	=	(+ aexp aexp) <br>
&emsp;&emsp; 	 	  |	(* aexp aexp) <br>
&emsp;&emsp; 	 	  |	(- aexp aexp) <br>
&emsp;&emsp; 	 	  |	(div aexp aexp) <br>
&emsp;&emsp; 	 	  |	(mod aexp aexp) <br>
&emsp;&emsp; 	 	  |	number <br>
&emsp;&emsp; 	 	  |	id <br> <br>
 	 	 	 	 
 bexp = (= aexp aexp) <br>
&emsp;&emsp; 	 	  | (> aexp aexp) <br>
&emsp;&emsp;	 	   |	(< aexp aexp) <br>
&emsp;&emsp; 	    |	(>= aexp aexp) <br>
&emsp;&emsp; 	    |	(<= aexp aexp) <br>
&emsp;&emsp; 	 	  |	(not bexp) <br>
&emsp;&emsp; 	 	  |	(and bexp ...) <br>
&emsp;&emsp; 	 	  |	(or bexp ...) <br>
&emsp;&emsp; 	 	  |	true <br>
&emsp;&emsp; 	 	  |	false <br> <br>

### SIMPL-F: Supporting Functions
Syntax for defining functions in SIMPL-F: <br>
A program now is a sequence of functions. If there is a main function, that function is applied with no arguments to run the program; otherwise, the program does nothing (pretty much like how C works). <br> <br>
  program	=	function ...  <br> <br>
 	 	 	 	 
  function = (fun (id id ...) (vars [(id int) ...] stmt ...))
 	 	 	 	 
  aexp =	(id aexp ...) <br>
&emsp;&emsp; 	 	|	...
 	 	 	 	 
  stmt = (return aexp) <br>
&emsp;&emsp; 	 	| ...

---

## The Project
This project is about writing an compiler from SIMPL-F to A-PRIMPL, completed as two consecutive assignment questions of CS 146, W23 offering. For information about the assembly language, A-PRIMPL, and its associated machine language, PRIMPL, please refer to the [assembler project](https://github.com/hg2006/A-simple-assembler). For convenience, the [assembler](Assembler.rkt) and the [PRIMPL simulator](PRIMPL.rkt) have also been uploaded to this project. Therefore, he A-PRIMPL code produced by compiler can be further assembled into PRIMPL machine code, and executed by the PRIMPL simulator. <br>
With regard to the assignment, no starter code has been given except for the [PRIMPL simulator](PRIMPL.rkt), which was for the use of helping student understand the core of PRIMPL as well as facilitating debugging process. Another helpful resource was the assembler we wrote earlier, we used it along with the PRIMPL simulator for deugging purpose. Considering the difficulty of the assignment, the instructor team has allowed this assignment to be completed in pairs.

---

## Compiling
### Variables
To avoid conflicts, we will prefix the name of each SIMPL variable with an underscore character "_". This helps dinstinguish between variables in SIMPL and the variables we produce during compiling.

### Stack Frame
To support recursive calls for functions, we simulate a stack with two pointers, Stack Pointer ```sp``` and Frame Pointer ```fp```. <br>
Each function call will generate a stack frame that contains values for arguements, local variables, and other relative information such as its return address (more detailed information will be stated in the section [Compiling a Function Call](#compiling-a-function-call)). <br>
<br>
```sp``` points to the first available space in the simulated stack. <br>
The ```fp``` points to the starting point for the current function call in the stack space. <br> 
Both pointers are mutated and dereferenced by basic arithmetics, ```move```, and ```offset``` instructions (see ["Grammar of PRIMPL" in assembler project](https://github.com/hg2006/A-simple-assembler/blob/main/README.md#grammar-and-other-details-of-primpl)). <br>
&emsp; E.g. ```(add sp sp 2)``` means to increment the ```sp``` by 2. <br>
&emsp; &emsp; &nbsp; ```(move (0 sp) fp)``` means to store the value stored in ```fp``` to the address where ```sp``` points to. <br>

### Compiling statements within function
Consider: ```(+ exp1 exp2)``` <br>
Compiling statement will recursively emit code to compute exp1, then exp2, and finally add. We need to allocate some stack space, and push the computed value of exp1 into stack for storage while compting for the second. After summing these two, we need to pop these two values out of stack so it can be reserved for future use. <br> <br>

The compiler deals with these three as as following:
- allocate space: ```(add sp sp 1)``` The ```sp``` has been incremented once, so the slot at the location ```(-1 sp)``` becomes available
- push: ```(move (-1 sp) N)``` The value N is stored at the top of the stack
- pop: ```(sub sp sp N)``` The top N slots of the stack are freed, the values are popped <br> <br>

For this compiler, the rules for allocating temporary storage when compiling statements go as follows (we will discuss everything about functions in a later part): <br>
1. If the statement will be returning some value, it will allocate space itself, and then push the returning value into the stack frame. <br>
E.g. compiling ```5``` =>
```racket
     (add sp sp 1)
     (move (-1 sp) 5)
```
2. If the statement is expecting some other statements to be executed beforehand (E.g. for compiling ```(+ 2 3)```we first need to compile 2 and 3), it will compile those statements first. Then, the statement proceeds with the temporary values stored into the stack by the previous compiled statements. It will also be responsible for popping out the temporary values stored by its sub-statements. <br>
E.g. compiling ```(+ exp1 exp2)``` =>
```racket
     (add sp sp 1)                 ;; Reserve space for the return of statement itself
     compile exp1
     compile exp2
     (add (-3 sp) (-2 sp) (-1 sp)) ;; Since compiling exp1 and exp2 will increment sp by exactly 2,
                                   ;; the returning spot for the current statement is (-3 sp).
                                   ;; Note for subtraction and some other statements the order
                                   ;; of (-2 sp) and (-1 sp) could be important
     (sub sp sp 2)                 ;; Pop the temporary values stored by exp1 and exp2  
```
<br>Techniques for compiling most of the other statements are similar to the way we compile ```(+ exp1 exp2)``` , we provide a few more examples of others.

#### (set var exp)
```racket
     compile exp         ;; Since set does not return, no (add sp sp 1) needed
     (move _var (-1 sp)) ;; Since the variable name is a SIMPL variable, we will append an underscore
     (sub sp sp 1)
```

#### (iif exp stmt1 stmt2)
```racket
     compile exp
     (branch (-1 sp) label0)  ;; In the compiler, label0, label1, label2 will be labels produced           
     (sub sp sp 1)            ;; by a label generating function to ensure each label is unique
     (jump label1)
     (label label0)
     (sub sp sp 1)
     compile stmt1
     (jump label2)
     (label label1)
     compile stmt2
     (label label2)
 ```
 
 #### (while exp stmt)
```racket     
  (label label_top)               ;; In the compiler, unique label names will be generated by appending a counter
  compile exp
  (sub sp sp 1)                   ;; now (0 sp) stores the result of [exp]
  (branch (0 sp) label_body)      ;; its value is no longer useful after the condition check
  (jump label_end)
  (label label_body)
  compile stmt
  (jump label_top)
  (label while_end)
 ```

### Compiling a Function Definition
The number of the function arguments and local variables remains unchanged. Thus we are able to deduce the address of any variable of the function relative to the ```fp```. Therefore, this compiler is designed to have each stack frame initialized as follows: <br>
```racket
     return value   ;; to save the return value of the current function
fp-> return_ADDR    ;; where pc should return to 
     return_fp      ;; where fp should return to
     parameters
     locals
sp-> temporary storage   
```
As an example, the function ```(f x y)```, with ```x``` and ```y``` as parameters, in addition with ```n``` and ```m``` as locals, will have a stack frame initialized as follows: <br>
```racket
     return value   ;; to save the return value of the current function
fp-> return_ADDR    ;; where pc should return to 
     return_fp      ;; where fp should return to
     _f_x           ;; parameters
     _f_y
     _f_n           ;; locals
     _f_m
sp-> temporary storage starts here  
```
When managing the A-PRIMPL instruction to set up a stack frame for the function, we will leave the work of initializing the ```return value```, ```return_ADDR```, ```return_fp```, ```parameters```, as well as placing the ```fp``` to the correct position to [Function call](compiling-a-function-call). When compiling a function definition, we need to:
1. Set up a label for the start of the function, i.e. ```(label start_f)```
2. Generating A-PRIMPL instruction to set up the value of locals in the stack frame (note we've already set up everything before locals in the stack frame during the function call)
3. Generating A-PRIMPL instruction to help referene the parameters (the values of parameters are set up in the stack frame by function call, but we need a way to reference them with respect to ```fp```)
4. Generatinbg A-PRIMPL instruction to help reference the locals. <br>

Taking the example above again, consider ```(f x y)``` with ```n=2``` and ```m=3``` as locals, below is a sketch for the code block of function definition for function ```f```:
```racket
(label START_f)

(move (_f_n fp) _f_n_val)
(add sp sp 1)
(move (_f_m fp) _f_m_val)
(add sp sp 1)

compile statements of f

(const _f_y 3)
(const _f_x 2)

(const _f_n 4)
(data _f_n_val 2)
(const _f_m 5)
(data _f_m_val 3)

```
### Return
Each function produces an integer value through a ```return``` statement. (Note returning void is not supported in SIMPL)<br>
To guarantee that there is always a returned value for a function, we defined a syntax rule that every function must have a ```return``` statement as its last statement. This rule is checked during the compilation of each function's definition, and the compiler will produces an error if it detects any instances of missing ```return```. <br>
<br>
The compiled code for evaluating the value for ```return``` is generated by the usual arithmetic expression compilation. Note that during our previous compiling process for other statements we push the newly generated value to the top of the stack and incremented the ```sp``` by 1. <br>
We then 
1. store the returning value in ```(-1 fp)```
2. set ```sp``` back to ```fp```
3. move ```fp``` back to where we should return ```fp``` to (this is stored in ```(1 fp)```)
4. jump to where ```PC``` should return to (stored in ```(0 sp)``` at this point since ```fp``` is moved away already) <br>

For how we managed the stack frame to store each relevant information mentioned above please refer to [Compiling a Function Call](#compiling-a-function-call). <br>

E.g. ```(return aexp)``` ->
```racket
compile aexp
(move (-1 fp) (-1 sp))   ;; (-1 sp) is where we stored the result of compiling aexp
(move sp fp)
(move fp (RETURN_fp fp)) ;; We will compile (const RETURN_fp 1) into the A-PRIMPL program at the beginning 
(jump (RETURN_ADDR sp))  ;; We will compile (const RETURN_ADDR 0) into the A-PRIMPL program at the beginning 

```

### Compiling a Function Call
As described above, besides function arguments and local variables, some other information should also be stored for each funtion call, namely the returning value, the ```return_fp```, where fp should be reset to, as well as ```return_ADDR```, to which we should reset the ```PC``` to. We will handle these along with setting up the parameters while compiling a function call.<br>

As a result, when compiling a function application, we reserve two spaces to store ```return_ADDR``` and ```return_fp```, and we increment ```sp``` by 2 (so that it points to the first available space in stack again). Then we include the compiled code to evaluating given arguements, and update the ```fp```. Note updating the ```fp``` can be a bit tricky due to how this compiler structures the stack frame (please refer to the comments in the code below for further detail). <br>

After everything above gets set, we ```jsr``` to jump to the corresponding label while storing the current ```PC``` to the previously reserved space, namely ```(0 fp)```. At this point, everything about the function call is done. As the program runs through the jsr, it will head to the start of the corresponding function definition and start executing the instructions there.<br>

E.g. Compiling ```(f 2 3)``` ->      (the locals in f are handled in compiling function definition, thus ignored here)

```racket
(add sp sp 1)
(move (1 sp) fp)     ;; set up RETURN_fp
(add sp sp 2)        ;; (add sp sp 2) since we need to skip RETURN_ADDR and RETURN_fp,
                     ;; we will come back later and set up RETURN_ADDR with jsr
compile 2            ;; we do not move fp at this point since we might still need 
compile 3            ;; to reference variables of current function, e.g. (f x y) where
                     ;; x is a local of f
(add sp sp 1)        
(add (-1 sp) (* -1 (+ 3 (# of parameters))) sp) ;; tricky part, sp at at this point is
(move fp (-1 sp))                               ;; (# of parameters + 3) ahead of where fp supposed to be
(sub sp sp 1)   

(jsr (0 fp) START_f)
```




