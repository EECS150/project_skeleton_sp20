// Source: https://www.ibm.com/support/knowledgecenter/P8DEA/p8egb/p8egb_supportedresolution.htm
module display_controller #(

    // Video resolution parameters for 800x600 @60Hz -- pixel_freq = 40 MHz
    parameter H_ACTIVE_VIDEO = 800,
    parameter H_FRONT_PORCH  = 40,
    parameter H_SYNC_WIDTH   = 128,
    parameter H_BACK_PORCH   = 88,

    parameter V_ACTIVE_VIDEO = 600,
    parameter V_FRONT_PORCH  = 1,
    parameter V_SYNC_WIDTH   = 4,
    parameter V_BACK_PORCH   = 23

//    // Video resolution parameters for 1024x768 @60Hz -- pixel_freq = 65 MHz
//    parameter H_ACTIVE_VIDEO = 1024,
//    parameter H_FRONT_PORCH  = 24,
//    parameter H_SYNC_WIDTH   = 136,
//    parameter H_BACK_PORCH   = 160,
//
//    parameter V_ACTIVE_VIDEO = 768,
//    parameter V_FRONT_PORCH  = 3,
//    parameter V_SYNC_WIDTH   = 6,
//    parameter V_BACK_PORCH   = 29


//    // Video resolution parameters for 1280x720 @60Hz -- pixel_freq = 74.25 MHz
//    parameter H_ACTIVE_VIDEO = 1280,
//    parameter H_FRONT_PORCH  = 110,
//    parameter H_SYNC_WIDTH   = 40,
//    parameter H_BACK_PORCH   = 220,
//
//    parameter V_ACTIVE_VIDEO = 720,
//    parameter V_FRONT_PORCH  = 5,
//    parameter V_SYNC_WIDTH   = 5,
//    parameter V_BACK_PORCH   = 20
) (
    input pixel_clk,

    input [23:0] pixel_stream_din_data,
    input pixel_stream_din_valid,
    output pixel_stream_din_ready,

    // video signals
    output [23:0] video_out_pData,
    output video_out_pHSync,
    output video_out_pVSync,
    output video_out_pVDE
);

    // TODO: Your code

endmodule
