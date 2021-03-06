makefile                                                                                            0000644 0050565 0023420 00000000424 12243766251 012247  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 assembler: assembler.c preprocessor.c preprocessor.h instructionprinter.c instructionprinter.h labelHandler.c labelHandler.h wordHangler.c wordHangler.h staticdata.h
	gcc -std=c99 -o assemble -Wall assembler.c preprocessor.c instructionprinter.c labelHandler.c wordHangler.c

                                                                                                                                                                                                                                            assembler.c                                                                                         0000644 0050565 0023420 00000073041 12243770556 012700  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 //Main class for the assembler. Contains the main method
//#include "staticdata.h"
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdbool.h>
#include "labelHandler.h"
#include "instructionprinter.h"
#include "preprocessor.h"
#include <string.h>
#include "wordHangler.h"
//forward declaration of functions
void decodeInstruction(char* line);
void createSimpleLtype(char* line, int* opCode, bool sw);
int decodeRegister(char* line, int* reg, int prevReg, int prevReg1);
void copyReg(int* source, int* dest);
void createSimpleRtype(char* line, int* funct, int atIndicator);
void createShamtRtype(char* line, int* funct, int srlIndicator);
void dTobConverter(int Imm, int* binary, int length);
int findLtypeImmediate(char* line);
int findShamtSa(char* line, int length, int pos, int zeros);
void createImmRtype(char* line, int* opcode, int startPos, int liIndicator);
void createBranch(char* line, int* opCode, int numberOfRegisters, int atIndicator);
void createJtype(char* line, int* opCode, int size);
void createJr(char* line, int* opCode);
void printTable();
void createLa(char* line, int* opCode);
char* getRegister(char* line, int regNum);
char* getLRegister(char* line);
void createBlteSlt(char* line, int* opCode, int bleIndicator);
void createBlteBne(char* line, int* opCode);
char* getJRegister(char* line, int size);
//all the different opcodes needed stored as int arrays
//NEED BLTZ couldnt found it
//NEED special cases for BLT, BLE
//BLT, slt + bne
//BLE, slt + beq
//structure that holds all opCode/func bits of instructions
static RegistersT registers = {{0, 0, 0, 0, 0}, {0, 0, 0, 1, 0}, {0, 0, 0, 1, 1}, {0, 0, 1, 0, 0}, {0, 0, 1, 0, 1},
{0, 0, 1, 1, 0}, {0, 0, 1, 1, 1}, {0, 1, 0, 0, 0}, {0, 1, 0, 0, 1}, {0, 1, 0, 1, 0},
{0, 1, 0, 1, 1}, {0, 1, 1, 0, 0}, {0, 1, 1, 0, 1}, {0, 1, 1, 1, 0}, {0, 1, 1, 1, 1},
{1, 0, 0, 0, 0}, {1, 0, 0, 0, 1}, {1, 0, 0, 1, 0}, {1, 0, 0, 1, 1}, {1, 0, 1, 0, 0},
{1, 0, 1, 0, 1}, {1, 0, 1, 1, 0}, {1, 0, 1, 1, 1}, {1, 1, 0, 0, 0}, {1, 1, 0, 0, 1},
{1, 1, 1, 0, 0}, {1, 1, 1, 0, 1}, {1, 1, 1, 1, 0}, {1, 1, 1, 1, 1}, {0, 0, 0, 0, 1}};


static opCode opCodes = {
 {1, 0, 0, 0, 1, 1}, {1, 0, 1, 0, 1, 1}, {0, 0, 1, 0, 0, 0}, {0, 0, 1, 0, 0, 0}, {1, 0, 0, 0, 0, 0}, {1, 0, 0, 0, 1, 0}, 
{0, 0, 1, 0, 0, 0}, {0, 0, 1, 0, 0, 1}, {1, 0, 0, 1, 0, 1}, {1, 0, 0, 1, 0, 0}, {0, 0, 1, 1, 0, 1}, {0, 0, 1, 1, 0, 0},
{1, 0, 1, 0, 1, 0}, {0, 0, 1, 0, 1, 0}, {0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 1, 0}, {0, 0, 0, 0, 1, 1}, {0, 0, 0, 0, 0, 0},
{0, 0, 0, 1, 0, 0}, {0, 0, 0, 1, 0, 1}, {0, 0, 0, 1, 1, 0}, {0, 0, 0, 0, 1, 0}, {0, 0, 1, 0, 0, 0}, {0, 0, 0, 0, 1, 1},
{0, 0, 0, 0, 0, 1}};
//file pointers
static FILE *input;
static FILE *output;
static FILE *preprocessed;

//table for label information
static LabelTable labels;

//number of instructions processed
static int currInstruction;

int main( int argc, const char* argv[] )
{
	currInstruction = 0;
	//process input commands
	const char* outputPath;
	const char* inputPath;
	bool list = false;
	if (strcmp("-symbols", argv[1]) == 0)
	{
		list = true;
		inputPath = argv[2];
		outputPath = argv[3];
	}
	else{
		inputPath = argv[1];
		outputPath = argv[2];
	}
	

	//open input stream
	input = fopen(inputPath, "r");
	output = fopen(outputPath, "w");
	
	if (input == NULL || output == NULL){
		printf("Either the input or output file does not exist. Program will now stop");
		return 0;
	}	
	
	//create a new temporary file to be written to
	preprocessed = fopen("preTemp.txt", "ab+");
	
	char pre[100];
	char pre1[100];
	char pre2[100];
	pre[0] = 0;
	pre1[0] = 0;
	pre2[0] = 0;
	//first preprocessor pass remove comments and whitespace
	while(fgets(pre, 100, input) != NULL){
		if (strstr(pre, ".asciiz") == NULL){
		
			preProcess(pre, pre1, preprocessed);
                }
		else if (strstr(pre, ".asciiz") != NULL){
			fprintf(preprocessed, "%s", pre);
		}
	}
        
	//at this point we loop to the .data section process is completely writing the final output
	//to a temporary file once the .text section is completed we will write the contents of this file
	//to the final output and remove it
	rewind(preprocessed);
	char data[100];
        data[0] = 0;
	
	//create a temp file to hold the final representation of .data
	FILE *preData = fopen("preData.txt", "ab+");

	//set file pointer to .data section
	fgets(data, 100, preprocessed);
        while (strstr(data, ".data") == NULL){
		fgets(data, 100, preprocessed);
	}
	
	//in order to keep track of addresses that need to be assigned to labels and array with the same number
        //of elements as the labels is created with each index storing the address as is they all took up one line
        //as we make our initial pass through the .data section writing to the first temp file the addresses are 
        //updated if a label value goes over more then 1 line
        int addressHolder[100];
        for (int i = 0; i < 100; i++){
                addressHolder[i] = 2048 + i;
        }
	
	int labelNumber = 0;
        //loop through until end of the file
        while(fgets(data, 100, preprocessed) != NULL){
                   int lines = 0;
		   //has a .word declaration
                   if (strstr(data, ".word")){
                           lines = processWord(data, preData);
			   
                    }
                    //has a .asciiz declaration
                    else if (strstr(data, ".asciiz")){
                            lines = processASC(data, preData);
                    }
			
		labelNumber = labelNumber + 1;
		//lines will be the number of 32 bit segments it takes to store the value past 1 line, 0 if only 1 line
		//all other address values must be pushed back by that ammount
		for (int i = labelNumber; i < 100; i++){
			addressHolder[i] = addressHolder[i] + lines;
		}
          }

	rewind(preData);
	//all declarations in data section are printed out 1 per line
	//now rewrite them 32bits per line to preData1.txt
	FILE *preData1 = fopen("preData1.txt", "ab+");
	char data1[100];
	char data2[100];
	data2[0] = 0;
	data1[0] = 0;
	

	while(fgets(data1, 100, preData) != NULL){
		//check length of the line
		int strLength = strlen(data1);
		//if the line has a length of 16 the next line can be added on if it
		//is length 16 as well
		if (strLength == 17 || strLength == 9){	
			//need to check next line and see if it is also length 16
			char* next = fgets(data2, 100, preData);
			if (next != NULL){
				int nextLength = strlen(data2);
				//need to update addresses
				if (nextLength == 17 && strLength == 17){
					 data2[16] = '\0';
					 fprintf(preData1, "%s", data2);
					 fprintf(preData1, "%s", data1);
				}
				else if (nextLength == 25 && strLength == 9){
					data2[24] = '\0';
					fprintf(preData1, "%s", data2);
                                        fprintf(preData1, "%s", data1);
				}	
				else
				{
					if (strLength == 17){	
						//next line wont fit, pad with zeros
						for (int i = 0; i < 16; i++){
							fprintf(preData1, "0");
						} 
						fprintf(preData1, "%s", data1);
						fprintf(preData1, "%s", data2);	
					}
					else{
						 for (int i = 0; i < 24; i++){
                                                        fprintf(preData1, "0");
                                                }
                                                fprintf(preData1, "%s", data1);
                                                fprintf(preData1, "%s", data2);
					}
				}
			}
			else{
				//end of file write out the line
				for (int i = 0; i < 16; i++){
                                	fprintf(preData1, "0");
                        	} 
                        		fprintf(preData1, "%s", data1);
			} 
		}
		//write to next temp file
		else{
			fprintf(preData1, "%s", data1);
		}
	}	
	rewind(preData1);
	remove("preData.txt");	

	labels.size = 0;	
	//first preprocessor pass gather label data to be used in next pass
	char labelSearch[100];
	labelSearch[0] = 0;
	int textCounter = 0;
	rewind(preprocessed);
	//make sure file pointer starts at .text
	fgets(labelSearch, 100, preprocessed);
	while(strstr(labelSearch, ".text") == NULL){
		fgets(labelSearch, 100, preprocessed);
	}
	//get labels from .text section	
	fgets(labelSearch, 100, preprocessed);
	while (strstr(labelSearch, ".data") == NULL){
		Label* newLabel = detectLabel(labelSearch, textCounter);
		//if a label is found add it to the label table
		if (newLabel != NULL){
			newLabel->lineNumber = textCounter;
			InsertLabel(&labels, newLabel);
		}
		else{
			textCounter = textCounter + 1;
		}
		fgets(labelSearch, 100, preprocessed);		
	}

	//find labels in the .data section addresses set by addressHolder array
	int counter6 = 0;
	while (fgets(labelSearch, 100, preprocessed) != NULL){
		Label* newLabel = detectLabel(labelSearch, addressHolder[counter6]);
		if (newLabel != NULL){
			newLabel->lineNumber = addressHolder[counter6];
			InsertLabel(&labels, newLabel);
		}
		counter6 = counter6 + 1;
	
	}


	//reset file pointer
	rewind(preprocessed);

	//read in first line of the input file, it is assumed a line will not have more then 100 characters
        char nextLn[100];
	nextLn[0] = 0;
	if (list == false){
		fgets(nextLn, 100, preprocessed);
		//loop through file reading one line at a time until .data section is reached
		while (strstr(nextLn, ".data") == NULL){

			//do not process the line if it is empty
			if (nextLn[0] != '\n' && strstr(nextLn, ":") == NULL)
			{
				//read in line and decode the instruction at the end next ln will hold the instruction
				decodeInstruction(nextLn);
			}
			fgets(nextLn, 100, preprocessed);
		}

		//all instructions have been processed .data section left
		fprintf(output, "\n");
              	char data[100]; 
		data[0] = 0;
		//loop read through preData1 temp file and print to output
		while(fgets(data, 100, preData1) != NULL){	
			fprintf(output, "%s", data);
		}
		//code is translated!
		
	}
	//print out list table for output
	else{
		printTable();
	}

	//finished close input and output files
	remove("preData1.txt");
	remove("preTemp.txt");
	fclose(input);
	fclose(output);
	
	return 0;		
}

//print out a table of all labels
void printTable(){
	printf("in function");
	fprintf(output, "Address      Symbol\n");
	fprintf(output, "-------------------------------\n");
	//print out address in hex and then 
	for (int i = 0; i < labels.size; i++){
	        fprintf(output, "0x%08x", labels.table[i].lineNumber * 4);
		fprintf(output, "   %s\n", labels.table[i].name);
	}

}

//examine first few characters and determine what instruction the line represents. Once the instruction is recognized the opcode
//is found in the table of opcodes and the instruction is created. Pesudo instructions create two strings for broken down 
//command finds opcodes and then translates the instructions 
//@param lineNum is the instructions line number. this is used for calculating address offsets
//@param line instruction being decoded
//@pre assumes that line contains no whitespace, labels, or comments
void decodeInstruction(char* line){
	//get a substring of 4 to avoid any conflicts with labels and instruction names
	char linei[4];
	linei[0] = line[0];
	linei[1] = line[1];
	linei[2] = line[2];	
	linei[3] = line[3];
	//Begin L-type checks
	//lw check
	if (strstr(linei, "lw") != NULL){
		
		createSimpleLtype(line, opCodes.lw, false);
	}
	//sw check
	else if (strstr(linei, "sw") != NULL){
		createSimpleLtype(line, opCodes.sw, true);
	}
	//la check
	else if (strstr(linei, "la") != NULL){
		createLa(line, opCodes.addi);
        }
	//li check
	else if (strstr(linei, "li") != NULL){
		createImmRtype(line, opCodes.addiu, 4, 1);
        }
	//begin R-Type checks
	//add check
	else if (strstr(linei, "addiu") != NULL){
		createImmRtype(line, opCodes.addiu, 11, 0);
        }
	//sub check	
	else if (strstr(linei, "sub") != NULL){
		createSimpleRtype(line, opCodes.sub, 0);
        }
	//addi check
	else if (strstr(linei, "addi") != NULL){
		createImmRtype(line, opCodes.addi, 10, 0);
        }
	//addiu check
	else if (strstr(linei, "add") != NULL){
		createSimpleRtype(line, opCodes.add, 0);
        }
	//or check
	else if (strstr(linei, "ori") != NULL){
		createImmRtype(line, opCodes.ori, 9, 0);
        }
	//and check
	else if (strstr(linei, "andi") != NULL){
		createImmRtype(line, opCodes.andi, 10, 0);
        }
	//ori check
	else if (strstr(linei, "or") != NULL){
		createSimpleRtype(line, opCodes.orin, 0);
        }
	//andi check
	else if (strstr(linei, "and") != NULL){
		createSimpleRtype(line, opCodes.andin,  0);
        }
	//slt check
	else if (strstr(linei, "slti") != NULL){
		createImmRtype(line, opCodes.slti, 10, 0);
        }
	//slti check
	else if (strstr(linei, "slt") != NULL){
		createSimpleRtype(line, opCodes.slt, 0);
        }
	//sll check
	else if (strstr(linei, "sll") != NULL){
		createShamtRtype(line, opCodes.sll, 0);
        }
	//srl check
	else if (strstr(linei, "srl") != NULL){
		createShamtRtype(line, opCodes.srl, 1);
        }
	//sra check
	else if (strstr(linei, "sra") != NULL){
		createShamtRtype(line, opCodes.sra, 0);
        }	
	//nop check
	else if (strstr(linei, "nop") != NULL){
		currInstruction = currInstruction + 1;
		printNop(output);
        }
	//Begin Branch L-type checks
	//beq check
	else if (strstr(linei, "beq") != NULL){
		createBranch(line, opCodes.beq, 2, 0);
        }
	//bne check
	else if (strstr(linei, "bne") != NULL){
		createBranch(line, opCodes.bne, 2, 0);
        }
	//bltz check
	else if (strstr(linei, "bltz") != NULL){
		createBranch(line, opCodes.bltz, 1, 0);
        }
	//blez check
	else if (strstr(linei, "blez") != NULL){
		createBranch(line, opCodes.blez, 1, 0);
        }
	//blt check
	else if (strstr(linei, "blt") != NULL){
		 createBlteSlt(line, opCodes.slt, 0);
		 createBlteBne(line, opCodes.bne);
        }
	//ble check
	else if (strstr(linei, "ble") != NULL){
		createBlteSlt(line, opCodes.slt, 1);
		createBlteBne(line, opCodes.beq);
        }
	//j check
	else if (strstr(linei, "jal") != NULL){
		createJtype(line, opCodes.jal, 3);
        }
	//jr check
	else if (strstr(linei, "jr") != NULL){
		createJr(line, opCodes.jr);
        }
	//jal check
	else if (strstr(linei, "j") != NULL){
		createJtype(line, opCodes.j, 1);
        }
	//syscall check
	else if (strstr(line, "syscall") != NULL){
		currInstruction = currInstruction + 1;
		printsyscall(output);
        }

}

//creates a special version of slt when blt/ble is called
void createBlteSlt(char* line, int* opCode, int bleIndicator){
	currInstruction = currInstruction + 1;
        rType instruc;
	//set opCode
	for (int i = 0; i < 6; i++){
                instruc.funct[i] = opCode[i];
        }
	
	for (int i = 0; i < 5; i++){
		instruc.rd[i] = registers.at[i];
		instruc.shamt[i] = 0;
	}

	//get rs and rt
	char regb[100];
        char regb1[100];
        strcpy(regb, line);
        strcpy(regb1, line);
		
	if (bleIndicator == 1){
		char* reg1 = getRegister(regb, 1);
         	decodeRegister(reg1, instruc.rt, 0, 0);
         	char* reg2 = getRegister(regb1, 2);
         	decodeRegister(reg2, instruc.rs, 0, 0);
	}
	else{
		char* reg1 = getRegister(regb, 1);
                decodeRegister(reg1, instruc.rs, 0, 0);
                char* reg2 = getRegister(regb1, 2);
                decodeRegister(reg2, instruc.rt, 0, 0);	
	}
	printSimpleRtype(&instruc, output);	
}

//create special branch instruciont beq/bne for blt/ble
void createBlteBne(char* line, int* opCode){
	currInstruction = currInstruction + 1;
        lType instruc;
	
	for (int i = 0; i < 6; i++){
                instruc.op[i] = opCode[i];
        }

	for (int i = 0; i < 5; i++){
		instruc.rt[i] = registers.at[i];
		instruc.rs[i] = 0;
	}

	
	//get label offset
	char* label = getRegister(line, 3);
        int labelPos = findLabel(label, &labels);
	int offset = labels.table[labelPos].lineNumber - currInstruction;
	
	for (int i = 16; i >= 0; i--){
                int temp = offset >> i;
                instruc.Imm[i] = temp & 1;
        }

        printSimpleLtype(&instruc, output);
}

//creates a new non psuedo Ltype instruction based on a string and then prints it
//@param line contains registers for one instruction with registers seperated by a comma 
//@param dest holds machine code for Ltype instruction
void createSimpleLtype(char* line, int* opCode, bool sw){
	currInstruction = currInstruction + 1;
	//create a new Ltype
	lType instruc;
	//initialize opCode
	for (int i = 0; i < 6; i++){
                instruc.op[i] = opCode[i];
        }
	
	char regb[100];
        char regb1[100];
        strcpy(regb, line);
        strcpy(regb1, line);
	
        //find rt and rd
        	char* reg1 = getRegister(regb, 1);
		decodeRegister(reg1, instruc.rs, 0, 0);
        	char* reg2 = getLRegister(regb1);
        	decodeRegister(reg2, instruc.rt, 0, 0);

        	//insert 16bit offset
        	//TODO find offset in string and turn into binary format something better then hard coded values for array
        	//for now all 0
		int Immediate = findLtypeImmediate(line);
		int immBinary[16] = {0};        
		dTobConverter(Immediate, immBinary, 16);	
	
		//print instruction
		for (int i = 0; i < 16; i++){
			instruc.Imm[i] = immBinary[i];
		}
		printSimpleLtype(&instruc, output);

}


//find immediate in Ltype instructions will be between ',' and '('
int findLtypeImmediate(char* line){
	//used to store trimmed string
	char Imm[4];
	//find first occurence of ,
	char* comma = strchr(line, ',');
	int commaPos = (int) (comma - line) + 1;

	//find first occurence of (
	char* paren = strchr(line, '(');
	int parenPos = (int)( paren - line);
	int immCount = 0;

	//loop through and copy integer offset over
	for (int i =  commaPos; i < parenPos; i++){
		Imm[immCount] = line[i];
		
		immCount++;
	}

	int immediate = atoi(Imm);

	return immediate;
}

//get the second register of a ltype
char* getLRegister(char* line){
	char* token;
	token = strtok(line, "()");
	token = strtok(NULL, "()");

	return token;
}

//creates a new non psuedo Rtype instruction, with a shamt field of all 0s based on the string entered and prints it
//supported instructions add, sub, or, and, slt
//@indicator if 30 then use at as the first register
void createSimpleRtype(char* line, int* funct, int atIndicator){
	 currInstruction = currInstruction + 1;
	 rType instruc;
	 //initialize funct
	 for (int i = 0; i < 6; i++){
		instruc.funct[i] = funct[i];
	 }
	//create buffers for line
	char regb[100];
	char regb1[100];
	char regb2[100];
	strcpy(regb, line);
	strcpy(regb1, line);
	strcpy(regb2, line);

	char* reg1 = getRegister(regb, 1); 	 
        decodeRegister(reg1, instruc.rd, atIndicator, 0);
	
	char* reg2 = getRegister(regb1, 2);
	decodeRegister(reg2, instruc.rs, 0, 0);

	char* reg3 = getRegister(regb2, 3);
        decodeRegister(reg3, instruc.rt, 0, 0);    

        //shamt field for supported instructions is always 0
        for (int i = 0; i < 5; i++){
		instruc.shamt[i] = 0;
        }
	printSimpleRtype(&instruc, output);
}

//create Rtype instruction that uses shamt field held in line with funct field= funct
//supported instructions sll, srl, sra
void createShamtRtype(char* line, int* funct, int srlIndicator){
	currInstruction = currInstruction + 1;
	rType instruc;
        //initialize funct
    	for (int i = 0; i < 6; i++){
               instruc.funct[i] = funct[i];
        }
	//initialize rs
	if (srlIndicator == 0){
		//if not srl rs all 0s
		for (int i = 0; i < 5; i++){
			instruc.rs[i] = 0;
		}
	}
	else{
		 //TODO it is srl 
		 for (int i = 0; i < 5; i++){
                        instruc.rs[i] = 0;
                }
	}
	//buffers for finding registers
	char regb[100];
        char regb1[100];
        strcpy(regb, line);
        strcpy(regb1, line);

	//find rt and rd
	char* reg1 = getRegister(regb, 1);
        int temp1 = decodeRegister(reg1, instruc.rd, 0, 0);

	char* reg2 = getRegister(regb1, 2);
        int temp2 = decodeRegister(reg2, instruc.rt, 0, 0);

	int zeroInd = 0;
	if (temp1 == 1){
		zeroInd++;
	}	
	if (temp2 ==  1){
		zeroInd++;
	}
	//find the sa
	int sa[5];
	int saInt = findShamtSa(line, 5, 9, zeroInd);

	dTobConverter(saInt, sa, 5);
	for (int i = 0; i < 5; i++){

		instruc.shamt[i] = sa[i];
	}
	printSimpleRtype(&instruc, output);
}

//create an Rtype instructions that uses immediates as parameters
//same as lytype except the position of the immediate
//supported instructions addi, addiu, ori, andi, slti, LI
//li is a special case where rs is $zero, so there is an int idicator set to 1 if it is LI
void createImmRtype(char* line, int* opCode, int startPos, int liIndicator){
	currInstruction = currInstruction + 1;
	lType instruc;
	//copy opcode
	for (int i = 0; i < 6; i++){
                instruc.op[i] = opCode[i];
        }
	//create buffers to back up line	
	char regb[100];
        char regb1[100];
        strcpy(regb, line);
        strcpy(regb1, line);

	//get rt
	char* reg1 = getRegister(regb, 1);
        int temp = decodeRegister(reg1, instruc.rt, 0, 0);
	
	int zeroInd = 0;
	if (temp == 1){
		zeroInd++;
	}
	
	//find rs		
	if (liIndicator != 1){
		//find rs
		char* reg2 = getRegister(regb1, 2);
	        int temp2 = decodeRegister(reg2, instruc.rs, 0, 0);
		if (temp2 == 1){
			zeroInd++;
		}
		

	}
	//if instruc is li then rs is all zeros
	else{
		for (int i = 0; i < 5; i++){
			instruc.rs[i] = 0;
		}
	}
	
	int Immediate = findShamtSa(line, 16, startPos, zeroInd);
        int immBinary[16] = {0};
        dTobConverter(Immediate, immBinary, 16);

        for (int i = 0; i < 16; i++){
                instruc.Imm[i] = immBinary[i];
        }
	printImmRtype(&instruc, output);

}

//finds sa for instructions that use shamt field can also be used to find rtype immediates
//@param 16, or 5
//starting position of the immediate
//@return integer representation of sa
//@param zeros tells the number of zero registers used
int findShamtSa(char* line, int size, int pos, int zeros ){
	char sa[size];
	//sa will be after third ',' in line
	//get array index of start of sa, always 11
	//counter for sa
	int saCount = 0;
	
	
	for(int i = pos + 2 + (zeros * 2); i < strlen(line); i++){
		sa[saCount] = line[i];
		printf("%c", line[i]);
		saCount++;
	}
	int saInt = atoi(sa);
	return saInt;
}

//create a branch type instruction based on line
//@param line current line in input
//@param opCode of instruction
//@param numberOfregisters the instruction takes as an input
//supported instructions: beq, bne, bltz, blez
void createBranch(char* line, int* opCode, int numberOfregisters, int atIndicator){
	currInstruction = currInstruction + 1;
	lType instruc;
	//copy opcode
	for (int i = 0; i < 6; i++){
                instruc.op[i] = opCode[i];
        }
		
	char regb[100];
        char regb1[100];
        strcpy(regb, line);
        strcpy(regb1, line);
	
	//decode registers
	char* reg1 = getRegister(regb, 1);
        decodeRegister(reg1, instruc.rt, 0, 0);
        
	if (numberOfregisters == 2){
		 char* reg2 = getRegister(regb1, 2);
        	 decodeRegister(reg2, instruc.rs, 0, 0);
	}
	else{
		for (int i = 0; i < 5; i++){
			instruc.rs[i] = 0;
		}
	}
	
	//find label
	char* label;
	if (numberOfregisters == 2){
		label = getRegister(line, 3);
	}
	else{
		label = getRegister(line, 2);
	}
	int labelPos = findLabel(label, &labels);
	//calculate address offset
	int offset = labels.table[labelPos].lineNumber - currInstruction;		
	
	//set Imm based on label
	for (int i = 16; i >= 0; i--){
		int temp = offset >> i;
		instruc.Imm[i] = temp & 1;
	}

	printSimpleLtype(&instruc, output);
}

//create new jtype instruction based on line
//@param line holds current instruction
//@param opCode for jtype
//supported instructions: j, jal
void createJtype(char* line, int* opCode, int size){
	currInstruction = currInstruction + 1;
	jType instruc;
	
	//set opCode
	for (int i = 0; i < 6; i++){
                instruc.op[i] = opCode[i];
        }
	//find label
	char* label = getJRegister(line, size);
	int labelPos = findLabel(label, &labels);
	
	for (int i = 0; i < 16; i++){
	
                instruc.Imm[i] = labels.table[labelPos].address[i];
        }
	//set the last bits to 0
	for (int i = 16; i < 26; i++){
		instruc.Imm[i] = 0;
	}
	printSimpleJtype(&instruc, output);
}

//get label assiciate with jump instruction
char* getJRegister(char* line, int size){
	char* label = malloc(sizeof(char) * (strlen(line) - size));
	int counter = 0;
        for (int i = size; i < strlen(line); i++){
		label[counter] = line[i];
		counter++;
	}
        return label;
}


//print out jr special case different from the rest of the registers
void createJr(char* line, int* opCode){
	currInstruction = currInstruction + 1;
	rType instruc;
	//set opcode, rs, rt
	for (int i = 0; i < 5; i++){
		instruc.rt[i] = 0;
		instruc.rd[i] = 0;
		instruc.funct[i] = opCode[i];
        }
	instruc.funct[5] = opCode[5];
	for (int i = 0; i < 5; i++){
		instruc.shamt[i] = 0;
	}
	//find register
	decodeRegister(line, instruc.rs, 0, 0);
	printSimpleRtype(&instruc, output);
	
}

//create a la instruction
void createLa(char* line, int* opCode){
	currInstruction = currInstruction + 1;
	lType instruc;
	
	for (int i = 0; i < 6; i++){
		instruc.op[i] = opCode[i];
	}
	
	decodeRegister(line, instruc.rs, 0,  0);
	for (int i = 0; i < 5; i++){
		instruc.rt[i] = 0;
	}
        	
	//create a substring that contains the label
	char* label = getRegister(line, 2);

	int labelPos = findLabel(label, &labels);
	for (int i = 0; i < 16; i++){
                instruc.Imm[i] = labels.table[labelPos].address[i];
        }

        printSimpleLtype(&instruc, output);

}

//add$s2,$s0,$s1
//get specified register from the line and retrun it
char* getRegister(char* line, int regNum){
	char* token;
	token = strtok(line, ",$");
	for (int i = 0; i < regNum; i++){
		token = strtok(NULL, ",$");
	}
	return token;
}

//@param line current line being decoded
//@param reg empty array to be initialized as register code in binary
//@return register that was found to signify first register in instruction 0-31
int decodeRegister(char* line, int* reg, int prevReg, int prevReg1){
	if (prevReg == 30){
                copyReg(registers.at, reg);
        }
	else if (strstr(line, "zero") && prevReg != 1 && prevReg1 != 1){
	      copyReg(registers.zero, reg);
	      return 1;
	}
	else if (strstr(line, "v0") && prevReg != 2 && prevReg1 != 2){
	      copyReg(registers.v0, reg);
	      return 2;
	}
	else if (strstr(line, "v1") && prevReg != 3 && prevReg1 != 3){
	      copyReg(registers.v1, reg);
	      return 3;
	}
	else if (strstr(line, "a0") && prevReg != 4 && prevReg1 != 4){
	      copyReg(registers.a0, reg);
	      return 4;
	}
	else if (strstr(line, "a1") && prevReg != 5 && prevReg1 != 5){
	      copyReg(registers.a1, reg);
	      return 5;
	}
	else if (strstr(line, "a2") && prevReg != 6 && prevReg1 != 6){
	      copyReg(registers.a2, reg);
	      return 6;
	}
	else if (strstr(line, "a3") && prevReg != 7 && prevReg1 != 7){
	      copyReg(registers.a3, reg);
	      return 7;
	}
	else if (strstr(line, "t0") && prevReg != 8 && prevReg1 != 8){
	      copyReg(registers.t0, reg);
	      return 8;
	}
	else if (strstr(line, "t1") && prevReg != 9 && prevReg1 != 9){
	      copyReg(registers.t1, reg);
	      return 9;
	}
	else if (strstr(line, "t2") && prevReg != 10 && prevReg1 != 10){
	      copyReg(registers.t2, reg);
	      return 10;
	}
	else if (strstr(line, "t3") && prevReg != 11 && prevReg1 != 11){
	      copyReg(registers.t3, reg);
	      return 11;
	}
	else if (strstr(line, "t4") && prevReg != 12 && prevReg1 != 12){
	      copyReg(registers.t4, reg);
	      return 12;
	}
	else if (strstr(line, "t5") && prevReg != 13 && prevReg1 != 13){
	      copyReg(registers.t5, reg);
	      return 13;
	}
	else if (strstr(line, "t6") && prevReg != 14 && prevReg1 != 14){
	      copyReg(registers.t6, reg);
	      return 14;
	}
	else if (strstr(line, "t7") && prevReg != 15 && prevReg1 != 15){
	      copyReg(registers.t7, reg);
	      return 15;
	}
	else if (strstr(line, "s0") && prevReg != 16 && prevReg1 != 16){
	      copyReg(registers.s0, reg);
	      return 16;
	}
	else if (strstr(line, "s1") && prevReg != 17 && prevReg1 != 17){
	      copyReg(registers.s1, reg);
	      return 17;
	}
	else if (strstr(line, "s2") && prevReg != 18 && prevReg1 != 18){
	      copyReg(registers.s2, reg);
	      return 18;
	}
	else if (strstr(line, "s3") && prevReg != 19 && prevReg1 != 19){
	      copyReg(registers.s3, reg);
	      return 19;
	}
	else if (strstr(line, "s4") && prevReg != 20 && prevReg1 != 20){
	      copyReg(registers.s4, reg);
	      return 20;
	}
	else if (strstr(line, "s5") && prevReg != 21 && prevReg1 != 21){
	      copyReg(registers.s5, reg);
	      return 21;
	}
	else if (strstr(line, "s6") && prevReg != 22 && prevReg1 != 22){
	      copyReg(registers.s6, reg);
	      return 22;
	}
	else if (strstr(line, "s7") && prevReg != 23 && prevReg1 != 23){
	      copyReg(registers.s7, reg);
	      return 23;
	}
	else if (strstr(line, "t8") && prevReg != 24 && prevReg1 != 24){
	      copyReg(registers.t8, reg);
	      return 24;
	}
	else if (strstr(line, "t9") && prevReg != 25 && prevReg1 != 25){
	      copyReg(registers.t9, reg);
	      return 25;
	}
	else if (strstr(line, "gp") && prevReg != 26 && prevReg1 != 26){
	      copyReg(registers.gp, reg);
	      return 26;
	}
	else if (strstr(line, "sp") && prevReg != 27 && prevReg1 != 27){
	      copyReg(registers.sp, reg);
	      return 27;
	}
	else if (strstr(line, "fp") && prevReg != 28 && prevReg1 != 28){
	      copyReg(registers.fp, reg);
	      return 28;
	}
	else if (strstr(line, "ra") && prevReg != 29 && prevReg1 != 29){
	      copyReg(registers.ra, reg);
	      return 29;
	}
	else if (strstr(line, "at") ){
		copyReg(registers.at, reg);
	}
	return 0;
}


// copy one register array to anothe array
void copyReg(int* source, int* dest){
	for(int i = 0; i < 5; i++){
	      dest[i] = source[i];
	}
}

//converts a integer to binary in the form of an integer array
//@param Imm integer to be converted
//@param binary array binary representation will be stored in
//@param length of binary array
void dTobConverter(int Imm, int* binary, int length){
	int temp;
	for (int i = 31; i >= 0; i--){
		temp = Imm >> i;
		if (i < length){
			if (temp & 1){
				binary[i] = 1;
			}
			else{
				binary[i] = 0;
			}
		}
	}
}


                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               instructionprinter.c                                                                                0000644 0050565 0023420 00000005615 12243761052 014701  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 #include <stdio.h>
#include "instructionprinter.h"
//#include "staticdata.h"
//print out an ltype record based on instru
void printSimpleLtype(lType* instruc, FILE *output){
	//print opCode
	for (int i = 0; i < 6; i++){
		fprintf(output,"%d", instruc->op[i]);
	}
	//print out rs
	for (int i = 0; i < 5; i++){
                fprintf(output,"%d", instruc->rt[i]);
        }
	//print out rt
	for (int i = 0; i < 5; i++){
                fprintf(output,"%d", instruc->rs[i]);
        }
	//print out 16 bit Immediate
	for (int i = 15; i >= 0; i--){
                fprintf(output,"%d", instruc->Imm[i]);
        }
	//end the line
	fprintf(output, "\n");
}

void printImmRtype(lType* instruc, FILE *output){
	for (int i = 0; i < 6; i++){
                fprintf(output,"%d", instruc->op[i]);
        }
	//rs
	for (int i = 0; i < 5; i++){
                fprintf(output,"%d", instruc->rs[i]);
        }
	//rt
	 for (int i = 0; i < 5; i++){
                fprintf(output,"%d", instruc->rt[i]);
        }
	//16 bit
	for (int i = 15; i >= 0; i--){
                fprintf(output,"%d", instruc->Imm[i]);
        }
	fprintf(output, "\n");
}

//print out an rtype record based on instruc
void printSimpleRtype(rType* instruc, FILE *output){
	//print opCode
	for (int i = 0; i < 6; i++){
		fprintf(output, "0");
	}
	//print out rs
	for (int i = 0; i < 5; i++){
		fprintf(output,"%d", instruc->rs[i]);
	}
	//print out rt
	for (int i = 0; i < 5; i++){
		fprintf(output,"%d", instruc->rt[i]);
	}
	//print out rd bit Immediate
	for (int i = 0; i < 5; i++){
		fprintf(output,"%d", instruc->rd[i]);
	}
	//print out shamt
	for (int i = 4; i >= 0; i--){
		fprintf(output,"%d", instruc->shamt[i]);
	}
	//print out funct
	for (int i = 0; i < 6; i++){
		fprintf(output,"%d", instruc->funct[i]);
	}
	fprintf(output,"\n");
}

//TODO make sure IMM prints out in right order
//print out a jtype record based on instruc
void printSimpleJtype(jType* instruc, FILE *output){
	//print opCode
	for (int i = 0; i < 6; i++){
		fprintf(output, "%d", instruc->op[i]);
	}
	//print out Imm
	for (int i = 25; i >=0; i--){
		fprintf(output,"%d", instruc->Imm[i]);
	}
	fprintf(output, "\n");
}

//print out a nop, 32 zeros
void printNop(FILE *output){
	for (int i = 0; i < 32; i++){
		fprintf(output, "0");
	}
	fprintf(output, "\n");
}

//print out syscall
void printsyscall(FILE *output){
	for (int i = 0; i < 28; i++){
		fprintf(output, "0");
	}
	fprintf(output, "1");
	fprintf(output, "1");
	fprintf(output, "0");
	fprintf(output, "0 \n");
}

void printSw(lType* instruc, FILE *output){
	 for (int i = 0; i < 6; i++){
                fprintf(output,"%d", instruc->op[i]);
        }
	for (int i = 0; i < 5; i++){
                fprintf(output,"%d", instruc->rs[i]);
        }
	for (int i = 0; i < 5; i++){
                fprintf(output,"%d", instruc->rt[i]);
        }
	for (int i = 15; i >= 0; i--){
                fprintf(output,"%d", instruc->Imm[i]);
        }
	fprintf(output, "\n");	

}
                                                                                                                   instructionprinter.h                                                                                0000644 0050565 0023420 00000000676 12243442153 014706  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 #include "staticdata.h"
#ifndef INSTRUCTIONPRINTER_H
#define INSTRUCTIONPRINTER_H
//header file for insructionprinter
void printSimpleLtype(lType* instruc, FILE *output);

void printImmRtype(lType* instruc, FILE *output);

void printSimpleRtype(rType* instruc, FILE *output);

void printSimpleJtype(jType* instruc, FILE *output);

void printNop(FILE *output);

void printsyscall(FILE *output);

void printSw(lType* instruc, FILE *output);
#endif
                                                                  labelHandler.c                                                                                      0000644 0050565 0023420 00000001347 12243737440 013273  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 #include "labelHandler.h"
#include <string.h>
#include<stdio.h>

//insert a label into table
//@param tableof labels
//@param name of label
//@param address of label
void InsertLabel(LabelTable *table, Label* label){
	int size = table->size;
	if (size != 20){
		table->table[size] = *label;
		table->size++;
	}		
}

//search for a label, based on name
//if found return position, if nothing is found return -1
int findLabel(char* line, LabelTable* table){
	int lineLen = strlen(line);
	for (int i = 0; i < table->size;  i++){
		//check to see if line contains name
		printf("Search %sn", line);
		printf("   Name: %sn\n", table->table[i].name); 
		if (strncmp(line, table->table[i].name, lineLen - 1) == 0){
			return i;
		}
	}
	return -1;
}

                                                                                                                                                                                                                                                                                         labelHandler.h                                                                                      0000644 0050565 0023420 00000001143 12243674706 013277  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 //structure and functions for keeping track of labels and their addresses 
#ifndef LABELHANDLER_H
#define LABELHANDLER_H

//strucure that represents a label
typedef struct label{
	//name of label, used as search key
	char* name[32];
	char* hexAddress[10];
	//binary representation
	int* address[16];
	//so it is possible to tell is it is ahead or behind a instruction
	int lineNumber;
} Label;

//structure that keeps track of labels
typedef struct labelTable{
	Label table[20];
	int size;
} LabelTable;

void InsertLabel(LabelTable *table, Label *label);

int findLabel(char* line, LabelTable *table);
#endif

                                                                                                                                                                                                                                                                                                                                                                                                                             preprocessor.c                                                                                      0000644 0050565 0023420 00000003533 12243675112 013440  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 #include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "preprocessor.h"
//PreProcessor functions gets rid of comments and labels
//@param line from the input file
//@return 1 if a comment is found a removed
//@return 2 if no comment was found
void preProcess(char* line, char* dest, FILE* output){
	dest[0] = 0;
	int commentInd = 0;
	//check to see if line contains comments
	char* comment = strchr(line, '#');
	if (comment != NULL){
		//a comment is found, get position of beginning
		int index = (int)(comment - line);
		//delete everything after comment
		strncat(dest, line, index);
		commentInd = 1;
		
	}
	//string has no comment 
	else
	{
		strcpy(dest, line);
		
	
	}	
	
	//dont proceed if the line is empty
	if (dest[0] != '\n'){
		//remove whitespace
		char* token = strtok(dest, " \t");
		while (token != NULL){
			fprintf(output, "%s", token);
			token = strtok(NULL, " \t");
		}
		if (commentInd == 1){
			fprintf(output, "\n");
		}
	}
}

//examine line and determine if it is a label
//if it is a label return a new label
//@param instructionNumber # of instruction in section
Label* detectLabel(char* line, int instructionNumber){
	//check to see if the line is a label
	if(strrchr(line, ':') != NULL){
		//create a new label to be added to the list
		Label *newLabel = malloc(sizeof(Label));
		printf("Hex Address: %p  ", instructionNumber * 4);
		int addressInt = (instructionNumber * 4);
		newLabel->lineNumber = instructionNumber;		
		//add address info
		printf("Address: ");
		for (int i = 16; i >= 0; i--){
			int temp = addressInt >> i;
			newLabel->address[i] = (temp) & 1;
			printf("%d", newLabel->address[i]);
			
		}
		printf("   ");
		//assign name without :
		char* colon = strchr(line, ':');
		int colonPos = colon - line;
		strncpy(newLabel->name, line, colonPos);
		printf("%s\n", newLabel->name);
		return newLabel;
	}
	return NULL;	
}
                                                                                                                                                                     preprocessor.h                                                                                      0000644 0050565 0023420 00000000420 12243220216 013424  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 #include "labelHandler.h"
#ifndef PREPROCCESSOR_H
#define PREPROCCESSOR_H
//header file for preproccessor
void preProcess(char* line, char* dest, FILE* output);

void removeWhiteSpace(char* line, char* dest);

Label* detectLabel(char* line, int instructionNumber);
#endif
                                                                                                                                                                                                                                                staticdata.h                                                                                        0000644 0050565 0023420 00000002523 12242507561 013037  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 //header file that holds declarations of all static data like table of opcodes, structures for different instruction types

//table to hold all register numbers
typedef struct registertable {
int zero[5];
int v0[5];
int v1[5];
int a0[5];
int a1[5];
int a2[5];
int a3[5];
int t0[5];
int t1[5];
int t2[5];
int t3[5];
int t4[5];
int t5[5];
int t6[5];
int t7[5];
int s0[5];
int s1[5];
int s2[5];
int s3[5];
int s4[5];
int s5[5];
int s6[5];
int s7[5];
int t8[5];
int t9[5];
int gp[5];
int sp[5];
int fp[5];
int ra[5];
int at[5];
} RegistersT;

//table of all supported opcode/funct bits
typedef struct opCode {
int lw[6];
int sw[6];
int la[6];
int li[6];
int add[6];
int sub[6];
int addi[6];
int addiu[6];
int orin[6];
int andin[6];
int ori[6];
int andi[6];
int slt[6];
int slti[6];
int sll[6];
int srl[6];
int sra[6];
int nop[6];
int beq[6];
int bne[6];
int blez[6];
int j[6];
int jr[6];
int jal[6];
int bltz[6];
} opCode;

//struc to represent rtype instructions
typedef struct rType{
        int rs[5];
        int rt[5];
        int rd[5];
        int shamt[5];
        int funct[6];
} rType;

//struc to represent ltype instructions        
typedef struct lType{
        int op[6];
        int rs[5];
        int rt[5];
        int Imm[16];
} lType;

//struc to represent jtype instructions        
typedef struct jType{
        int op[6];
	int Imm[26];
} jType;
                                                                                                                                                                             wordHangler.c                                                                                       0000644 0050565 0023420 00000015501 12243730054 013161  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 #include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "wordHangler.h"

//driver function, reads in all lines and converts them to binary form stored in char* arrays
//it then stores them in a 2d array and writes them to a output 32 bits per line

//determine what type of .word declaration line contains
int processWord(char* line, FILE *output){
	//if there are commas then initializ array
	if (strstr(line, ",") != NULL){
		printf("Initialize Array\n");
		int ret = createArrayInit(line, output);
		return ret;	
	}
	//if there are 2 colons init all
	else if (colonCount(line) == 2){
		printf("Array\n");
		int ret = createArrayInitAll(line, output);
		return ret;
	}
	//otherwise it is a variable
	else{
		printf("Var\n");
		createVar(line, output);
		return 0;
	}	
	
}

//create an array with elements a, b, c, d, e, ....
int createArrayInit(char* line, FILE *output){
	//before we can split the string into tokens we must copy all values after the colon into a new string
	char afterColon[100];
	//get colon position
	char *colon = strchr(line, ':');
        int colonPos = (int)(colon - line);
	int counter = 0;
	//copy string
	for (int i = colonPos; i < strlen(line); i++){
		afterColon[counter] = line[i];
		counter++;
	}

	int elementCount = 0;
	//declare a pointer to be used by strtok
	char* token;
	token = strtok(afterColon, ",abcdefghijklmnopqrstuvwxyz.:");
	//get all tokens
	while (token != NULL){
		int element = atoi(token);
		dTobPrinter(element, output);
		token = strtok(NULL, ",abcdefghijklmnopqrstuvwxyz.:");
		elementCount = elementCount + 1;
	}
	return elementCount;
}

//create an array of size n, with m characters m:n
int createArrayInitAll(char* line, FILE *output){
	//find colon position 
	char *colon = strchr(line, ':');
	colon = strchr(colon + 1, ':');
	int colonPos = (int)(colon - line);
	
	//character array holding size of new array
	int strLength = strlen(line);
	char size[strLength - colonPos + 1];
	int counter1 = 0;
	for (int i = colonPos + 1; i < strLength; i++){
		size[counter1] = line[i];
		counter1 = counter1 + 1;
	}
	int decSize = atoi(size);
	
	//character array holding value of array elements
	//find position of .
	char* period = strchr(line, '.');
	int periodPos = (int)(period - line);

	char element[colonPos - (periodPos + 5)];
	int counter2 = 0;
	for(int i = periodPos + 5; i < colonPos; i++){
		element[counter2] = line[i];
		counter2 = counter2 + 1;
	}
	int elementValue = atoi(element);

	//print out size lines with value of element
	for (int i = 0; i < decSize; i++){
		dTobPrinter(elementValue, output);
	}
	return decSize - 1;
}

//create a variable from .data section
//variable always occurs 5 positions after the .
void createVar(char* line, FILE *output){
	//find position of period 
	char* period = strchr(line, '.');
        int periodPos = (int)(period - line);

	int strLength = strlen(line);
        char var[strLength - (periodPos + 5)];
        int counter = 0;
	for (int i = periodPos + 5; i < strLength; i++)
	{
		var[counter] = line[i];
		counter = counter + 1;
	}
	//convert to a decimal
	int varInt = atoi(var);
	dTobPrinter(varInt, output);
}	

//grabs the ascii string between two quotes and prints them
int processASC(char* line, FILE *output){
	int lineCount = 0;
	//get just the string to be printed
	char* token;
        token = strtok(line, "\"");
	token = strtok(NULL, "\"");
	
	
	//print out the ascii string in big endian order
	//read fours byte at a time and print backwards
	int strLength = strlen(token);
	printf("%s %d\n", token, strLength);
	//if string is less the 4 then it can be printed by simple cases
	if (strLength >= 4){
		lineCount = -1;
		//remainder is the amount of letters left over that need to be printed in last 4 byte chunk
		int remainder = strLength % 4;
		for (int i = 0; i < strLength - remainder; i = i + 4){
			printBinaryChar(token[i + 3], output);
			printBinaryChar(token[i + 2], output);
			printBinaryChar(token[i + 1], output);
			printBinaryChar(token[i], output);
			fprintf(output, "\n");
			lineCount = lineCount + 1;
		}
		lineCount = lineCount + 1;
		//now number of characters left = remainder + 1 0 byte
		int currPos = strLength - remainder;
		//no remainder need 32 0s
		if (remainder == 0){
			for (int i = 0; i < 8; i++){
				fprintf(output, "0");
			}
			fprintf(output, "\n");

		}
		//could possibly fit more on this line?
		else if (remainder == 1){
			for (int i = 0; i < 8; i++){
                        	fprintf(output, "0");
                	}
			printBinaryChar(token[currPos], output);
                	fprintf(output, "\n");
		}
		else if (remainder == 2){
               		for (int i = 0; i < 16; i++){
                        	fprintf(output, "0");
                	}
			printBinaryChar(token[currPos + 1], output);
                        printBinaryChar(token[currPos], output);
                	fprintf(output, "\n");
        	}
		else{
                        for (int i = 0; i < 8; i++){
                	        fprintf(output, "0");
                	}
			printBinaryChar(token[currPos + 2], output);
                        printBinaryChar(token[currPos + 1], output);
                        printBinaryChar(token[currPos], output);
                	fprintf(output, "\n");
        	}
		return lineCount;
	}
	//only print out 2 bytes because it is possible to fit another word on this line if it will fit
	else if (strLength == 1){
                for (int i = 0; i < 8; i++){
                        fprintf(output, "0");
                }
		printBinaryChar(token[0], output);
                fprintf(output, "\n");
		return 0;
        }
	else if (strLength == 2){
		for (int i = 0; i < 16; i++){
                        fprintf(output, "0");
                }
		printBinaryChar(token[1], output);
                printBinaryChar(token[0], output);
                fprintf(output, "\n");
		return 0;
        }
	else if (strLength == 3){
                for (int i = 0; i < 8; i++){
                        fprintf(output, "0");
                }
		printBinaryChar(token[2], output);
                printBinaryChar(token[1], output);
                printBinaryChar(token[0], output);

                fprintf(output, "\n");
		return 0;
        }


	return lineCount;
}

//converts c to binary
void printBinaryChar(char c, FILE *output){
	for (int i = 7; i >= 0; --i) {
		int bin = ((c  >> i) & 1);
    		fprintf(output, "%d", bin);
	}
}

//count the number of colons in a line
int colonCount(char* line){
	int length = strlen(line);
	int count = 0;
	for (int i = 0; i < length; i++){
		if (line[i] == ':'){
			count = count + 1;
		}
	}
	return count;
}


void dTobPrinter(int Imm, FILE* output){
        int temp;
        for (int i = 31; i >= 0; i--){
                temp = Imm >> i;
                if (temp & 1){
                       fprintf(output, "1");
                }
                else{
                       fprintf(output, "0");
                }
        }
	fprintf(output, "\n");
}


                                                                                                                                                                                               wordHangler.h                                                                                       0000644 0050565 0023420 00000000622 12243725726 013176  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 #include <stdbool.h>
//handles all .word declarations
int processWord(char* line, FILE *output);

int processASC(char* line, FILE *output);
 
void createVar(char* line, FILE *output);

int createArrayInit(char* line, FILE *output);

int createArrayInitAll(char* line, FILE *output);

void printBinaryChar(char c, FILE *output);

int colonCount(char* line);

void dTobPrinter(int Imm, FILE* output);



                                                                                                              readme.txt                                                                                          0000644 0050565 0023420 00000000166 12243766566 012561  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 All appears to work perfectly, except when calculating address offsets. Sometimes the affters are off by a bit or too
                                                                                                                                                                                                                                                                                                                                                                                                          pledge.txt                                                                                          0000644 0050565 0023420 00000001276 12243767651 012563  0                                                                                                    ustar   dmoore09                        Majors                                                                                                                                                                                                                 // On my honor:
//
// - I have not discussed the C++ language code in my program with
// anyone other than my instructor or the teaching assistants
// assigned to this course.
//
// - I have not used C++ language code obtained from another student,
// or any other unauthorized source, either modified or unmodified.
//
// - If any C++ language code or documentation used in my program
// was obtained from another source, such as a text book or course
// notes, that has been clearly noted with a proper citation in
// the comments of my program.
//
// - I have not designed this program in such a wayas to defeat or
// interfere with the normal operation of the Curator System.
//
// <Daniel Moore> 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  