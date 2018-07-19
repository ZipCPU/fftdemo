`default_nettype	none
//
module	logfn(i_clk, i_ce, i_sync, i_real, i_imag, o_sample, o_sync);
	localparam	IW=16, OW=8;
	//
	input	wire			i_clk, i_ce, i_sync;
	input	wire	signed [IW-1:0]	i_real, i_imag;
	output	wire	[OW-1:0]	o_sample;
	output	wire			o_sync;
	//
	reg	signed [2*IW-1:0] rp, ip;
	reg	[2*IW:0]	squard;


	always @(posedge i_clk)
	if (i_ce)
	begin
		rp <= i_real * i_real;
		ip <= i_imag * i_imag;
	end

	reg	[3:0]	pre_sync;
	initial	pre_sync = 0;
	always @(posedge i_clk)
		pre_sync <= { pre_sync[2:0], i_sync };

	reg	[6:0]	znibs;
	reg	[4:0]	preshift;
	reg	[5:0]	shft;
	reg	[32:0]	pshiftd;
	reg	[32:0]	shiftd;
	reg	[7:0]	pre_output;

	always @(posedge i_clk)
	if (i_ce)
		squard <= rp + ip;

	always @(posedge i_clk)
	begin
		znibs[6] <= (squard[32:30]==3'h0);
		znibs[5] <= (squard[29:25]==5'h0);
		znibs[4] <= (squard[24:20]==5'h0);
		znibs[3] <= (squard[19:15]==5'h0);
		znibs[2] <= (squard[14:10]==5'h0);
		znibs[1] <= (squard[ 9: 5]==5'h0);
		znibs[0] <= (squard[ 4: 0]==5'h0);
	end

	always @(posedge i_clk)
	if (i_ce)
	begin
		casez(znibs)
		7'b1_0??_???:begin preshift<=5'd03; pshiftd<=(squard <<  3); end
		7'b1_10?_???:begin preshift<=5'd08; pshiftd<=(squard <<  8); end
		7'b1_110_???:begin preshift<=5'd13; pshiftd<=(squard << 13); end
		7'b1_111_0??:begin preshift<=5'd18; pshiftd<=(squard << 18); end
		7'b1_111_10?:begin preshift<=5'd23; pshiftd<=(squard << 23); end
		7'b1_111_110:begin preshift<=5'd28; pshiftd<=(squard << 28); end
		default: begin     preshift<=5'd0;  pshiftd<= squard; end
		endcase

		casez(pshiftd[32:27])
		6'b1?????:begin shft<={1'b0,preshift};shiftd<=pshiftd   ; end
		6'b01????:begin shft<=preshift+1; shiftd <= (pshiftd<<1); end
		6'b001???:begin shft<=preshift+2; shiftd <= (pshiftd<<2); end
		6'b0001??:begin shft<=preshift+3; shiftd <= (pshiftd<<3); end
		6'b00001?:begin shft<=preshift+4; shiftd <= (pshiftd<<4); end
		6'b000001:begin shft<=preshift+4; shiftd <= (pshiftd<<5); end
		6'b000000:begin shft<=preshift+5; shiftd <= (pshiftd<<6); end
		endcase

		if (shft >= 6'd32)
			pre_output <= 0;
		else if (shiftd[32])
			pre_output <= { ~shft[4:0], shiftd[31:29] };
		else
			pre_output <= 0;
	end

	always @(posedge i_clk)
	if (i_ce)
	begin
		o_sync <= pre_sync[3];
		o_sample <= pre_output;
	end

	// Make Verilator happy
	// verilator lint_off UNUSED
	wire	[28:0] unused;
	assign	unused = { shiftd[28:0] };
	// verilator lint_on  UNUSED
endmodule
