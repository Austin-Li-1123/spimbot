.data
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1
three:  .float  3.0
five:   .float  5.0
PI:     .float  3.141592
F180: .float 180.0

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c

SUBMIT_ORDER 			= 0xffff00b0
DROPOFF 				= 0xffff00c0
PICKUP 					= 0xffff00e0
GET_TILE_INFO			= 0xffff0050
SET_TILE				= 0xffff0058

REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK      = 0xffff00d8

GET_MONEY               = 0xffff00e4
GET_LAYOUT 				= 0xffff00ec
SET_REQUEST 			= 0xffff00f0
GET_REQUEST 			= 0xffff00f4

GET_INVENTORY 			= 0xffff0040
GET_TURNIN_ORDER 		= 0xffff0044
GET_TURNIN_USERS		= 0xffff0048
GET_SHARED 				= 0xffff004c

GET_BOOST 				= 0xffff0070
GET_INGREDIENT_INSTANT 	= 0xffff0074
FINISH_APPLIANCE_INSTANT = 0xffff0078

PUZZLE: .space 1808
RECEIVED: .space 4
BONK_RECEIVED: .space 4
SHARE_INFO: .word 0:2
LAYOUT_ARRAY: .space 225
SHARE_INFO_ARRAY: .word 0:12
ORDERS_ARRAY: .word 0:12
INVENTORY: .word 0:4
ORDERS: .word 0:6
PARTNER_REQUEST: .word 0:12
MY_REQUEST: .word 0:2

.text
main:
	# Construct interrupt mask
	li      $t4, 0
	or      $t4, $t4, BONK_INT_MASK # request bonk
	or      $t4, $t4, REQUEST_PUZZLE_INT_MASK	        # puzzle interrupt bit
	or      $t4, $t4, 1 # global enable
	mtc0    $t4, $12

	#Fill in your code here
############################# check bots

	la $t0, LAYOUT_ARRAY;
	sw $t0, GET_LAYOUT;

	la $t0, PARTNER_REQUEST;

	li $t1, 12;
	sw $t1, 0($t0);
	sw $t1, 4($t0);
	sw $t1, 8($t0);
	sw $t1, 12($t0);
	sw $t1, 16($t0);
	sw $t1, 20($t0);
	sw $t1, 24($t0);
	sw $t1, 32($t0);
	sw $t1, 36($t0);
	sw $t1, 40($t0);
	sw $t1, 44($t0);

	move $a0, $t0;
	jal create_request;

	la $t0, MY_REQUEST;
	sw $v0, 0($t0);
	sw $v1, 4($t0);

	sw $t0, SET_REQUEST

	lw $t0, BOT_X
	blt $t0, 100, left_bot
	j right_bot
#############################
create_request:
	sub		$sp, $sp, 4
	sw		$ra, 0($sp)		# save $ra on stack

	lw		$v0, 24($a0)	#unsigned lo = ((array[6] << 30) >> 30);
	sll		$v0, $v0, 30
	srl		$v0, $v0, 30

	li		$t0, 5
first_loop_create:
	blt 	$t0, 0, second_loop_start_create	#for (int i = 5; i >= 0; --i) {
	sll		$v0, $v0, 5		#lo = lo << 5;
	mul		$t1, $t0, 4		#Calculate array[i]
	add		$t2, $a0, $t1
	lw		$t1, 0($t2)		#Load array[i]
	or		$v0, $v0, $t1	#lo |= array[i];
	sub		$t0, $t0, 1
	j first_loop_create

second_loop_start_create:
	li		$t0, 12
	li		$v1, 0

second_loop_create:
	ble 	$t0, 7, intermediate_bits_create	#  for (int i = 12; i > 7; --i) {
	mul		$t1, $t0, 4		#Calculate array[i]
	add		$t2, $a0, $t1
	lw		$t1, 0($t2)		#Load array[i]
	or		$v1, $v1, $t1	#hi |= array[i];
	sll		$v1, $v1, 5		#hi = hi << 5;

	sub		$t0, $t0, 1
	j second_loop_create

intermediate_bits_create:
	lw		$t1, 28($a0)	#Load array[7]
	or		$v1, $v1, $t1	#hi |= array[i];
	sll		$v1, $v1, 3		#hi = hi << 3;
	lw		$t1, 24($a0)	#Load array[6]
	srl		$t1, $t1, 2		#(array[6] >> 2)
	or		$v1, $v1, $t1	#hi |= (array[6] >> 2);

end_create:
	lw		$ra, 0($sp)
	add		$sp, $sp, 4
	jr		$ra

############################# LEFT hard code for grabbing ingredients from the bottom bin
left_bot:
	jal move_down
	jal solve_puzzle
	jal move_right
	jal solve_puzzle
	jal move_down
	jal solve_puzzle
	li $a0, 20;
	li $a1, 50;
	jal sb_arctan;

	li $t0, 90;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 0
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, -180;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	jal pick_left_bins;

	li $a0, 120;
	li $a1, 80;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, -180;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	jal pick_left_bins;

	li $a0, 120;
	li $a1, 80;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, -180;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	jal pick_left_bins;
layout_check_left:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 32($t0);
	beq $t0, 5, wash_at_22;
finish_check_22_wash:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 35($t0);
	beq $t0, 5, wash_at_52;
finish_check_52_wash:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 32($t0);
	beq $t0, 4, cook_at_22;
finish_check_22_cook:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 35($t0);
	beq $t0, 4, cook_at_52;
finish_check_52_cook:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 32($t0);
	beq $t0, 6, chop_at_22;
finish_check_22_chop:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 35($t0);
	beq $t0, 6, chop_at_52;
finish_check_52_chop:

	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $s0, SHARE_INFO_ARRAY;
	lw $t0, 4($s0);
	bne $t0, 0, layout_check_left;
	lw $t0, 8($s0);
	bne $t0, 0, layout_check_left;
	lw $t0, 16($s0);
	bne $t0, 0, layout_check_left;
	lw $t0, 24($s0);
	bne $t0, 0, layout_check_left;
	lw $t0, 36($s0);
	bne $t0, 0, layout_check_left;


	jal move_down;
	jal solve_puzzle;
	la $t0, ORDERS;
	sw $t0, GET_TURNIN_ORDER;

	la $a0, ORDERS;
	lw $a0, 0($a0);
	la $a1, ORDERS;
	lw $a1, 4($a1);
	la $a2, ORDERS_ARRAY;

	jal decode_request;

	la $s0, ORDERS_ARRAY;
	lw $t0, 0($s0);
lettuce_loop:
	ble $t0, $0, lettuce_loop_end;
	li $t1, 0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	li $t1, 5;
	sll $t1, $t1, 16;
	add $t1, $t1, 2;
	sw $t1, PICKUP;

	li $t1, 90
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	sw $0, DROPOFF;
	sub $t0, $t0, 1
	j lettuce_loop;
lettuce_loop_end:
	la $s0, ORDERS_ARRAY;
	lw $t0, 12($s0);
onion_loop:
	ble $t0, $0, onion_loop_end;
	li $t1, 0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	li $t1, 4;
	sll $t1, $t1, 16;
	add $t1, $t1, 1;
	sw $t1, PICKUP;

	li $t1, 90
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	sw $0, DROPOFF;
	sub $t0, $t0, 1
	j onion_loop;
onion_loop_end:
	la $s0, ORDERS_ARRAY;
	lw $t0, 20($s0);
tomato_loop:
	ble $t0, $0, tomato_loop_end;
	li $t1, 0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	li $t1, 3;
	sll $t1, $t1, 16;
	add $t1, $t1, 1;
	sw $t1, PICKUP;

	li $t1, 90
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	sw $0, DROPOFF;
	sub $t0, $t0, 1
	j tomato_loop;
tomato_loop_end:
	la $s0, ORDERS_ARRAY;
	lw $t0, 32($s0);
meat_loop:
	ble $t0, $0, meat_loop_end;
	li $t1, 0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	li $t1, 2;
	sll $t1, $t1, 16;
	add $t1, $t1, 1;
	sw $t1, PICKUP;

	li $t1, 90
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	sw $0, DROPOFF;
	sub $t0, $t0, 1
	j meat_loop;
meat_loop_end:
	la $s0, ORDERS_ARRAY;
	lw $t0, 40($s0);
cheese_loop:
	ble $t0, $0, cheese_loop_end;
	li $t1, 0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	li $t1, 1;
	sll $t1, $t1, 16;
	sw $t1, PICKUP;

	li $t1, 90
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	sw $0, DROPOFF;
	sub $t0, $t0, 1
	j cheese_loop;
cheese_loop_end:
	la $s0, ORDERS_ARRAY;
	lw $t0, 44($s0);
bread_loop:
	ble $t0, $0, bread_loop_end;
	li $t1, 0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	li $t1, 0;
	sll $t1, $t1, 16;
	sw $t1, PICKUP;

	li $t1, 90
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right

	sw $0, DROPOFF;
	sub $t0, $t0, 1
	j bread_loop;
bread_loop_end:

	sw $0, SUBMIT_ORDER;

	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $s0, SHARE_INFO_ARRAY;
	lw $t0, 44($s0);
	beq $t0, 0, inf;

	j finish_check_52_chop;

inf:
	j inf;
##############################################
wash_at_22:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 8($t0); #unwashed unchopped lettuce
	la $t1, SHARE_INFO_ARRAY; #unwashed tomato
	lw $t1, 24($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_wash_22;
	li $t0, 5;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 3
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	#jal move_left_one;
	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
wash_loop_22:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_wash_22_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020002
	sw $t3, SET_TILE
wash_wait_22:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, wash_ready_22
	j wash_wait_22
wash_ready_22:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j wash_loop_22;
finish_wash_22_loop:


	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	sw $v0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, 0;
	li $t1, 4;
drop_all_wash_22:
	bge $t0, $t1, finish_drop_wash_22;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_wash_22;
finish_drop_wash_22:
	j wash_at_22
finish_wash_22:
	j finish_check_22_wash;
###############################################
wash_at_52:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 8($t0); #unwashed unchopped lettuce
	la $t1, SHARE_INFO_ARRAY; #unwashed tomato
	lw $t1, 24($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_wash_52;
	li $t0, 5;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 3
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	#jal move_left_52;
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
wash_loop_52:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_wash_52_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020005
	sw $t3, SET_TILE
wash_wait_52:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, wash_ready_52
	j wash_wait_52
wash_ready_52:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j wash_loop_52;
finish_wash_52_loop:
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	sw $v0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
drop_all_wash_52:
	bge $t0, $t1, finish_drop_wash_52;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_wash_52;
finish_drop_wash_52:
	j wash_at_52
finish_wash_52:
	j finish_check_52_wash;
###############################################
cook_at_22:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 36($t0); #unwashed unchopped lettuce
	beq $t0, $zero, finish_cook_22;
	li $t0, 2;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
cook_loop_22:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_cook_22_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020002
	sw $t3, SET_TILE
cook_wait_22:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, cook_ready_22
	j cook_wait_22
cook_ready_22:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j cook_loop_22;
finish_cook_22_loop:
	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	sw $v0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
drop_all_cook_22:
	bge $t0, $t1, finish_drop_cook_22;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_cook_22;
finish_drop_cook_22:
	j cook_at_22
finish_cook_22:
	j finish_check_22_cook;
###############################################
cook_at_52:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 36($t0); #unwashed unchopped lettuce
	beq $t0, $zero, finish_cook_52;
	li $t0, 2;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 2
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	#jal move_left_52;
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
	cook_loop_52:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_cook_52_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020005
	sw $t3, SET_TILE
	cook_wait_52:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, cook_ready_52
	j cook_wait_52
	cook_ready_52:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j cook_loop_52;
	finish_cook_52_loop:
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	sw $v0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
	drop_all_cook_52:
	bge $t0, $t1, finish_drop_cook_52;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_cook_52;
	finish_drop_cook_52:
	j cook_at_52
	finish_cook_52:
	j finish_check_52_cook;
###############################################
chop_at_22:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 4($t0); #unchopped lettuce
	la $t1, SHARE_INFO_ARRAY; #unwashed tomato
	lw $t1, 16($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_chop_22;
	li $t0, 5;
	sll $t0, $t0, 16;
	add $t0, $t0, 1;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 4
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	#jal move_left_one;
	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
chop_loop_22:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_chop_22_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020002
	sw $t3, SET_TILE
	lw $t4, GET_TILE_INFO
	add $t4, $t4, 1
chop_wait_22:
	lw $t3, GET_TILE_INFO
	beq $t3, $t4, chop_ready_22
	j chop_wait_22
chop_ready_22:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j chop_loop_22;
finish_chop_22_loop:


	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	sw $v0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, 0;
	li $t1, 4;
drop_all_chop_22:
	bge $t0, $t1, finish_drop_chop_22;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_chop_22;
finish_drop_chop_22:
	j chop_at_22
finish_chop_22:
	j finish_check_22_chop;
###############################################
chop_at_52:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 4($t0); #unwashed unchopped lettuce
	la $t1, SHARE_INFO_ARRAY;
	lw $t1, 16($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_chop_52;
	li $t0, 5;
	sll $t0, $t0, 16;
	add $t0, $t0, 1;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 4
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	#jal move_left_52;
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t0, 180;
	add $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
	chop_loop_52:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_chop_52_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020005
	sw $t3, SET_TILE
	lw $t4, GET_TILE_INFO
	add $t4, $t4, 1;
chop_wait_52:
	lw $t3, GET_TILE_INFO
	beq $t3, $t4, chop_ready_52
	j chop_wait_52
chop_ready_52:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j chop_loop_52;
	finish_chop_52_loop:
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	sw $v0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
	drop_all_chop_52:
	bge $t0, $t1, finish_drop_chop_52;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_chop_52;
	finish_drop_chop_52:
	j chop_at_52
	finish_chop_52:
	j finish_check_52_chop;
###############################################
pick_left_bins:
		sub $sp, $sp, 4;
		sw $ra, 0($sp);
		li $t0, 0;
		li $t1, 3;
pick_one_time:
		beq $t0, $t1, finish_this_bin;
		sw $0, PICKUP;
		sw $0, PICKUP;
		sw $0, PICKUP;
		sw $0, PICKUP;
		jal move_right
		jal solve_puzzle
	  li $t2, 0;
		li $t3, 4;
drop_all:
		bge $t2, $t3, finish_drop;
		sw $t2, DROPOFF;
		add $t2, $t2, 1;
		j drop_all;
finish_drop:
		add $t0, $t0, 1;
		beq $t0, $t1, finish_this_bin;
		jal move_left;
		jal solve_puzzle;
		j pick_one_time;
finish_this_bin:

		lw $ra, 0($sp);
		add $sp, $sp, 4;
		jr $ra;

#############################
############################# RIGHT hard code for grabbing ingredients from the bottom bin
right_bot:
	jal move_down
	jal solve_puzzle
	jal move_left
	jal solve_puzzle
	jal move_down
	jal solve_puzzle
	li $a0, 20;
	li $a1, 50;
	jal sb_arctan;


	li $t0, -1;
	mul $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	jal pick_right_bins;

	li $a0, 120;
	li $a1, 80;
	jal sb_arctan;
	li $t0, -1;
	mul $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	jal pick_right_bins;

	li $a0, 120;
	li $a1, 80;
	jal sb_arctan;
	li $t0, -1;
	mul $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	jal pick_right_bins;
layout_check_right:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 42($t0);
	beq $t0, 5, wash_at_122;
finish_check_122_wash:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 39($t0);
	beq $t0, 5, wash_at_92;
finish_check_92_wash:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 42($t0);
	beq $t0, 4, cook_at_122;
finish_check_122_cook:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 39($t0);
	beq $t0, 4, cook_at_92;
finish_check_92_cook:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 42($t0);
	beq $t0, 6, chop_at_122;
finish_check_122_chop:
	la $t0, LAYOUT_ARRAY;
	lb $t0, 39($t0);
	beq $t0, 6, chop_at_92;
finish_check_92_chop:

	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $s0, SHARE_INFO_ARRAY;
	lw $t0, 4($s0);
	bne $t0, 0, layout_check_right;
	lw $t0, 8($s0);
	bne $t0, 0, layout_check_right;
	lw $t0, 16($s0);
	bne $t0, 0, layout_check_right;
	lw $t0, 24($s0);
	bne $t0, 0, layout_check_right;
	lw $t0, 36($s0);
	bne $t0, 0, layout_check_right;


jal move_down;
jal solve_puzzle;
la $t0, ORDERS;
sw $t0, GET_TURNIN_ORDER;

la $a0, ORDERS;
lw $a0, 0($a0);
la $a1, ORDERS;
lw $a1, 4($a1);
la $a2, ORDERS_ARRAY;

jal decode_request;

la $s0, ORDERS_ARRAY;
lw $t0, 0($s0);
lettuce_loop2:
ble $t0, $0, lettuce_loop_end2;
li $t1, -180
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

li $t1, 5;
sll $t1, $t1, 16;
add $t1, $t1, 2;
sw $t1, PICKUP;

li $t1, 90
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

sw $0, DROPOFF;
sub $t0, $t0, 1
j lettuce_loop2;
lettuce_loop_end2:
la $s0, ORDERS_ARRAY;
lw $t0, 12($s0);
onion_loop2:
ble $t0, $0, onion_loop_end2;
li $t1, -180
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

li $t1, 4;
sll $t1, $t1, 16;
add $t1, $t1, 1;
sw $t1, PICKUP;

li $t1, 90
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

sw $0, DROPOFF;
sub $t0, $t0, 1
j onion_loop2;
onion_loop_end2:
la $s0, ORDERS_ARRAY;
lw $t0, 20($s0);
tomato_loop2:
ble $t0, $0, tomato_loop_end2;
li $t1, -180
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

li $t1, 3;
sll $t1, $t1, 16;
add $t1, $t1, 1;
sw $t1, PICKUP;

li $t1, 90
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

sw $0, DROPOFF;
sub $t0, $t0, 1
j tomato_loop2;
tomato_loop_end2:
la $s0, ORDERS_ARRAY;
lw $t0, 32($s0);
meat_loop2:
ble $t0, $0, meat_loop_end2;
li $t1, -180
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

li $t1, 2;
sll $t1, $t1, 16;
add $t1, $t1, 1;
sw $t1, PICKUP;

li $t1, 90
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

sw $0, DROPOFF;
sub $t0, $t0, 1
j meat_loop2;
meat_loop_end2:
la $s0, ORDERS_ARRAY;
lw $t0, 40($s0);
cheese_loop2:
ble $t0, $0, cheese_loop_end2;
li $t1, -180
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

li $t1, 1;
sll $t1, $t1, 16;
sw $t1, PICKUP;

li $t1, 90
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

sw $0, DROPOFF;
sub $t0, $t0, 1
j cheese_loop2;
cheese_loop_end2:
la $s0, ORDERS_ARRAY;
lw $t0, 44($s0);
bread_loop2:
ble $t0, $0, bread_loop_end2;
li $t1, -180
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

li $t1, 0;
sll $t1, $t1, 16;
sw $t1, PICKUP;

li $t1, 90
sw $t1, 0xffff0014 ($zero)
li $t1, 1
sw $t1, 0xffff0018 ($zero) # point right

sw $0, DROPOFF;
sub $t0, $t0, 1
j bread_loop2;
bread_loop_end2:

sw $0, SUBMIT_ORDER;

la $t0, SHARE_INFO;
sw $t0, GET_SHARED;

la $a0, SHARE_INFO;
lw $a0, 0($a0);
la $a1, SHARE_INFO;
lw $a1, 4($a1);
la $a2, SHARE_INFO_ARRAY;

jal decode_request;

la $s0, SHARE_INFO_ARRAY;
lw $t0, 44($s0);
beq $t0, 0, inf2;

j finish_check_92_chop;
inf2:
	j inf2;
##############################################
wash_at_122:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 8($t0); #unwashed unchopped lettuce
	la $t1, SHARE_INFO_ARRAY; #unwashed tomato
	lw $t1, 24($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_wash_122;
	li $t0, 5;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 3
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t0, 0;
	sub $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
wash_loop_122:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_wash_122_loop;
	sw $t1 DROPOFF
	li $t3, 0x0002000c
	sw $t3, SET_TILE
wash_wait_122:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, wash_ready_122
	j wash_wait_122
wash_ready_122:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j wash_loop_122;
finish_wash_122_loop:


	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t1, -180;
	sub $t1, $t1, $v0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, 0;
	li $t1, 4;
drop_all_wash_122:
	bge $t0, $t1, finish_drop_wash_122;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_wash_122;
finish_drop_wash_122:
	j wash_at_122
finish_wash_122:
	j finish_check_122_wash;
###############################################
wash_at_92:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 8($t0); #unwashed unchopped lettuce
	la $t1, SHARE_INFO_ARRAY; #unwashed tomato
	lw $t1, 24($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_wash_92;
	li $t0, 5;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 3
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	#jal move_left_92;
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t0, 0;
	sub $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
wash_loop_92:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_wash_92_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020009
	sw $t3, SET_TILE
wash_wait_92:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, wash_ready_92
	j wash_wait_92
wash_ready_92:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j wash_loop_92;
finish_wash_92_loop:
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t1, -180;
	sub $t1, $t1, $v0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
drop_all_wash_92:
	bge $t0, $t1, finish_drop_wash_92;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_wash_92;
finish_drop_wash_92:
	j wash_at_92
finish_wash_92:
	j finish_check_92_wash;
###############################################
cook_at_122:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 36($t0); #unwashed unchopped lettuce
	beq $t0, $zero, finish_cook_122;
	li $t0, 2;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t0, 0;
	sub $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
cook_loop_122:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_cook_122_loop;
	sw $t1 DROPOFF
	li $t3, 0x0002000c
	sw $t3, SET_TILE
cook_wait_122:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, cook_ready_122
	j cook_wait_122
cook_ready_122:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j cook_loop_122;
finish_cook_122_loop:
	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t1, -180;
	sub $t1, $t1, $v0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
drop_all_cook_122:
	bge $t0, $t1, finish_drop_cook_122;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_cook_122;
finish_drop_cook_122:
	j cook_at_122
finish_cook_122:
	j finish_check_122_cook;
###############################################
cook_at_92:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 36($t0); #unwashed unchopped lettuce
	beq $t0, $zero, finish_cook_92;
	li $t0, 2;
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 2
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;


	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t0, 0;
	sub $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
	cook_loop_92:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_cook_92_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020009
	sw $t3, SET_TILE
	cook_wait_92:
	lw $t3, GET_TILE_INFO
	li $t4, 1
	beq $t3, $t4, cook_ready_92
	j cook_wait_92
cook_ready_92:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j cook_loop_92;
finish_cook_92_loop:
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t1, -180;
	sub $t1, $t1, $v0;
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
	drop_all_cook_92:
	bge $t0, $t1, finish_drop_cook_92;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_cook_92;
	finish_drop_cook_92:
	j cook_at_92
	finish_cook_92:
	j finish_check_92_cook;
###############################################
chop_at_122:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 4($t0); #unchopped lettuce
	la $t1, SHARE_INFO_ARRAY; #unwashed tomato
	lw $t1, 16($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_chop_122;
	li $t0, 5;
	sll $t0, $t0, 16;
	add $t0, $t0, 1;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 4
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t0, 0;
	sub $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
chop_loop_122:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_chop_122_loop;
	sw $t1 DROPOFF
	li $t3, 0x0002000c
	sw $t3, SET_TILE
	lw $t4, GET_TILE_INFO
	add $t4, $t4, 1
chop_wait_122:
	lw $t3, GET_TILE_INFO
	beq $t3, $t4, chop_ready_122
	j chop_wait_122
chop_ready_122:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j chop_loop_122;
finish_chop_122_loop:


	li $a0, 90;
	li $a1, 7;
	jal sb_arctan;
	li $t1, -180;
	sub $t1, $t1, $v0
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, 0;
	li $t1, 4;
drop_all_chop_122:
	bge $t0, $t1, finish_drop_chop_122;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_chop_122;
finish_drop_chop_122:
	j chop_at_122
finish_chop_122:
	j finish_check_122_chop;
###############################################
chop_at_92:
	la $t0, SHARE_INFO;
	sw $t0, GET_SHARED;

	la $a0, SHARE_INFO;
	lw $a0, 0($a0);
	la $a1, SHARE_INFO;
	lw $a1, 4($a1);
	la $a2, SHARE_INFO_ARRAY;

	jal decode_request;

	la $t0, SHARE_INFO_ARRAY;
	lw $t0, 4($t0); #unwashed unchopped lettuce
	la $t1, SHARE_INFO_ARRAY;
	lw $t1, 16($t1);
	add $t0, $t0, $t1; #lettuce and tomato
	beq $t0, $zero, finish_chop_92;
	li $t0, 5;
	sll $t0, $t0, 16;
	add $t0, $t0, 1;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;

	li $t0, 4
	sll $t0, $t0, 16;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;
	sw $t0, PICKUP;


	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t0, 0;
	sub $t0, $t0 $v0;
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;

	li $t0, -90;
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL # point right

	la $t0, INVENTORY;
	sw $t0, GET_INVENTORY;

	li $t1, 0;
	chop_loop_92:
	mul $t2, $t1, 4
	add $t2, $t2, $t0;
	lw $t2, 0($t2);
	beq $t2, $0, finish_chop_92_loop;
	sw $t1 DROPOFF
	li $t3, 0x00020009
	sw $t3, SET_TILE
	lw $t4, GET_TILE_INFO
	add $t4, $t4, 1;
chop_wait_92:
	lw $t3, GET_TILE_INFO
	beq $t3, $t4, chop_ready_92
	j chop_wait_92
chop_ready_92:
	sw $zero, PICKUP
	add $t1, $t1, 1;
	j chop_loop_92;
finish_chop_92_loop:
	li $a0, 30;
	li $a1, 8;
	jal sb_arctan;
	li $t1, -180;
	sub $t1, $t1, $v0;
	sw $t1, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jal solve_puzzle;
	li $t0, 0;
	li $t1, 4;
	drop_all_chop_92:
	bge $t0, $t1, finish_drop_chop_92;
	sw $t0, DROPOFF;
	add $t0, $t0, 1;
	j drop_all_chop_92;
	finish_drop_chop_92:
	j chop_at_92
	finish_chop_92:
	j finish_check_92_chop;


pick_right_bins:
		sub $sp, $sp, 4;
		sw $ra, 0($sp);
		li $t0, 0;
		li $t1, 3;
pick_one_time_right:
		beq $t0, $t1, finish_this_bin_right;
		sw $0, PICKUP;
		sw $0, PICKUP;
		sw $0, PICKUP;
		sw $0, PICKUP;
		jal move_left
		jal solve_puzzle
	  li $t2, 0;
		li $t3, 4;
drop_all_right:
		bge $t2, $t3, finish_drop_right;
		sw $t2, DROPOFF;
		add $t2, $t2, 1;
		j drop_all_right;
finish_drop_right:
		add $t0, $t0, 1;
		beq $t0, $t1, finish_this_bin_right;
		jal move_right;
		jal solve_puzzle;
		j pick_one_time_right;
finish_this_bin_right:

		lw $ra, 0($sp);
		add $sp, $sp, 4;
		jr $ra;


############################# helper function for spimbot
solve_puzzle:
	la $s0, PUZZLE;
	sw $s0, REQUEST_PUZZLE;

wait_puzzle_bonk:
	lw $s0, RECEIVED;
	bne $s0, $0, puzzle_reveived;
	j wait_puzzle_bonk;

puzzle_reveived:
	la $a0, PUZZLE;
	sub $sp, $sp, 4;
	sw $ra, 0($sp);
	jal islandfill;
	lw $ra, 0($sp);
  add $sp, $sp, 4;
	la $s0, PUZZLE;
	sw $s0, SUBMIT_SOLUTION;
	sw $0, RECEIVED;
	lw $s1, BONK_RECEIVED;
	bne $s1, $0, puzzle_bonk_end;
	j solve_puzzle;

puzzle_bonk_end:
	sw $0, BONK_RECEIVED;
	sw $0, RECEIVED;
	jr $ra;
############################# helper function ends here

############################# move functions

move_up:
	li $t0, -90
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jr $ra
###############################################
move_down:
	li $t0, 90
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity
	jr $ra
###############################################
move_left:
	sub $sp, $sp, 8;
	sw $t0, 0($sp);
	sw $t1, 4($sp);
	li $t0, 180
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity

	lw $t0, 0($sp);
	lw $t1, 4($sp);
	add $sp, $sp, 8;
	jr $ra

###############################################
move_right:
	sub $sp, $sp, 8;
	sw $t0, 0($sp);
	sw $t1, 4($sp);

	li $t0, 0
	sw $t0, 0xffff0014 ($zero)
	li $t1, 1
	sw $t1, 0xffff0018 ($zero) # point right
	li $t2, 10
	sw $t2, 0xffff0010 ($zero) # set max velocity


	lw $t0, 0($sp);
	lw $t1, 4($sp);
	add $sp, $sp, 8;
	jr $ra

############################################### one step
move_up_one:
	li $a0, -90
	sw $a0, 0xffff0014 ($zero)
	li $t0, 1
	sw $t0, 0xffff0018 ($zero) # point right
	li $t1, 10
	sw $t1, 0xffff0010 ($zero) # set max velocity
	lw $t0, BOT_Y
	sub $t0, $t0, 20
loop_up_one:
	lw $t1, BOT_Y
	ble $t1, $t0, stop_up_one
	j loop_up_one
stop_up_one:
	li $t2, 0
	sw $t2, 0xffff0010 ($zero)
	jr $ra

move_down_one:
	li $a0, 90
	sw $a0, 0xffff0014 ($zero)
	li $t0, 1
	sw $t0, 0xffff0018 ($zero) # point right
	li $t1, 10
	sw $t1, 0xffff0010 ($zero) # set max velocity
	lw $t0, BOT_Y
	add $t0, $t0, 20
loop_down_one:
	lw $t1, BOT_Y
	bge $t1, $t0, stop_down_one
	j loop_down_one
stop_down_one:
	li $t2, 0
	sw $t2, 0xffff0010 ($zero)
	jr $ra

move_left_one:
	li $a0, 180
	sw $a0, 0xffff0014 ($zero)
	li $t0, 1
	sw $t0, 0xffff0018 ($zero) # point right
	li $t1, 10
	sw $t1, 0xffff0010 ($zero) # set max velocity
	lw $t0, BOT_X
	sub $t0, $t0, 90
loop_left_one:
	lw $t1, BOT_X
	ble $t1, $t0, stop_left_one
	j loop_left_one
stop_left_one:
	li $t2, 0
	sw $t2, 0xffff0010 ($zero)
	jr $ra

move_left_52:
	li $a0, 180
	sw $a0, 0xffff0014 ($zero)
	li $t0, 1
	sw $t0, 0xffff0018 ($zero) # point right
	li $t1, 10
	sw $t1, 0xffff0010 ($zero) # set max velocity
	lw $t0, BOT_X
	sub $t0, $t0, 30
loop_left_52:
	lw $t1, BOT_X
	ble $t1, $t0, stop_left_52
	j loop_left_52
stop_left_52:
	li $t2, 0
	sw $t2, 0xffff0010 ($zero)
	jr $ra

move_right_one:
	li $a0, 0
	sw $a0, 0xffff0014 ($zero)
	li $t0, 1
	sw $t0, 0xffff0018 ($zero) # point right
	li $t1, 10
	sw $t1, 0xffff0010 ($zero) # set max velocity
	lw $t0, BOT_X
	add $t0, $t0, 20
loop_right_one:
	lw $t1, BOT_X
	bge $t1, $t0, stop_right_one
	j loop_right_one
stop_right_one:
	li $t2, 0
	sw $t2, 0xffff0010 ($zero)
	jr $ra

############################# libs for spim bot
floodfill:
        slt     $t0, $a2, 0
        slt     $t1, $a3, 0
        or      $t0, $t1, $t0
        beq     $t0, 0, f_end_if1
        move    $v0, $a1
        jr      $ra
f_end_if1:
        lw      $t0, 0($a0)
        lw      $t1, 4($a0)
        sge     $t0, $a2, $t0
        sge     $t1, $a3, $t1
        or      $t0, $t1, $t0

        beq     $t0, 0, f_end_if2
        move    $v0, $a1
        jr      $ra
f_end_if2:
        lw      $t0, 0($a0)
        lw      $t1, 4($a0)
        mul     $t2, $a2, $t1
        add     $t2, $t2, $a3
        add     $t2, $t2, $a0
        add     $t2, $t2, 8
        lb      $t3, 0($t2)

        beq     $t3, '#', f_endif_3
        move    $v0, $a1
        jr      $ra
f_endif_3:

f_recur:
        sub     $sp, $sp, 88
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        sw      $t3, 48($sp)
        sw      $t4, 52($sp)
        sw      $t5, 56($sp)
        sw      $t6, 60($sp)
        sw      $t7, 64($sp)
        sw      $t8, 68($sp)
        sw      $t9, 72($sp)
        sw      $s4, 20($sp)
        sw      $s5, 24($sp)
        sw      $s6, 28($sp)
        sw      $s7, 32($sp)
        sw      $t0, 36($sp)
        sw      $t1, 40($sp)
        sw      $t2, 44($sp)
        sw      $a0, 76($sp)
        sw      $a1, 80($sp)
        sw      $a2, 84($sp)

        sb      $a1, 0($t2)

        move    $s0, $a0
        move    $s1, $a1
        move    $s2, $a2
        move    $s3, $a3

        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, 1
        add     $a3, $s3, 1
        jal     floodfill


        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, 1
        add     $a3, $s3, 0
        jal     floodfill

        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, 1
        add     $a3, $s3, -1
        jal     floodfill

        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, 0
        add     $a3, $s3, 1
        jal     floodfill

        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, 0
        add     $a3, $s3, -1
        jal     floodfill

        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, -1
        add     $a3, $s3, 1
        jal     floodfill

        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, -1
        add     $a3, $s3, 0
        jal     floodfill

        move    $a0, $s0
        move    $a1, $s1
        add     $a2, $s2, -1
        add     $a3, $s3, -1
        jal     floodfill

        add     $v0, $a1, 1
f_done:
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        lw      $s4, 20($sp)
        lw      $s5, 24($sp)
        lw      $s6, 28($sp)
        lw      $s7, 32($sp)

        lw      $t0, 36($sp)
        lw      $t1, 40($sp)
        lw      $t2, 44($sp)
        lw      $t3, 48($sp)
        lw      $t4, 52($sp)
        lw      $t5, 56($sp)
        lw      $t6, 60($sp)
        lw      $t7, 64($sp)
        lw      $t8, 68($sp)
        lw      $t9, 72($sp)

        lw      $a0, 76($sp)
        lw      $a1, 80($sp)
        lw      $a2, 84($sp)
        add     $sp, $sp, 88

        jr      $ra

islandfill:
        sub     $sp, $sp, 88
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        sw      $s4, 20($sp)
        sw      $s5, 24($sp)
        sw      $s6, 28($sp)
        sw      $s7, 32($sp)
        sw      $t0, 36($sp)
        sw      $t1, 40($sp)
        sw      $t2, 44($sp)
        sw      $t3, 48($sp)
        sw      $t4, 52($sp)
        sw      $t5, 56($sp)
        sw      $t6, 60($sp)
        sw      $t7, 64($sp)
        sw      $t8, 68($sp)
        sw      $t9, 72($sp)
        sw      $a0, 76($sp)
        sw      $a1, 80($sp)
        sw      $a2, 84($sp)

        move    $s0, $a0
        li      $s1, 'A'
        li      $s2, 0

        lw      $s4, 0($a0)
        lw      $s5, 4($a0)

i_outer_loop:
        bge     $s2, $s4, i_outer_end

        li      $s3, 0
i_inner_loop:
        bge     $s3, $s5, i_inner_end

        move    $a0, $s0
        move    $a1, $s1
        move    $a2, $s2
        move    $a3, $s3
        jal     floodfill
        move    $s1, $v0

        add     $s3, $s3, 1
        j       i_inner_loop
i_inner_end:

        add     $s2, $s2, 1
        j       i_outer_loop
i_outer_end:
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        lw      $s4, 20($sp)
        lw      $s5, 24($sp)
        lw      $s6, 28($sp)
        lw      $s7, 32($sp)

        lw      $t0, 36($sp)
        lw      $t1, 40($sp)
        lw      $t2, 44($sp)
        lw      $t3, 48($sp)
        lw      $t4, 52($sp)
        lw      $t5, 56($sp)
        lw      $t6, 60($sp)
        lw      $t7, 64($sp)
        lw      $t8, 68($sp)
        lw      $t9, 72($sp)

        lw      $a0, 76($sp)
        lw      $a1, 80($sp)
        lw      $a2, 84($sp)
        add     $sp, $sp, 88
        jr      $ra

############################# libs end here
sb_arctan:
    li      $v0, 0           # angle = 0;

    abs     $t0, $a0         # get absolute values
    abs     $t1, $a1
    ble     $t1, $t0, no_TURN_90

    ## if (abs(y) > abs(x)) { rotate 90 degrees }
    move    $t0, $a1         # int temp = y;
    neg     $a1, $a0         # y = -x;
    move    $a0, $t0         # x = temp;
    li      $v0, 90          # angle = 90;

no_TURN_90:
    bgez    $a0, pos_x       # skip if (x >= 0)

    ## if (x < 0)
    add     $v0, $v0, 180    # angle += 180;

pos_x:
    mtc1    $a0, $f0
    mtc1    $a1, $f1
    cvt.s.w $f0, $f0         # convert from ints to floats
    cvt.s.w $f1, $f1

    div.s   $f0, $f1, $f0    # float v = (float) y / (float) x;

    mul.s   $f1, $f0, $f0    # v^^2
    mul.s   $f2, $f1, $f0    # v^^3
    l.s     $f3, three       # load 3.0
    div.s   $f3, $f2, $f3    # v^^3/3
    sub.s   $f6, $f0, $f3    # v - v^^3/3

    mul.s   $f4, $f1, $f2    # v^^5
    l.s     $f5, five        # load 5.0
    div.s   $f5, $f4, $f5    # v^^5/5
    add.s   $f6, $f6, $f5    # value = v - v^^3/3 + v^^5/5

    l.s     $f8, PI          # load PI
    div.s   $f6, $f6, $f8    # value / PI
    l.s     $f7, F180        # load 180.0
    mul.s   $f6, $f6, $f7    # 180.0 * value / PI

    cvt.w.s $f6, $f6         # convert "delta" back to integer
    mfc1    $t0, $f6
    add     $v0, $v0, $t0    # angle += delta

    bge     $v0, 0, sb_arc_tan_end
    # negative value received.
    li      $t0, 360
    add     $v0, $t0, $v0

sb_arc_tan_end:
    jr      $ra

###############################################
decode_request:
	sub		$sp, $sp, 4
	sw		$ra, 0($sp)		# save $ra on stack

	li		$t0, 0

first_loop:
	bge 	$t0, 6, intermediate_bits	#for (int i = 0; i < 6; ++i)
	and		$t1, $a0, 0x1f	#array[i] = lo & 0x0000001f;
	mul		$t2, $t0, 4		#Calculate array[i]
	add		$t3, $a2, $t2
	sw		$t1, 0($t3)		#Save array[i]
	srl		$a0, $a0, 5		#lo = lo >> 5;
	add		$t0, $t0, 1
	j first_loop

intermediate_bits:
	sll		$t0, $a1, 2		#unsigned upper_three_bits = (hi << 2) & 0x0000001f;
	and		$t0, $t0, 0x1f
	or		$t0, $t0, $a0	#array[6] = upper_three_bits | lo;
	sw		$t0, 24($a2)
	srl		$a1, $a1, 3		#hi = hi >> 3;

	li		$t0, 7

second_loop:
	bge 	$t0, 12, end	#for (int i = 7; i < 12; ++i)
	and		$t1, $a1, 0x1f	#array[i] = hi & 0x0000001f;
	mul		$t2, $t0, 4		#Calculate array[i]
	add		$t3, $a2, $t2
	sw		$t1, 0($t3)		#Save array[i]
	srl		$a1, $a1, 5		#hi = hi >> 5;
	add		$t0, $t0, 1
	j second_loop

end:
	lw		$ra, 0($sp)
	add		$sp, $sp, 4
	jr		$ra

###############################################
.kdata
chunkIH:    .space 32
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at        # Save $at
.set at
        la        $k0, chunkIH
        sw        $a0, 0($k0)        # Get some free registers
        sw        $v0, 4($k0)        # by storing them to a global variable
        sw        $t0, 8($k0)
        sw        $t1, 12($k0)
        sw        $t2, 16($k0)
        sw        $t3, 20($k0)
		sw $t4, 24($k0)
		sw $t5, 28($k0)

        mfc0      $k0, $13             # Get Cause register
        srl       $a0, $k0, 2
        and       $a0, $a0, 0xf        # ExcCode field
        bne       $a0, 0, non_intrpt



interrupt_dispatch:            # Interrupt:
    mfc0       $k0, $13        # Get Cause register, again
    beq        $k0, 0, done        # handled all outstanding interrupts

    and        $a0, $k0, BONK_INT_MASK    # is there a bonk interrupt?
    bne        $a0, 0, bonk_interrupt

    and        $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne        $a0, 0, timer_interrupt

	and 	$a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne 	$a0, 0, request_puzzle_interrupt

    li        $v0, PRINT_STRING    # Unhandled interrupt types
    la        $a0, unhandled_str
    syscall
    j    done

bonk_interrupt:
	sw 		$0, BONK_ACK
    #Fill in your code here
		li $k0, 1;
		sw $k0, BONK_RECEIVED;
    j       interrupt_dispatch    # see if other interrupts are waiting

request_puzzle_interrupt:
	sw 		$0, REQUEST_PUZZLE_ACK
	#Fill in your code here
	li $k0, 1;
	sw $k0, RECEIVED;
	j	interrupt_dispatch

timer_interrupt:
	sw 		$0, TIMER_ACK
	#Fill in your code here
    j        interrupt_dispatch    # see if other interrupts are waiting

non_intrpt:                # was some non-interrupt
    li        $v0, PRINT_STRING
    la        $a0, non_intrpt_str
    syscall                # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH
    lw      $a0, 0($k0)        # Restore saved registers
    lw      $v0, 4($k0)
	lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
	lw $t4, 24($k0)
	lw $t5, 28($k0)
.set noat
    move    $at, $k1        # Restore $at
.set at
    eret
