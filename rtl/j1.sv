/* J1 Forth CPU
 *
 * based on
 *     http://excamera.com/sphinx/fpga-j1.html
 *     https://github.com/ros-drivers/wge100_driver
 *     jamesb@willowgarage.com
 */

module j1(input         sys_clk_i, // main clock
	  input         sys_rst_i, // reset
	  input  [15:0] io_din,    // io data in
	  output        io_rd,     // io read
	  output        io_wr,     // io write
	  output [15:0] io_addr,   // io address
	  output [15:0] io_dout);  // io data out

   typedef enum logic [3:0] {OP_T,OP_N,OP_T_PLUS_N,OP_T_AND_N,
			     OP_T_IOR_N,OP_T_XOR_N,OP_INV_T,OP_N_EQ_T,
			     OP_N_LS_T,OP_N_RSHIFT_T,OP_T_MINUS_1,OP_R,
			     OP_AT,OP_N_LSHIFT_T,OP_DEPTH,OP_N_ULS_T} op_t;

   typedef enum logic [2:0] {INSN_LIT,INSN_UBRANCH,INSN_0BRANCH,
			     INSN_CALL,INSN_ALU} iclass_t;

   typedef struct packed {
      iclass_t           iclass;
      logic              r_to_pc;
      op_t               alu_op;
      logic              t_to_n;
      logic              t_to_r;
      logic              n_to_mem;
      logic              reserved;
      logic signed [1:0] rstack;
      logic signed [1:0] dstack;
   } insn_t;

   var insn_t  insn;
   wire [15:0] immediate = {1'b0,insn[14:0]};

   wire [15:0] ramrd;
   logic       io_sel;

   logic [4:0]  _dsp,dsp;
   logic [15:0] _st0,st0;
   wire [15:0]  st1;
   wire         _dstkW;     // D stack write

   logic [12:0] _pc,pc;
   logic [4:0]  _rsp,rsp;
   wire [15:0]  rst0;
   logic        _rstkW;     // R stack write
   logic [15:0] _rstkD;
   wire _ramWE;             // RAM write enable

   wire [12:0] pc_plus_1;
   assign pc_plus_1 = pc + 13'd1;

   /* Restricted from 16 Kwords to 8 Kwords because of limited memory resources of the Altera Cyclone II.*/
   dpram8kx16 dpram(.address_a(_pc),
		    .address_b(_st0[13:1]),
		    .clock(sys_clk_i),
		    .data_a(16'b0),
		    .data_b(st1),
		    .wren_a(1'b0),
		    .wren_b(_ramWE & (_st0[15:14] == 0)), // TODO: extra signal
		    .q_a(insn),
		    .q_b(ramrd));


   logic [15:0] dstack[32];
   logic [15:0] rstack[32];

   always_ff @(posedge sys_clk_i)
     begin
	if (_dstkW)
	  dstack[_dsp] = st0;

	if (_rstkW)
	  rstack[_rsp] = _rstkD;
     end

   assign st1  = dstack[dsp];
   assign rst0 = rstack[rsp];

   always_comb io_sel = (st0[15:14] != 2'b00); // RAM:00000H...3FFFH I/O:4000H...FFFFH

   wire is_lit     = (insn[15]);
   wire is_ubranch = (insn.iclass == INSN_UBRANCH);
   wire is_0branch = (insn.iclass == INSN_0BRANCH);
   wire is_call    = (insn.iclass == INSN_CALL);
   wire is_alu     = (insn.iclass == INSN_ALU);

   always_comb
     if (is_lit)
       _st0 = immediate;
     else
       begin
	  var op_t op;

	  unique case (1'b1)
	    is_ubranch:  op = OP_T;
	    is_0branch:  op = OP_N;
	    is_call   :  op = OP_T;
	    is_alu    :  op = op_t'(insn.alu_op);
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
            default        _st0 = 16'hxxxx;
	  endcase
       end

   assign io_rd   = (is_alu && (insn.alu_op == OP_AT) && io_sel);
   assign io_wr   = _ramWE;
   assign io_addr = st0;
   assign io_dout = st1;

   assign _ramWE = is_alu & insn.n_to_mem;
   assign _dstkW = is_lit | (is_alu & insn.t_to_n);

   wire signed [4:0] dd = insn.dstack;  // D stack delta
   wire signed [4:0] rd = insn.rstack;  // R stack delta

   always_comb
     if (is_lit)
       begin
	  _dsp   = dsp + 5'd1;
	  _rsp   = rsp;
	  _rstkW = 0;
	  _rstkD = _pc;
       end
     else if (is_alu)
       begin
	  _dsp   = dsp + dd;
	  _rsp   = {$signed(rsp) + $signed(rd)};
	  _rstkW = insn.t_to_r;
	  _rstkD = st0;
       end
     else // jump/call
       begin
	  // predicated jump is like DROP
	  if (is_0branch)
            _dsp = dsp - 5'd1;
	  else
            _dsp = dsp;

	  if (is_call)
	    begin // call
	       _rsp   = rsp + 5'd1;
	       _rstkW = 1;
	       //_rstkD = {pc_plus_1[14:0],1'b0};
	       _rstkD = pc_plus_1 << 1;
	    end
	  else
	    begin
	       _rsp   = rsp;
	       _rstkW = 0;
	       _rstkD = _pc;
	    end
       end

   always_comb
     if (sys_rst_i)
       _pc = pc;
     else
       if (is_ubranch || (is_0branch && (st0 == 16'h0000)) || is_call)
         _pc = insn[12:0];
       else if (is_alu && insn[12])
         //_pc = {1'b0,rst0[15:1]};
         _pc = rst0 >> 1;
       else
         _pc = pc_plus_1;

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
