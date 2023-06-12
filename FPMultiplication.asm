################################
# By : Muath Alsubhi 
# description: this program eliminate the need of a FPU for multiplication purposes.
# Inputs: two floating point numbers
# output: the multiplication of the two numbers
################################

.data
prompt1: .asciiz "\nEnter 1st float: "
prompt2: .asciiz "Enter 2nd float: "
resultF: .asciiz "Result of fmul: "
resultM: .asciiz "\nResult of mul.s: "
repeat: .asciiz "\nRepeat (Y/N)? "
buffer: .space 100
.text
main:
#------------------------------ ASK FOR INPUT
li $v0 , 4 # prompt msg
la $a0, prompt1
syscall
li $v0, 6 # prompt input
syscall
mov.s $f1, $f0
mfc1 $a1, $f0 # first number
li $v0 , 4 #prompt msg
la $a0, prompt2
syscall
li $v0, 6 # prompt input
syscall
mfc1 $a0, $f0 # 2nd number
mul.s $f8 ,$f0, $f1
jal fmul
## PRINT RESULT OF FMUL
li $v0, 4
la $a0, resultF
syscall
li $v0, 2
syscall
mov.s $f12, $f8
li $v0, 4
la $a0 resultM
syscall
li $v0, 2
syscall
KEEPASKING:
li $v0, 4
la $a0, repeat
syscall
li $v0, 8
la $a0, buffer
la $a1, 2
syscall
la $t0, buffer
lb $t1, 0($t0)
beq $t1, 'Y', main
beq $t1, 'N', exitProgram
j KEEPASKING
#j exitProgram


fmul: 
## STORE IT IN STACK
subiu $sp $sp 12
sw $ra, 0($sp) 
sw $a0, 4($sp)
sw $a1, 8($sp) 
## 1- determine the sign , 1 xor 2
move $t0, $a1 # 1st num  # copy 
move $t1, $a0 # 2nd num #copy
# we will
andi $t2, $a1, 0x80000000 # $t2 will be the sign bit of 1st num
andi $t3, $a0, 0x80000000 # $t3 is sign bit for the 2nd num
xor $t2, $t3, $t2 # $t2 now holds our result sign,
## GET EXPONENT  c
andi $t3, $a0, 0x7F800000 # first exponent
andi $t4, $a1, 0x7F800000 # second exponent 
# CHECKING FOR INFINITE AND AVOIDING OVERFLOW
bgeu $t3, 0x7F800000, INFINITE1
bgeu $t4, 0x7F800000, INFINITE2
# HANDLING UNDERFLOW
bnez $t3, continue
bnez $t4, continue 
# means both is close to zero, #undeflowing# hence we must output 0
mtc1 $t2, $f12
j exitfmul
continue:
# now we need to shift the bias and add
li $t5, 0x3F800000 # shifted bias
#li $t5, 127
#sll $t5, $t5, 23
addu $t3, $t4, $t3, # sum $t3, and $t4 exponents
subu $t5, $t3, $t5 # this is now our new Exponent value which we will shift 23 bits
# now we need to check the most significand bit if it is 1 or not, that indicates overflow
bgeu $t5, 0x80000000, OV
j NORM

OV:
# nothing really needed to be done but process it as infinite!
# we can expect the number to have an exponent value of EV = exponent1 + exponent2 - bias
INFINITE:
INFINITE1:
li $t5 0x7F800000 # 0111 1111 1 , 7 F, 1
# we need to check if second number is zero then NaN
beqz $t4, NAN1
# other wise it is infinite times some number... so we combine that with the sign and send it back
inf:
li $t5 0x7F800000 # 0111 1111 1 , 7 F, 1
beqz $t3, NAN1
or $s6, $t5, $t2
mtc1 $s6, $f12
j exitfmul
NAN1:
or $s6, $t2, $t5
ori $s6, $s6, 0x00000001 # force NaN 
mtc1 $s6, $f12
j exitfmul
INFINITE2: # with a similar procedure
#beqz $t3, NAN1 # infinite time 0 is NaN
j inf



# FINALLY get signicand and normalize
# normalize....
NORM:
li $t3, 0x00800000
li $t4, 0x00800000
# get significand... 
andi $t7, $a0, 0x007FFFFF
andi $t8, $a1, 0x007FFFFF
or $t4, $t4, $t8
or $t3, $t3, $t7

# now multipliy
multu $t3, $t4
# we have high and low now.
mfhi $t3
mflo $t4
blt $t3, 0x00008000, METHOD1 # check the 16th bit...
# ---- METHOD 2
andi $t3, $t3, 0x7FFF # here we ignored first bit... hence we have 15 bits
sll $t3, $t3, 8# our first 8 bits is empty
srl $t4, $t4, 24 # 8 remain
or $t3, $t3, $t4 # significand...
#addiu $t3, $t3, 1 # increment significand
addiu $t5, $t5, 0x800000 # increment exponent
li $s0, 8
j ROUNDING
METHOD1:

andi $t3, $t3, 0x3FFF # here we ignored first two bits... hence we have 14 bits
sll $t3, $t3, 9# our first 9 bits is empty
srl $t4, $t4, 23 # 9 remain
or $t3, $t3, $t4 # significand...
li $s0, 9
ROUNDING:
mflo $t4
sllv $t7, $t4, $s0
sgeu $s1, $t7, 0x80000000 # ROUNDING
#sgeu $s1, $t7, 0x10000000 # rounding bit is 1, in $s1
andi $t8, $t7, 0x7FFFFFFF
sgtu $s2, $t8, $zero # sticky bit value in $s2 # this should be valid
# we have 4 cases....
beqz $s1, combine # no rouding, truncate
beqz $s2, nearest # if RS=10, TIE
# if 11, increment..
addiu $t3, $t3, 1 
j combine
nearest: # here we round to the nearest even
# check last bit in our significand
sll $s3, $t3, 31 #
sgeu $s3, $s3, 0x10000000 
beqz $s3, combine
# otherwise increment
addiu $t3, $t3, 1 # increment significand

combine:
#or $t4, $t3, $t4 #our significand
or $t3, $t3, $t5 # our exponent
or $t3, $t3, $t2 # our sign
mtc1 $t3, $f12 # output?
#cvt.d.w $f12, $f12

# self notes
# now this is our new stored in $t8 
# HOW TO HANDLE FRACTIONS???
# well first take the 23 bits, normalize it. then just do unsinged multiplication for them.
# followingly, you will end up witha maximum of 48 bits, check the first bit, if 0, no normlize needed
# if 1, then normalize and shift accordingly ### IDK HOW
# furthermore, now you need to see the rounding bit and the sticky bit and handle them.
## now you end up with a fraction, exponent and sign. combine them in a single general purpose and print.


exitfmul: 
addiu $sp $sp, 12
jr $ra


exitProgram:
li $v0, 10
syscall
