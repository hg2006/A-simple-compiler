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

### Compiling a Function Definition
The number of the function arguments and local variables remains unchanged. Thus we are able to deduce the address of any variable of the function relative to the ```fp```. <br>
During the first scanning stage of the program, an association list that helps reference the function name to its (listof parameter) and (listof (list local value))
<br>
<br>
When compiling a function definition, a label with a name that corresponds to the function name is created for any future function calls to jump to. <br>
<br>
The compiled code for evaluating local variables and pushing them into the stack is appended (note that the process of evaluating and pushing the value of arguments will have be done at this point when [applying a function](#compiling-a-function-call)). <br>
The rest of the function definition is compiled as usual statements with all occurrences of variables are replaced by their addresses relative to the ```fp``` based on the previously generated ```environment```.

### Return
Each function produces an integer value through a ```return``` statement. <br>
To guarantee that there is always a returned value for a function, we defined a syntax rule that every function must have a ```return``` statement as its last statement. This rule is checked during the compilation of each function's definition, and the compiler will produces an error if it detects any instances of missing ```return```. <br>
<br>
The compiled code for evaluating the value for ```return``` is generated by the usual arithmetic expression compilation. Note that during our previous compiling process for other statements we push the newly generated value to the top of the stack and incremented the ```sp``` by 1. <br>
We then 
1. store the returning value in ```(-1 fp)```
2. set ```sp``` back to ```fp```
3. move ```fp``` back to where we should return ```fp``` to (this is stored in ```(1 fp)```)
4. jump to where ```PC``` should return to (stored in ```(0 fp)```)
(For how we managed the stack frame to store each relevant information mentioned above please refer to [Compiling a Function Call](#compiling-a-function-call)). <br> 
E.g. (return aexp) ->
```racket
compile aexp
(move (-1 fp) (-1 sp))   ;; (-1 sp) is where we stored the result of compiling aexp
(move sp fp)
(move fp (RETURN_fp fp)) ;; We will compile (const RETURN_fp 1) into the A-PRIMPL program at the beginning 
(jump (RETURN_ADDR sp))  ;; We will compile (const RETURN_ADDR 0) into the A-PRIMPL program at the beginning 

```


### Compiling a Function Call
Besides function arguments and local variables, there are several information should be stored for each funtion call, namely the value to ```return```, the previous value of the ```fp``` before it is mutated, as well as which code should be executed after the ```return``` (that is, the previous value of ```PC``` before it is mutated). <br>
Since the frame pointer and the stack pointer may be mutated constantly, a way to determine the information is to reserve spaces at the start of compiling the function call. <br>
We could have a dedicated space for the value to ```return```, but since we will only use it after we ```jump``` back from the function call, we could simply store it in the space that stores the previous value of ```PC```, and it will remains at the top of the stack after updates of the ```sp```. <br>
<br>
As a result, when compiling a function application, we reserve two spaces to store  the previous value of ```PC``` and the previous value of ```fp``` respectively, and we increment ```sp``` by 2 (so that it points to the first available space again). Then we include the compiled code to evaluating given arguements, and update the ```fp```. <br>
Then we [```jsr```][...] to the corresponding label while storing the current ```PC``` to the previously reserved space, namely ```(-2 fp)``` (this is how we determine where to ```jump``` back to when we compiling a [```return```](#return) in a function definition). <br>
We then move the produced value to its reserved space, update the ```sp``` relative to the ```fp```, and finally, update the ```fp``` back to the previous value of ```fp```. <br>



