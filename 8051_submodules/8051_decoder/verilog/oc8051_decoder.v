// synopsys translate_off
`include "oc8051_timescale.v"
// synopsys translate_on

`include "oc8051_defines.v"


module oc8051_decoder (clk, rst, 
  irom_out_of_rst, new_valid_pc,
  op_cur,
  op_in, op1_c,
  ram_rd_sel_o, ram_wr_sel_o,
  bit_addr, wr_o, wr_sfr_o,
  src_sel1, src_sel2, src_sel3,
  alu_op_o, psw_set, eq, cy_sel, comp_sel,
  pc_wr, pc_sel, rd, rmw, istb, mem_act, mem_wait,
  wait_data, state);

//
// clk          (in)  clock
// rst          (in)  reset
// irom_out_of_rst 
//              (in) has the IROM started producing useful instructions? 
//                   this goes high some number of cycles after reset and stays high forever.
// op_in        (in)  operation code [oc8051_op_select.op1]
// eq           (in)  compare result [oc8051_comp.eq]
// ram_rd_sel   (out) select, whitch address will be send to ram for read [oc8051_ram_rd_sel.sel, oc8051_sp.ram_rd_sel]
// ram_wr_sel   (out) select, whitch address will be send to ram for write [oc8051_ram_wr_sel.sel -r, oc8051_sp.ram_wr_sel -r]
// wr           (out) write - if 1 then we will write to ram [oc8051_ram_top.wr -r, oc8051_acc.wr -r, oc8051_b_register.wr -r, oc8051_sp.wr-r, oc8051_dptr.wr -r, oc8051_psw.wr -r, oc8051_indi_addr.wr -r, oc8051_ports.wr -r]
// src_sel1     (out) select alu source 1 [oc8051_alu_src1_sel.sel -r]
// src_sel2     (out) select alu source 2 [oc8051_alu_src2_sel.sel -r]
// src_sel3     (out) select alu source 3 [oc8051_alu_src3_sel.sel -r]
// alu_op       (out) alu operation [oc8051_alu.op_code -r]
// psw_set      (out) will we remember cy, ac, ov from alu [oc8051_psw.set -r]
// cy_sel       (out) carry in alu select [oc8051_cy_select.cy_sel -r]
// comp_sel     (out) compare source select [oc8051_comp.sel]
// bit_addr     (out) if instruction is bit addresable [oc8051_ram_top.bit_addr -r, oc8051_acc.wr_bit -r, oc8051_b_register.wr_bit-r, oc8051_sp.wr_bit -r, oc8051_dptr.wr_bit -r, oc8051_psw.wr_bit -r, oc8051_indi_addr.wr_bit -r, oc8051_ports.wr_bit -r]
// pc_wr        (out) pc write [oc8051_pc.wr]
// pc_sel       (out) pc select [oc8051_pc.pc_wr_sel]
// rd           (out) read from rom [oc8051_pc.rd, oc8051_op_select.rd]
// reti         (out) return from interrupt [pin]
// rmw          (out) read modify write feature [oc8051_ports.rmw]
// pc_wait      (out)
//

input clk, rst, eq, mem_wait, wait_data;
input [7:0] op_in;

input irom_out_of_rst;
output new_valid_pc;
output [7:0] op_cur;
output [1:0] state;


output wr_o, bit_addr, pc_wr, rmw, istb, src_sel3;
output [1:0] psw_set, cy_sel, wr_sfr_o, src_sel2, comp_sel;
output [2:0] mem_act, src_sel1, ram_rd_sel_o, ram_wr_sel_o, pc_sel, op1_c;
output [3:0] alu_op_o;
output rd;
reg first_time;

reg rmw;
reg src_sel3, wr,  bit_addr, pc_wr;
reg [3:0] alu_op;
reg [1:0] src_sel2, comp_sel, psw_set, cy_sel, wr_sfr;
reg [2:0] mem_act, src_sel1, ram_wr_sel, ram_rd_sel, pc_sel;

//
// state        if 2'b00 then normal execution, sle instructin that need more than one clock
// op           instruction buffer
reg  [1:0] state;
wire [1:0] state_dec;
reg  [7:0] op;
wire [7:0] op_cur;
reg  [2:0] ram_rd_sel_r;

reg stb_i;

assign rd = !state[0] && !state[1] && !wait_data;// && !stb_o;

assign istb = (!state[1]) && stb_i;

assign state_dec = wait_data ? 2'b00 : state;

assign op_cur = mem_wait ? 8'h00
                : (state[0] || state[1] || mem_wait || wait_data) ? op : op_in;
//assign op_cur = (state[0] || state[1] || mem_wait || wait_data) ? op : op_in;

wire new_valid_pc = (!mem_wait && !(state[0] || state[1] || mem_wait || wait_data)) && irom_out_of_rst;

assign op1_c = op_cur[2:0];

assign alu_op_o     = wait_data ? `OC8051_ALU_NOP : alu_op;
assign wr_sfr_o     = wait_data ? `OC8051_WRS_N   : wr_sfr;
assign ram_rd_sel_o = wait_data ? ram_rd_sel_r    : ram_rd_sel;
assign ram_wr_sel_o = wait_data ? `OC8051_RWS_DC  : ram_wr_sel;
assign wr_o         = wait_data ? 1'b0            : wr;

//
// main block
// unregisterd outputs
always @(op_cur or eq or state_dec or mem_wait)
begin
    case (state_dec) 
      2'b01: begin
        casex (op_cur) 
          `OC8051_DIV : begin
              ram_rd_sel = `OC8051_RRS_B;
            end
          `OC8051_MUL : begin
              ram_rd_sel = `OC8051_RRS_B;
            end
          default begin
              ram_rd_sel = `OC8051_RRS_DC;
          end
        endcase
        stb_i = 1'b1;
        bit_addr = 1'b0;
        pc_wr = `OC8051_PCW_N;
        pc_sel = `OC8051_PIS_DC;
        comp_sel =  `OC8051_CSS_DC;
        rmw = `OC8051_RMW_N;
      end
      2'b10: begin
        casex (op_cur) 
          `OC8051_SJMP : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_DC;
              bit_addr = 1'b0;
            end
          `OC8051_JC : begin
              ram_rd_sel = `OC8051_RRS_PSW;
              pc_wr = eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_CY;
              bit_addr = 1'b0;
            end
          `OC8051_JNC : begin
              ram_rd_sel = `OC8051_RRS_PSW;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_CY;
              bit_addr = 1'b0;
            end
          `OC8051_JNZ : begin
              ram_rd_sel = `OC8051_RRS_ACC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_AZ;
              bit_addr = 1'b0;
            end
          `OC8051_JZ : begin
              ram_rd_sel = `OC8051_RRS_ACC;
              pc_wr = eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_AZ;
              bit_addr = 1'b0;
            end

          `OC8051_RET : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_AL;
              comp_sel =  `OC8051_CSS_DC;
              bit_addr = 1'b0;
            end
          `OC8051_RETI : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_AL;
              comp_sel =  `OC8051_CSS_DC;
              bit_addr = 1'b0;
            end
          `OC8051_CJNE_R : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_DES;
              bit_addr = 1'b0;
            end
          `OC8051_CJNE_I : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_DES;
              bit_addr = 1'b0;
            end
          `OC8051_CJNE_D : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_DES;
              bit_addr = 1'b0;
            end
          `OC8051_CJNE_C : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_DES;
              bit_addr = 1'b0;
            end
          `OC8051_DJNZ_R : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_DES;
              bit_addr = 1'b0;
            end
          `OC8051_DJNZ_D : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_DES;
              bit_addr = 1'b0;
            end
          `OC8051_JB : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_BIT;
              bit_addr = 1'b0;
            end
          `OC8051_JBC : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_BIT;
              bit_addr = 1'b1;
            end
          `OC8051_JMP_D : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_ALU;
              comp_sel =  `OC8051_CSS_DC;
              bit_addr = 1'b0;
            end
          `OC8051_JNB : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_BIT;
              bit_addr = 1'b1;
            end
          `OC8051_DIV : begin
              ram_rd_sel = `OC8051_RRS_B;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              bit_addr = 1'b0;
            end
          `OC8051_MUL : begin
              ram_rd_sel = `OC8051_RRS_B;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              bit_addr = 1'b0;
            end
          default begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              bit_addr = 1'b0;
          end
        endcase
        rmw = `OC8051_RMW_N;
        stb_i = 1'b1;
      end
      2'b11: begin
        casex (op_cur) 
          `OC8051_CJNE_R : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
          `OC8051_CJNE_I : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
          `OC8051_CJNE_D : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
          `OC8051_CJNE_C : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
          `OC8051_DJNZ_R : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
          `OC8051_DJNZ_D : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
          `OC8051_RET : begin
              ram_rd_sel = `OC8051_RRS_SP;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_AH;
            end
          `OC8051_RETI : begin
              ram_rd_sel = `OC8051_RRS_SP;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_AH;
            end
          `OC8051_DIV : begin
              ram_rd_sel = `OC8051_RRS_B;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
          `OC8051_MUL : begin
              ram_rd_sel = `OC8051_RRS_B;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
            end
         default begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
          end
        endcase
        comp_sel =  `OC8051_CSS_DC;
        rmw = `OC8051_RMW_N;
        stb_i = 1'b1;
        bit_addr = 1'b0;
      end
      2'b00: begin
        casex (op_cur) 
          `OC8051_ACALL :begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_I11;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_AJMP : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_I11;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_ADD_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ADDC_R : begin
             ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ANL_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_CJNE_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_DEC_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_DJNZ_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_INC_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_DR : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_RD : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ORL_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_SUBB_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XCH_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XRL_R : begin
              ram_rd_sel = `OC8051_RRS_RN;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
    
    //op_code [7:1]
          `OC8051_ADD_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ADDC_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ANL_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_CJNE_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_DEC_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_INC_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_ID : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_DI : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOVX_IA : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_MOVX_AI :begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_ORL_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_SUBB_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XCH_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XCHD :begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XRL_I : begin
              ram_rd_sel = `OC8051_RRS_I;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
    
    //op_code [7:0]
          `OC8051_ADD_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ADDC_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ANL_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ANL_C : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ANL_DD : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ANL_DC : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ANL_B : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_ANL_NB : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_CJNE_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_CJNE_C : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_CLR_B : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_CPL_B : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_DEC_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_DIV : begin
              ram_rd_sel = `OC8051_RRS_B;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_DJNZ_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_INC_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_INC_DP : begin
              ram_rd_sel = `OC8051_RRS_DPTR;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_JB : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_BIT;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b1;
            end
          `OC8051_JBC : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_BIT;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b1;
            end
/*          `OC8051_JC : begin
              ram_rd_sel = `OC8051_RRS_PSW;
              pc_wr = eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_CY;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end*/
          `OC8051_JMP_D : begin
              ram_rd_sel = `OC8051_RRS_DPTR;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
    
          `OC8051_JNB : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_SO2;
              comp_sel =  `OC8051_CSS_BIT;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b1;
            end
/*          `OC8051_JNC : begin
              ram_rd_sel = `OC8051_RRS_PSW;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_CY;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_JNZ : begin
              ram_rd_sel = `OC8051_RRS_ACC;
              pc_wr = !eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_AZ;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_JZ : begin
              ram_rd_sel = `OC8051_RRS_ACC;
              pc_wr = eq;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_AZ;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end*/
          `OC8051_LCALL :begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_I16;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_LJMP : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_I16;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_DD : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_MOV_BC : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_MOV_CB : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_MOVC_DP :begin
              ram_rd_sel = `OC8051_RRS_DPTR;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_MOVC_PC : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_MOVX_PA : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_MOVX_AP : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_MUL : begin
              ram_rd_sel = `OC8051_RRS_B;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_ORL_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ORL_AD : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ORL_CD : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_ORL_B : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_ORL_NB : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
          `OC8051_POP : begin
              ram_rd_sel = `OC8051_RRS_SP;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_PUSH : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_RET : begin
              ram_rd_sel = `OC8051_RRS_SP;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_RETI : begin
              ram_rd_sel = `OC8051_RRS_SP;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end
          `OC8051_SETB_B : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b1;
            end
/*          `OC8051_SJMP : begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_Y;
              pc_sel = `OC8051_PIS_SO1;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b0;
              bit_addr = 1'b0;
            end*/
          `OC8051_SUBB_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XCH_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XRL_D : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XRL_AD : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          `OC8051_XRL_CD : begin
              ram_rd_sel = `OC8051_RRS_D;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_Y;
              stb_i = 1'b1;
              bit_addr = 1'b0;
            end
          default: begin
              ram_rd_sel = `OC8051_RRS_DC;
              pc_wr = `OC8051_PCW_N;
              pc_sel = `OC8051_PIS_DC;
              comp_sel =  `OC8051_CSS_DC;
              rmw = `OC8051_RMW_N;
              stb_i = 1'b1;
              bit_addr = 1'b0;
           end
        endcase
      end
    endcase
end










//
//
// registerd outputs

always @(posedge clk) begin
  if (rst) begin first_time <= 0; end
  else if (!wait_data && !mem_wait) first_time <= 1;
end
always @(posedge clk) //or posedge rst)
begin
  if (rst) begin
    ram_wr_sel <= #1 `OC8051_RWS_DC;
    src_sel1 <= #1 `OC8051_AS1_DC;
    src_sel2 <= #1 `OC8051_AS2_DC;
    alu_op <= #1 `OC8051_ALU_NOP;
    wr <= #1 1'b0;
    psw_set <= #1 `OC8051_PS_NOT;
    cy_sel <= #1 `OC8051_CY_0;
    src_sel3 <= #1 `OC8051_AS3_DC;
    wr_sfr <= #1 `OC8051_WRS_N;
  end else if (!wait_data) begin
    case (state_dec) 
      2'b01: begin
        casex (op_cur) 
          `OC8051_MOVC_DP :begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP1;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_MOVC_PC :begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP1;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_MOVX_PA : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP1;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_MOVX_IA : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP1;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_DIV : begin
              ram_wr_sel <= #1 `OC8051_RWS_B;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_DIV;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_OV;
              wr_sfr <= #1 `OC8051_WRS_ACC2;
            end
          `OC8051_MUL : begin
              ram_wr_sel <= #1 `OC8051_RWS_B;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_MUL;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_OV;
              wr_sfr <= #1 `OC8051_WRS_ACC2;
            end
          default begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              wr_sfr <= #1 `OC8051_WRS_N;
          end
        endcase
        cy_sel <= #1 `OC8051_CY_0;
        src_sel3 <= #1 `OC8051_AS3_DC;
      end
      2'b10: begin
        casex (op_cur) 
          `OC8051_ACALL :begin
              ram_wr_sel <= #1 `OC8051_RWS_SP;
              src_sel1 <= #1 `OC8051_AS1_PCH;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
            end
          `OC8051_LCALL :begin
              ram_wr_sel <= #1 `OC8051_RWS_SP;
              src_sel1 <= #1 `OC8051_AS1_PCH;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
            end
          `OC8051_JBC : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
            end
          `OC8051_DIV : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_DIV;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_OV;
            end
          `OC8051_MUL : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_MUL;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_OV;
            end
          default begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
          end
        endcase
        cy_sel <= #1 `OC8051_CY_0;
        src_sel3 <= #1 `OC8051_AS3_DC;
        wr_sfr <= #1 `OC8051_WRS_N;
      end

      2'b11: begin
        casex (op_cur) 
          `OC8051_RET : begin
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              psw_set <= #1 `OC8051_PS_NOT;
            end
          `OC8051_RETI : begin
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              psw_set <= #1 `OC8051_PS_NOT;
            end
          `OC8051_DIV : begin
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_DIV;
              psw_set <= #1 `OC8051_PS_OV;
            end
          `OC8051_MUL : begin
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_MUL;
              psw_set <= #1 `OC8051_PS_OV;
            end
         default begin
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              psw_set <= #1 `OC8051_PS_NOT;
          end
        endcase
        ram_wr_sel <= #1 `OC8051_RWS_DC;
        wr <= #1 1'b0;
        cy_sel <= #1 `OC8051_CY_0;
        src_sel3 <= #1 `OC8051_AS3_DC;
        wr_sfr <= #1 `OC8051_WRS_N;
      end
      default: begin
        casex (op_cur) 
          `OC8051_ACALL :begin
              ram_wr_sel <= #1 `OC8051_RWS_SP;
              src_sel1 <= #1 `OC8051_AS1_PCL;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_AJMP : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ADD_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ADDC_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ANL_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_AND;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_CJNE_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_OP2;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_DEC_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_RN;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_DJNZ_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_RN;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_INC_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_RN;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_MOV_AR : begin
              ram_wr_sel <= #1 `OC8051_RWS_RN;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_DR : begin
              ram_wr_sel <= #1 `OC8051_RWS_RN;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_CR : begin
              ram_wr_sel <= #1 `OC8051_RWS_RN;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_RD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ORL_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_OR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_SUBB_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_XCH_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_RN;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XCH;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC2;
            end
          `OC8051_XRL_R : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XOR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
    
    //op_code [7:1]
          `OC8051_ADD_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ADDC_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ANL_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_AND;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_CJNE_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_OP2;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_DEC_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_I;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_INC_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_I;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_MOV_ID : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_AI : begin
              ram_wr_sel <= #1 `OC8051_RWS_I;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_DI : begin
              ram_wr_sel <= #1 `OC8051_RWS_I;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_CI : begin
              ram_wr_sel <= #1 `OC8051_RWS_I;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOVX_IA : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOVX_AI :begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ORL_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_OR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_SUBB_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_XCH_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_I;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XCH;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC2;
            end
          `OC8051_XCHD :begin
              ram_wr_sel <= #1 `OC8051_RWS_I;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XCH;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC2;
            end
          `OC8051_XRL_I : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XOR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
    
    //op_code [7:0]
          `OC8051_ADD_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ADD_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ADDC_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ADDC_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ANL_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_AND;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ANL_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_AND;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ANL_DD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_AND;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ANL_DC : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_OP3;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_AND;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ANL_B : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_AND;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ANL_NB : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_RR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_CJNE_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_CJNE_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_OP2;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_CLR_A : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_CLR_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_CLR_B : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_CPL_A : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOT;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_CPL_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOT;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_CPL_B : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOT;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_RAM;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_DA : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_DA;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_DEC_A : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_DEC_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_DIV : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_DIV;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_OV;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_DJNZ_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_INC_A : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_INC_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_INC;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_INC_DP : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ZERO;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DP;
              wr_sfr <= #1 `OC8051_WRS_DPTR;
            end
          `OC8051_JB : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_JBC :begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_JC : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_JMP_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DP;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_JNB : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_JNC : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_JNZ :begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_JZ : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_LCALL :begin
              ram_wr_sel <= #1 `OC8051_RWS_SP;
              src_sel1 <= #1 `OC8051_AS1_PCL;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_LJMP : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_MOV_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_MOV_DA : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_DD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D3;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_CD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_OP3;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_BC : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_RAM;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_CB : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOV_DP : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP3;
              src_sel2 <= #1 `OC8051_AS2_OP2;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_DPTR;
            end
          `OC8051_MOVC_DP :begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DP;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOVC_PC : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_PCL;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_ADD;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOVX_PA : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MOVX_AP : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_MUL : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_MUL;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_OV;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ORL_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_OR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ORL_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_OR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_ORL_AD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_OR;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ORL_CD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_OP3;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_OR;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ORL_B : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_OR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_ORL_NB : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_RL;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_POP : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_PUSH : begin
              ram_wr_sel <= #1 `OC8051_RWS_SP;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_RET : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_RETI : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_RL : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_RL;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_RLC : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_RLC;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_RR : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_RR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_RRC : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_RRC;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_SETB_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_CY;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_SETB_B : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_SJMP : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_PC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_SUBB_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_SUBB_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_OP2;
              alu_op <= #1 `OC8051_ALU_SUB;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_AC;
              cy_sel <= #1 `OC8051_CY_PSW;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_SWAP : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_ACC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_RLC;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC2;
            end
          `OC8051_XCH_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XCH;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_1;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC2;
            end
          `OC8051_XRL_D : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XOR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_XRL_C : begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_OP2;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XOR;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_ACC1;
            end
          `OC8051_XRL_AD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_RAM;
              src_sel2 <= #1 `OC8051_AS2_ACC;
              alu_op <= #1 `OC8051_ALU_XOR;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          `OC8051_XRL_CD : begin
              ram_wr_sel <= #1 `OC8051_RWS_D;
              src_sel1 <= #1 `OC8051_AS1_OP3;
              src_sel2 <= #1 `OC8051_AS2_RAM;
              alu_op <= #1 `OC8051_ALU_XOR;
              wr <= #1 1'b1;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
            end
          default: begin
              ram_wr_sel <= #1 `OC8051_RWS_DC;
              src_sel1 <= #1 `OC8051_AS1_DC;
              src_sel2 <= #1 `OC8051_AS2_DC;
              alu_op <= #1 `OC8051_ALU_NOP;
              wr <= #1 1'b0;
              psw_set <= #1 `OC8051_PS_NOT;
              cy_sel <= #1 `OC8051_CY_0;
              src_sel3 <= #1 `OC8051_AS3_DC;
              wr_sfr <= #1 `OC8051_WRS_N;
           end
        endcase
      end
      endcase
  end
end


//
// remember current instruction
always @(posedge clk)// or posedge rst)
  if (rst) op <= #1 2'b00;
  else if (state==2'b00) op <= #1 op_in;

//
// in case of instructions that needs more than one clock set state
always @(posedge clk)// or posedge rst)
begin
  if (rst)
    state <= #1 2'b11;
  else if  (!mem_wait & !wait_data) begin
    case (state) 
      2'b10: state <= #1 2'b01;
      2'b11: state <= #1 2'b10;
      2'b00:
          casex (op_in) 
            `OC8051_ACALL   : state <= #1 2'b10;
            `OC8051_AJMP    : state <= #1 2'b10;
            `OC8051_CJNE_R  : state <= #1 2'b10;
            `OC8051_CJNE_I  : state <= #1 2'b10;
            `OC8051_CJNE_D  : state <= #1 2'b10;
            `OC8051_CJNE_C  : state <= #1 2'b10;
            `OC8051_LJMP    : state <= #1 2'b10;
            `OC8051_DJNZ_R  : state <= #1 2'b10;
            `OC8051_DJNZ_D  : state <= #1 2'b10;
            `OC8051_LCALL   : state <= #1 2'b10;
            `OC8051_MOVC_DP : state <= #1 2'b11;
            `OC8051_MOVC_PC : state <= #1 2'b11;
            `OC8051_MOVX_IA : state <= #1 2'b10;
            `OC8051_MOVX_AI : state <= #1 2'b10;
            `OC8051_MOVX_PA : state <= #1 2'b10;
            `OC8051_MOVX_AP : state <= #1 2'b10;
            `OC8051_RET     : state <= #1 2'b11;
            `OC8051_RETI    : state <= #1 2'b11;
            `OC8051_SJMP    : state <= #1 2'b10;
            `OC8051_JB      : state <= #1 2'b10;
            `OC8051_JBC     : state <= #1 2'b10;
            `OC8051_JC      : state <= #1 2'b10;
            `OC8051_JMP_D   : state <= #1 2'b10;
            `OC8051_JNC     : state <= #1 2'b10;
            `OC8051_JNB     : state <= #1 2'b10;
            `OC8051_JNZ     : state <= #1 2'b10;
            `OC8051_JZ      : state <= #1 2'b10;
            `OC8051_DIV     : state <= #1 2'b11;
            `OC8051_MUL     : state <= #1 2'b11;
//            default         : state <= #1 2'b00;
          endcase
      default: state <= #1 2'b00;
    endcase
  end
end


//
//in case of writing to external ram
always @(posedge clk)// or posedge rst)
begin
  if (rst) begin
    mem_act <= #1 `OC8051_MAS_NO;
  end else if (!rd) begin
    mem_act <= #1 `OC8051_MAS_NO;
  end else
    casex (op_cur) 
      `OC8051_MOVX_AI : mem_act <= #1 `OC8051_MAS_RI_W;
      `OC8051_MOVX_AP : mem_act <= #1 `OC8051_MAS_DPTR_W;
      `OC8051_MOVX_IA : mem_act <= #1 `OC8051_MAS_RI_R;
      `OC8051_MOVX_PA : mem_act <= #1 `OC8051_MAS_DPTR_R;
      `OC8051_MOVC_DP : mem_act <= #1 `OC8051_MAS_CODE;
      `OC8051_MOVC_PC : mem_act <= #1 `OC8051_MAS_CODE;
      default : mem_act <= #1 `OC8051_MAS_NO;
    endcase
end

always @(posedge clk)// or posedge rst)
begin
  if (rst) begin
    ram_rd_sel_r <= #1 3'h0;
  end else begin
    ram_rd_sel_r <= #1 ram_rd_sel;
  end
end



`ifdef OC8051_SIMULATION

always @(op_cur)
  if (op_cur===8'hxx) begin
    $display("time ",$time, "   failure: invalid instruction (oc8051_decoder)");
end


`endif




endmodule


