This repository contains a VHDL implementation of a custom DLX processor.

Starting from a basic version of the DLX, fully pipelined through five different stages, an improved version has been then realized by adding some features. 
Below are listed the key points and the features of the processor:

- Control unit and Datapath: a Finite State Machine (FSM) Control Unit has been realized, in order to manage and synchronize all the hardware components composing the Datapath. This one includes two memories, for instructions (which cannot be synthesized) and data, and an Arithmetic Logic Unit which is able to perform several kind of operations (including multiplication), and it’s described in a structural way.
- Instruction set: it’s the whole set of instructions that the processor is able to execute. It includes the instructions of the DLX basic, that are:
add, addi, and, andi, beqz, bnez, j, jal, lw, nop, or, ori, sge, sgei, sle, slei, sll, slli, sne, snei, srl, srli, sub, subi, sw, xor, xori.
Then, another set of instructions belonging to the improved version of the DLX has been added, such as: addu, addui, jalr, jr, lb, lbu, lhi, lhu, sb, seq, seqi, sgeu, sgeui, sgt, sgti, sgtu, sgtui, slt, slti, sltu, sltui, subu, subui, mult, multu.
- Hazard unit: the hazard unit is a sub-unit of the control unit, and thus it’s strictly related to it, since all the signals activated by the hazard unit pass through the control unit. It’s able to detect all the dependencies between destination register and source operands of nearby instructions, forwarding the needed data from the stage in which it is produced/loaded to the one in which it will be required.
- Control hazard: a static prediction is performed, stalling for one clock cycle the branch instruction, and moving up the calculation of the new value of the program counter in the decode stage.
