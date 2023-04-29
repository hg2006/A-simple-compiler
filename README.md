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
### Basics

