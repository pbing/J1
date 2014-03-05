/* J1 Forth CPU
 *
 * based on
 *     http://excamera.com/sphinx/fpga-j1.html
 *     https://github.com/ros-drivers/wge100_driver
 *     jamesb@willowgarage.com
 */

module j1(input               sys_clk_i, // main clock
	  input               sys_rst_i, // reset
	  input        [15:0] io_din,    // io data in
	  output logic        io_rd,     // io read
	  output logic        io_wr,     // io write
	  output logic [15:0] io_addr,   // io address
	  output logic [15:0] io_dout);  // io data out

   typedef enum logic [2:0] {TAG_UBRANCH,TAG_ZBRANCH,TAG_CALL,TAG_ALU} tag_t;

   typedef enum logic [3:0] {OP_T,OP_N,OP_T_PLUS_N,OP_T_AND_N,
			     OP_T_IOR_N,OP_T_XOR_N,OP_INV_T,OP_N_EQ_T,
			     OP_N_LS_T,OP_N_RSHIFT_T,OP_T_MINUS_1,OP_R,
			     OP_AT,OP_N_LSHIFT_T,OP_DEPTH,OP_N_ULS_T} op_t;

   typedef struct packed {
      logic        tag;
      logic [14:0] immediate;
   } lit_t;

   typedef struct packed {
      tag_t        tag;
      logic [12:0] address;
   } branch_t;

   typedef struct packed {
      tag_t              tag;
      logic              r_to_pc;
      op_t               alu_op;
      logic              t_to_n;
      logic              t_to_r;
      logic              n_to_mem;
      logic              reserved;
      logic signed [1:0] rstack;
      logic signed [1:0] dstack;
   } alu_t;

   logic [15:0] insn;      // instruction
   logic [12:0] _pc,pc;    // processor counter
   logic [12:0] pc_plus_1; // processor counter + 1
   logic        io_sel;    // I/O select

   /* select instruction types */
   logic is_lit,is_ubranch,is_zbranch,is_call,is_alu;

   /* RAM */
   wire  [15:0] ramrd;  // RAM read data
   logic        _ramWE; // RAM write enable

   /* data stack */
   logic        [15:0] dstack[32]; // data stack memory
   logic        [4:0]  _dsp,dsp;   // data stack pointer
   logic        [15:0] _st0,st0;   // top of data stack
   logic        [15:0] st1;        // next of data stack
   logic               _dstkW;     // data stack write

   /* return stack */
   logic        [15:0] rstack[32]; // return stack memory
   logic        [4:0]  _rsp,rsp;   // return stack pointer
   logic        [15:0]  rst0;      // top of return stack
   logic        [15:0] _rstkD;     // return stack data
   logic               _rstkW;     // return stack write

   dpram8kx16 dpram(.clock(sys_clk_i),

		    .address_a(_pc),
		    .data_a(16'h0),
		    .wren_a(1'b0),
		    .q_a(insn),

		    .address_b(/*_st0[13:1]*/st0[13:1]),
		    .data_b(st1),
		    .wren_b(_ramWE),
		    .q_b(ramrd));

   /* data and return stack */
   always_ff @(posedge sys_clk_i)
     begin
	if (_dstkW)
	  dstack[_dsp] = st0;

	if (_rstkW)
	  rstack[_rsp] = _rstkD;
     end

   always_comb
     begin
	st1  = dstack[dsp];
	rst0 = rstack[rsp];
     end

   /* select instruction types */
   always_comb
     begin
	/* Because unions are not supported by the Quartus II software we have to work around it. */
	var lit_t    lit_instr;
	var branch_t bra_instr;

	lit_instr  = insn;
	bra_instr  = insn;
	is_lit     = lit_instr.tag;
	is_ubranch = (bra_instr.tag == TAG_UBRANCH);
	is_zbranch = (bra_instr.tag == TAG_ZBRANCH);
	is_call    = (bra_instr.tag == TAG_CALL);
	is_alu     = (bra_instr.tag == TAG_ALU);
     end

   /* calculate next TOS value */
   always_comb
     if (is_lit)
       begin
	  var lit_t instr;

	  instr = insn;
	  _st0  = {1'b0,instr.immediate};
       end
     else
       begin
	  var op_t  op;
	  var alu_t instr;

	  instr = insn;

	  unique case (1'b1)
	    is_ubranch:  op = OP_T;
	    is_zbranch:  op = OP_N;
	    is_call   :  op = OP_T;
	    is_alu    :  op = op_t'(instr.alu_op);
	    default      op = op_t'('x);
	  endcase

	  case (op)
            OP_T         : _st0 = st0;
            OP_N         : _st0 = st1;
            OP_T_PLUS_N  : _st0 = st0 + st1;
            OP_T_AND_N   : _st0 = st0 & st1;
            OP_T_IOR_N   : _st0 = st0 | st1;
            OP_T_XOR_N   : _st0 = st0 ^ st1;
            OP_INV_T     : _st0 = ~st0;
            OP_N_EQ_T    : _st0 = {16{(st1 == st0)}};
            OP_N_LS_T    : _st0 = {16{($signed(st1) < $signed(st0))}};
            OP_N_RSHIFT_T: _st0 = st1 >> st0[3:0];
            OP_T_MINUS_1 : _st0 = st0 - 16'd1;
            OP_R         : _st0 = rst0;
            OP_AT        : _st0 = (io_sel) ? io_din : ramrd;
            OP_N_LSHIFT_T: _st0 = st1 << st0[3:0];
            OP_DEPTH     : _st0 = {rsp,3'b000,dsp};
            OP_N_ULS_T   : _st0 = {16{(st1 < st0)}};
            default        _st0 = 16'hx;
	  endcase
       end

   /* I/O and RAM control */
   always_comb
     begin
	var alu_t instr;
	logic     wr_en;

	instr   = insn;
	wr_en   = is_alu & instr.n_to_mem;
	io_sel  = (st0[15:14] != 2'b00); // I/O:4000H...FFFFH
	io_rd   = (is_alu && (instr.alu_op == OP_AT) && io_sel);
	io_wr   = wr_en & io_sel;
	io_addr = st0 >> 1; // changed from original design
	io_dout = st1;

	//_ramWE = wr_en && (_st0[15:14] == 2'b00); // RAM:00000H...3FFFH
	_ramWE = wr_en && !io_sel; // RAM:00000H...3FFFH
	_dstkW = is_lit | (is_alu & instr.t_to_n);
     end

   always_comb pc_plus_1 = pc + 13'd1;

   always_comb
     /* literals */
     if (is_lit)
       begin
	  _dsp   = dsp + 5'd1;
	  _rsp   = rsp;
	  _rstkW = 0;
	  _rstkD = 16'hx; // don't care
       end
   /* ALU operations */
     else if (is_alu)
       begin
	  var alu_t          instr;
	  logic signed [4:0] dd,rd; // stack delta

	  instr  = insn;
	  dd     = instr.dstack;
	  rd     = instr.rstack;
	  _dsp   = dsp + dd;
	  _rsp   = rsp + rd;
	  _rstkW = instr.t_to_r;
	  _rstkD = st0;
       end
     else
       /* jump/call */
       begin
	  /* predicated jump is like DROP */
	  if (is_zbranch)
            _dsp = dsp - 5'd1;
	  else
            _dsp = dsp;

	  if (is_call)
	    /* call */
	    begin
	       _rsp   = rsp + 5'd1;
	       _rstkW = 1'b1;
	       _rstkD = pc_plus_1 << 1;
	    end
	  else
	    /* */
	    begin
	       _rsp   = rsp;
	       _rstkW = 1'b0;
	       _rstkD = 16'hx; // don't care
	    end
       end

   /* control PC */
   always_comb
     begin
	var branch_t bra_instr;
	var alu_t    alu_instr;

	bra_instr = insn;
	alu_instr = insn;

	if (sys_rst_i)
	  _pc = pc;
	else
	  if (is_ubranch || (is_zbranch && (st0 == 16'h0)) || is_call)
            _pc = bra_instr.address;
	  else if (is_alu && alu_instr.r_to_pc)
            _pc = rst0 >> 1;
	  else
            _pc = pc_plus_1;
     end

   /* update PC and stacks */
   always_ff @(posedge sys_clk_i)
     if (sys_rst_i)
       begin
	  pc  <= 0;
	  dsp <= 0;
	  st0 <= 0;
	  rsp <= 0;
       end
     else
       begin
	  pc  <= _pc;
	  dsp <= _dsp;
	  st0 <= _st0;
	  rsp <= _rsp;
       end
endmodule
