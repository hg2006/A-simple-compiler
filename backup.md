#backup
### Compiling a Function Definition
The number of the function arguments and local variables remains unchanged. Thus we are able to deduce the address of any variable of the function relative to the ```fp```. <br>
During the first scanning stage of the program, a table (```environment```) that maps each variable to the address in the stack relative to the ```fp``` where the value of such variable may be stored in during a function applicaiton. <br>
<br>
When compiling a function definition, a label with a name that corresponds to the function name is created for any future function calls to jump to. <br>
<br>
The compiled code for evaluating local variables and pushing them into the stack is appended (note that the process of evaluating and pushing the value of arguments will have be done at this point when [applying a function](#compiling-a-function-call)). <br>
The rest of the function definition is compiled as usual statements with all occurrences of variables are replaced by their addresses relative to the ```fp``` based on the previously generated ```environment```.

### Return
Each function produces an integer value through a ```return``` statement. <br>
To guarantee that there is always a returned value for a function, we defined a syntax rule that every function must have a ```return``` statement as its last statement. This rule is checked during the compilation of each function's definition, and the compiler will produces an error if it detects any instances of missing ```return```. <br>
<br>
The compiled code for evaluating the value for ```return``` is generated by the usual arithmetic expression compilation. Note that during our previous compiling process for other statements we push the newly generated value to the top of the stack and incremented the ```sp``` by 1. Since essentially ```return``` is a statement to pass through the value that a function (a block of statements) produces, we may assume the same rule for ```return```. <br>
After we push the value to the stack, we should add an instruction to ```jump``` back to the statement right after the function call. The previous value of ```PC``` is stored in ```(-2 fp)``` (The process of determined the address where the original ```PC``` is stored is stated in the section [Compiling a Function Call](#compiling-a-function-call)). <br> 


### Compiling a Function Call
Besides function arguments and local variables, there are several information should be stored for each funtion call, namely the value to ```return```, the previous value of the ```fp``` before it is mutated, as well as which code should be executed after the ```return``` (that is, the previous value of ```PC``` before it is mutated). <br>
Since the frame pointer and the stack pointer may be mutated constantly, a way to determine the information is to reserve spaces at the start of compiling the function call. <br>
We could have a dedicated space for the value to ```return```, but since we will only use it after we ```jump``` back from the function call, we could simply store it in the space that stores the previous value of ```PC```, and it will remains at the top of the stack after updates of the ```sp```. <br>
<br>
As a result, when compiling a function application, we reserve two spaces to store  the previous value of ```PC``` and the previous value of ```fp``` respectively, and we increment ```sp``` by 2 (so that it points to the first available space again). Then we include the compiled code to evaluating given arguements, and update the ```fp```. <br>
Then we [```jsr```][...] to the corresponding label while storing the current ```PC``` to the previously reserved space, namely ```(-2 fp)``` (this is how we determine where to ```jump``` back to when we compiling a [```return```](#return) in a function definition). <br>
We then move the produced value to its reserved space, update the ```sp``` relative to the ```fp```, and finally, update the ```fp``` back to the previous value of ```fp```. <br>