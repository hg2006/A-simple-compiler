# A SIMPL to A-PRIMPL Compiler, CS 146, W23
This compiler was done as two consecutive assignment question of CS 146, W23 offering, instructed by Brad Lushman, at the University of Waterloo. Relevant assignments are [Q9:Compile SIMPL](https://github.com/hg2006/A-simple-compiler/issues/1#issue-1689627528) and [Q10:Compile SIMPL-F](https://github.com/hg2006/A-simple-compiler/issues/2#issue-1689627569)

## Table of Contents

## A simple imperative language: SIMPL

### Motivation
SIMPL is an artificial imperative language, designed by the instructor team of CS 146, that only supports a very small subset of features of imperative programming. To avoid complicated parsing issues and only focus on the core concepts of imperative programming, S-expression syntax is used.
The following are the elements of imperative programming based on which SIMPL is developed:
- Statements that produce no useful value, but get things done through side effects.
- Expressions only as part of statements. (Note since in CS 146 we proceeded into imperative programming from functional programming, namely Racket, distinguishing between statements and expressions are important)
- Sequencing of two or more statements
- Conditional evaluation
- Repetition

### Grammar
Below is the grammar of simplest version of SIMPL, written in Haskell. <br> <br>

program	 	=	 	(vars [(id number) ...] stmt ...) <br> <br>


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
A program now is a sequence of functions. If there is a main function, that function si applied with no arguments to run the program; otherwise, the program does nothing (pretty much like how C works). <br> <br>
  program	=	function ...  <br> <br>
 	 	 	 	 
  function = (fun (id id ...) (vars [(id int) ...] stmt ...))
 	 	 	 	 
  aexp =	(id aexp ...) <br>
&emsp;&emsp; 	 	|	...
 	 	 	 	 
  stmt = (return aexp) <br>
&emsp;&emsp; 	 	| ...

## The Project
This project is about writing an compiler from SIMPL-F to A-PRIMPL, completed as two consecutive assignment questions of CS 146, W23 offering. For information about the assembly language, A-PRIMPL, and its associated machine language, PRIMPL, please refer to the [assembler project](https://github.com/hg2006/A-simple-assembler). For convenience, the [assembler](Assembler.rkt) and the [PRIMPL simulator](PRIMPL.rkt) have also been uploaded to this project. Therefore, he A-PRIMPL code produced by compiler can be further assembled into PRIMPL machine code, and executed by the PRIMPL simulator, if you will. There's a [user guide](...) at the end of the README file. <br>
With regard to the assignment, no starter code has been given except for the [PRIMPL simulator](PRIMPL.rkt), which was for the use of helping student understand the core of PRIMPL as well as facilitating debugging process. Another helpful resource was the assembler we wrote earlier, we used it along with the PRIMPL simulator for deugging purpose. Considering the difficulty of the assignment, the instructor team has allowed this assignment to be completed in pairs.

## Compiling
### Variables
To avoid conflicts, we will prefix the name of each SIMPL variable with an underscore character "_". This helps dinstinguish between variables in SIMPL and the variables we produce during compiling.

### Stack Frame
To support recursive calls for functions, we simulate a stack with two pointers, Stack Pointer ```sp``` and Frame Pointer ```fp```. <br>
Each function call will generate a stack frame that contains values for arguements, local variables, and other relative information such as its return address (more detailed information will be stated in the section [Compiling a Function Call](#compiling-a-function-call). <br>
<br>
The ```sp``` stores the address of the first available space in the stack, that is, ```sp``` points to the first available space in the simulated stack. <br>
The ```fp``` points to the first argument for the current function call (more detailed information will be stated in the section [Compiling a Function Call](#compiling-a-function-call)). <br> 
Both pointers are mutated and dereferenced by basic arithmetics, [move][...], and [offset][...] instructions. <br>
&emsp; E.g. ```(add sp sp 2)``` means to increment the ```sp``` by 2. <br>
&emsp; &emsp; &nbsp; ```(move (0 sp) fp)``` means to store the value stored in ```fp``` to the address where ```sp``` points to. <br>

### Stack space allocation, push & pop
Consider: ```(+ exp1 exp2)```. Compiling statement will recursively emit code to compute exp1, then exp2, and finally add. We need to allocate some stack space, and push the first value into stack for storage while compting for the second. After summing these two, we need to pop these two values out of stack so it can be reserved for future use. <br> <br>

The compiler deals with these three as as following:
- allocate space: ```(add sp sp 1)``` The sp has been incremented once, so the slot at the location  &ensp; ```sp-1``` becomes available
- push: ```(move (-1 sp) N)``` The value N is stored at the top of the stack
- pop: ```(sub sp sp N)``` The top N slots of the stack are freed, the values are popped <br> <br>

For this compiler, the rules for allocating temporary storage when compiling statements go as follows (we will discuss everything about functions in a later part): <br>
1. If the statement will be returning some value, it will allocate space itself, and then pop the returning value into the stack frame.
E.g. compiling ```5``` =>
```racket
     (add sp sp 1)
     (move (-1 sp) 5)
```
2. If the statement is expecitng some other statements to be executed beforehand (E.g. for compiling ```(+ 2 3)```we first need to compile 2 and 3), it will compile those statements first. Then, the statement proceeds with the temporary values stored into the stack by the previous compiled statements. It will also be responsible for popping out the temporary values stored by its sub-statements.
E.g. comping ```(+ exp1 exp2)``` =>
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

### (set var exp)
```racket
     compile exp         ;; Since set does not return, no (add sp sp 1) needed
     (move _var (-1 sp)) ;; Since the variable name is a SIMPL variable, we will append an underscore
     (sub sp sp 1)
```

### (iif exp stmt1 stmt2)
```racket
     compile exp
     (branch (-1 sp) label0)  ;; In the compiler, label0, label1, label2 will be labels produced           
     (sub sp sp 1)            ;; by a label generating machine to ensure each label is unique
     (jump label1)
     (label label0)
     (sub sp sp 1)
     compile stmt1
     (jump label2)
     (label label1)
     compile stmt2
     (label label2)
 ```





