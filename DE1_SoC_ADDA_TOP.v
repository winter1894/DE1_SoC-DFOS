module DE1_SoC_ADDA_TOP    (

								KEY,			//*Added from DE1_SoC 
                        CLOCK_50,
                        ADC_CLK_A,
								ADC_CLK_B,
								ADC_DA,
								ADC_DB,
								ADC_OEB_A,
								ADC_OEB_B,
								ADC_OTR_A,
								ADC_OTR_B,
								DAC_CLK_A,
								DAC_CLK_B,
								DAC_DA,
								DAC_DB,
								DAC_MODE,
								DAC_WRT_A,
								DAC_WRT_B,
								OSC_SMA_ADC4,
								POWER_ON,
							   SMA_DAC4,
								
								//**********************************************************************************
								//MyMemory ***MEMORY IN USE***
								//wraddress_sig,
								//rdaddress_sig,
								//wren_sig,
								q_sig,
								data,
								
								//**********************************************************************************
								//FFT 
								//sink_valid, sink_sop, sink_eop, source_ready,
								sink_ready, source_error, source_sop, source_eop, source_valid, source_exp,
								source_error, source_exp,
								re, img
                        );
                        
input			[3:0]			KEY; //*Added from DE1_SoC                        
input		          		CLOCK_50;

output		          	ADC_CLK_A;
output		          	ADC_CLK_B;
input		    [13:0]		ADC_DA;
input		    [13:0]		ADC_DB;
output		          	ADC_OEB_A;
output		          	ADC_OEB_B;
input		          		ADC_OTR_A;		//Out of Range A
input		          		ADC_OTR_B;		//Out of Range B
output		          	DAC_CLK_A;
output		          	DAC_CLK_B;
output		 [13:0]		DAC_DA;
output		 [13:0]		DAC_DB;
output		          	DAC_MODE;
output		          	DAC_WRT_A;
output		          	DAC_WRT_B;
output		        		POWER_ON;

//Two below are external clock inputs
input                  OSC_SMA_ADC4;	//SMA A/D External Clock Input (J5) or 100MHz Oscillator Clock Input
input                  SMA_DAC4;		//SMA D/A External Clock Input (J5) 
//=======================================================
//  REG/WIRE declarations
//=======================================================
assign  DAC_WRT_B = CLK_125;      //Input write signal for PORT B
assign  DAC_WRT_A = CLK_125;      //Input write signal for PORT A

assign  DAC_MODE = 1; 		       //Mode Select. 1 = dual port, 0 = interleaved.

assign  DAC_CLK_B = CLK_125; 	    //PLL Clock to DAC_B
assign  DAC_CLK_A = CLK_125; 	    //PLL Clock to DAC_A
 
assign  ADC_CLK_B = CLK_65;  	    //PLL Clock to ADC_B
assign  ADC_CLK_A = CLK_65;  	    //PLL Clock to ADC_A


assign  ADC_OEB_A = 0; 		  	    //ADC_OEA Output Enable A
assign  ADC_OEB_B = 0; 			    //ADC_OEB Output Enable B

/////////////////////////////////////

wire    [13:0]	sin10_out;
wire    [13:0]	sin_out;

wire    [13:0]	comb;


wire    [31:0]	phasinc1;
wire    [31:0]	phasinc2;

wire    g = 0;
wire    v = 1;

assign  phasinc1 = {g,g,g,g,v,v,g,g,v,v,g,g,v,v,g,g,v,v,g,g,v,v,g,g,v,v,g,g,v,v,g,v};
assign  phasinc2 = {g,v,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g,g};

assign  DAC_DA = comb; //B
assign  DAC_DB = comb; //A

assign  POWER_ON  = 1;            



//=======================================================
//  Structural coding
//=======================================================

NCO sin1         (
						.phi_inc_i(phasinc1),
						.clk	    (CLK_125),
						.reset_n  (v),
						.clken	 (v),
						.fsin_o	 (sin_out),
						.fcos_o   (),
						.out_valid(ovalid)
		         );

NCO sin2         (
				      .phi_inc_i(phasinc2),
				      .clk	    (CLK_125),
				      .reset_n  (v),
					   .clken	 (v),
						.fsin_o	 (sin10_out),
						.fcos_o	 (),
						.out_valid(ovalid)
		          );


pll  pll_100    (
				     .inclk0(CLOCK_50),
                 .pllena(v),
                 .areset(g),
                 .c0    (CLK_125),
                 .c1	   (CLK_65)
			       );
		
lpm_add    lpm  (
                 .clock (CLK_125),
                 .dataa ({g,~sin_out[12],sin_out[11:0]}),
                 .datab ({g,~sin10_out[12],sin10_out[11:0]}),
                 .result(comb)
                );

//*********************************************************************
//*********************************************************************
//Code below added by Matthew Winter
//*********************************************************************
//*********************************************************************

reg sink_valid, sink_sop, sink_eop, source_ready;

output sink_ready, source_sop, source_eop, source_valid;
output [1:0] source_error;
output [5:0] source_exp;
output signed [13:0] re, img;

reg resetFFT;

		  
//FFT MODULE
FFT FFT_inst(
	.clk (CLK_65),
	.reset_n (KEY[0]), 
	.inverse (0),
	.sink_valid (sink_valid),
	.sink_sop (sink_sop),
	.sink_eop (sink_eop),
	.sink_real (FFTinput),	//FFT DATA INPUT
	//.sink_real (sin10_out),		//TEST INPUT
	.sink_imag ("0000000000000000"),
	.sink_error ("00"),
	.source_ready (source_ready),
	
	.sink_ready (sink_ready),
	.source_error (source_error),
	.source_sop (source_sop),
	.source_eop (source_eop),
	.source_valid (source_valid),
	.source_exp (source_exp),
	.source_real (re),
	.source_imag (img)
	);	

	
	
reg	[15:0]	wraddress_sig;
reg	[15:0]	rdaddress_sig;

reg	wren_sig;
output [15:0]	q_sig;
input [15:0]	data;
	
//MEMORY MODULE
TwoPortRAM	TwoPortRAM_inst (
	//.data ( {"00",sin_out} ),			//16 bit data input test
	.data ({"00",ADC_DA}),			//16 bit data input
	.rdaddress ( rdaddress_sig ),		//read address
	.rdclock ( CLK_65 ),					//input rd clock 65MHz
	.wraddress ( wraddress_sig ),		//write address
	.wrclock ( CLK_65 ),					//input wr clock 65MHz for now, may use external clock in future
	.wren ( wren_sig ),					//write enable
	.q ( q_sig )							//16 bit data output
	);
	
	reg [15:0] counter;				//keep track of traversing both read and write processes
	reg [15:0] readCounter;			//to track reading data address
	reg [15:0] writeCounter;			//to track written data address
	
	reg [13:0] FFTinput;			//input data for FFT
	

	parameter ZERO=0, ONE=1, TWO=2, THREE=3, FOUR=4, FIVE=5, SIX=6, SEVEN=7;
	reg [2:0] state;
	
	reg [1:0] triggered;		//keeps in memory whether trigger signal has gone through or not
	reg signalTapTrigger /*synthesis noprune*/; //prior comment notation prevents synthesizer optimizing this trigger away
	reg clk_half/*synthesis noprune*/; 	//65MHz clock/2
	
	
	reg signed [32:0] magnitudeFFTNoSqRt /*synthesis noprune*/;		//magnitude of real and imaginary output of FFT
	//wire [27:0] magnitudeFFTNoSqRtWire /*synthesis noprune*/;
	
	/*MultAdd MultAdd_inst(
	.result (magnitudeFFTNoSqRt),
	.dataa_0 (re),
	.dataa_1 (img),
	.datab_0 (re),
	.datab_1 (img)
	);*/
	
	reg risingEdgeClock /*synthesis noprune*/; //detects if a rising edge has already occurred and waits for signal to go low again
	//before collecting more data.
		
	always @ (posedge CLK_65) begin: MEM_WRITE
	
	//magnitudeFFTNoSqRtWire=magnitudeFFTNoSqRt;
	magnitudeFFTNoSqRt=((re*re)+(img*img));
	
	clk_half <= ! clk_half;			//65MHz clock/2
			
			//TRIGGER
			//************************************************
			if (SMA_DAC4>0) begin
				//set trigger to 1 for a cycle
				if (triggered==0) begin
					triggered=1;		//initially triggered=1
				end
				//if trigger has already been activated, set to 2.
				//This allows us to ignore the trigger after it's use and keep going though state machine
				else begin
					triggered=2;	
				end
			end
			//When trigger goes low, set triggered to 0
			else begin 
				triggered=0;
			end
			//************************************************

			//RESET
			if (!KEY[0] || triggered==1) begin
			
				wren_sig = 0;			//write enable off
				sink_sop = 0;			//not start of packet
				sink_eop = 0;			//not end of packet
				sink_valid = 0;		//data not valid
				source_ready = 1;		//Source ready	
				
				counter=0;	
				writeCounter=0;	
				readCounter=0;	
				state=0;
				
				signalTapTrigger=0;
				risingEdgeClock=0;
			end
				
			//STATE MACHINE
			else begin
				case (state)
				
					//empty case
					ZERO: begin		//1	
						state=1;
					end
					
					//WRITE
					ONE: begin		//2
						
						sink_sop=0;			//not start of packet
						sink_eop=0;			//not end of packet
						sink_valid=0;		//data not valid
						source_ready=0;	//source not ready
					
						readCounter=0;		//assure readCounter is set to 0
						
						//***Writing data to memory***
						if (risingEdgeClock==1) begin
							//do nothing
							wren_sig=0; //write enable OFF
							if (OSC_SMA_ADC4 < 0 || OSC_SMA_ADC4 == 0) begin
								risingEdgeClock=0;
							end
						end
						
						else if (OSC_SMA_ADC4 > 0) begin	//if external clock is high, recording is okay
							risingEdgeClock=1;
						
							wren_sig=1;			//write enable ON
							wraddress_sig=(writeCounter);		//keep updating address location
							writeCounter=writeCounter+1;		//update write counter
							counter=counter+1;					//update general counter
							//16k points
							//if (counter>16383) begin
							if (counter>8191) begin
								state=2;
								wren_sig = 0;			//write enable off
							end
						end
					end
									
					//START READ
					//***Send to FFT IP core using Avalon bus protocol***
					TWO: begin		//4
						sink_sop=0;			//not start of packet
						sink_eop=0;			//not end of packet
						sink_valid=0;		//data not valid
						source_ready=0;	//source not ready
						
						if(sink_ready==1) begin	
							state=3;
						end
					
					end
					
					//Stream input to FFT
					THREE: begin		//8
					
						readCounter=0;
						
						//read memory address 0
						rdaddress_sig=(readCounter);
						
						FFTinput=q_sig[13:0];
						
						sink_sop=1;			//start of packet
						sink_eop=0;			//not end of packet
						sink_valid=1;		//data valid
						
						state=4;
					end
					
					//stream middle and end packets				
					FOUR: begin	//16
						
						FFTinput=q_sig[13:0];
						
						//Traverse memory
						rdaddress_sig=(readCounter);
						readCounter=readCounter+1;		//update read counter
						counter=counter+1;				//update general counter
						
						//End of packet
						//16k points
						//if (readCounter==16383) begin
						if (readCounter==8191) begin
							sink_sop=0;			//start of packet
							sink_eop=1;			//not end of packet
							sink_valid=1;		//data valid
							state=5;
						end

						//else stream all middle packets
						else begin
							sink_sop=0;			//start of packet
							sink_eop=0;			//not end of packet
							sink_valid=1;		//data valid
							
						end
					
					end
					
					//Sending data done, reset values
					FIVE: begin		//32
						sink_sop=0;
						sink_eop=0;
						sink_valid=0;
						source_ready=1;

						//reset write address
						writeCounter=0;
						wraddress_sig=(writeCounter);
						
						//reset read address
						readCounter=0;
						rdaddress_sig=(readCounter);
						
						counter=1;
					
						//Go to next state when source start of packet comes through
						if (source_sop==1) begin
							state=6;
							
						end
					end

					//SignalTapTrigger stage
					SIX: begin		//64
					
						signalTapTrigger=1;
					
						/*counter=counter+1;
						*/
						
						//SignalTapTrigger counter (Rising and falling edges count as 2 steps in SignalTap)
						//Since SignalTap records to -2048, counter is nearly double that value to compensate
						//if (counter==4093) begin		//4093 catches first packet of FFT
						/*if (counter==1) begin
							state=7;
							signalTapTrigger=1;
						end
						*/
					end

					//Idle Stage
					SEVEN: begin		//128
						state=7;
					end

				endcase
			end
	end

endmodule 