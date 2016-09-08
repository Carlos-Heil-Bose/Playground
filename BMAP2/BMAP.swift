////////////////////////////////////////////////////////////////////////////////
///  @file   BMAP.swift
///  @brief  Bose Mobile Application Protocol (BMAP) interface
///
///  @details
///          Creates representations of BMAP messages.
///
///  Copyright © 2016 Bose Corporation. All rights reserved.
///
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// BMAP enumerations

enum BMAPFunctionBlock : UInt8 {
    case productInfo  = 0,
    settings          = 1,
    status            = 2,
    firmwareUpdate    = 3,
    deviceManagement  = 4,
    audioManagement   = 5,
    callManagement    = 6,
    sessionManagement = 7,
    debug             = 8,
    unused            = 9,
    dsp               = 10,
    bosEbuild         = 11,
    hearingAssistance = 12,
    dataCollection    = 13
}

enum BMAPOperator : UInt8 {
    case op_Set   = 0,
    op_Get        = 1,
    op_SetGet     = 2,
    op_Status     = 3,
    op_Error      = 4,
    op_Start      = 5,
    op_Result     = 6,
    op_Processing = 7
}

enum BMAPFunction : UInt8 {
    // BOSEbuild Functions
    case bb_FBlockInfo        = 0,
    bb_GetAll                 = 1,
    bb_ConnectedAccessories   = 2,
    bb_LEDSupportedModes      = 3,
    bb_LEDMode                = 4,
    bb_LEDModeInfo            = 5,
    bb_LEDUserControlListSize = 6,
    bb_LEDUserControlInfo     = 7,
    bb_LEDUserControlValue    = 8,
    bb_Disconnecting          = 9,
    bb_SaveLEDSetting         = 10,
    bb_Analytics              = 11
}

enum BB_LEDModes : UInt8 {
    case ledMode_RGB      = 0,
    ledMode_Dancing  = 1,
    ledMode_Initial  = 2
}

////////////////////////////////////////////////////////////////////////////////
/// BMAP class
/// The BMAP class provides the following interface:
///
///     BMAP(FunctionBlock, Function, Operator)
///        Instantiates a BMAP object with the desired values for Function Block, 
///        Function and Operator but without a payload (i.e., Data Length = zero).
///
///     BMAP(FunctionBlock, Function, Operator, Data)
///        Instantiates a BMAP object with the desired values for Function Block,
///        Function and Operator with Data as the message payload
///
///      getSize()
///        Returns the size in bytes of the associated BMAP message
///
///      getBytes()
///        Returns a list containing the bytes that make up the associated 
///        BMAP message
///
////////////////////////////////////////////////////////////////////////////////
open class BMAP {

    // BMAP Header definition
    struct BMAPHeader {
        let Nothing       : UInt8 = 0x00
        var FunctionBlock : BMAPFunctionBlock
        var Function      : BMAPFunction
        var Operator      : BMAPOperator
        var DataLength    : UInt8
        init(FunctionBlock : BMAPFunctionBlock, Function : BMAPFunction, Operator : BMAPOperator, DataLength : UInt8) {
            self.FunctionBlock = FunctionBlock
            self.Function      = Function
            self.Operator      = Operator
            self.DataLength    = DataLength
        }
    }
    var Header : BMAPHeader!
    var Payload : [UInt8]

    // Initializers
    init(FunctionBlock : BMAPFunctionBlock, Function : BMAPFunction, Operator : BMAPOperator) {
        Header = BMAPHeader(FunctionBlock: FunctionBlock, Function: Function, Operator: Operator, DataLength: 0)
        Payload              = [0]
    }
    init(FunctionBlock : BMAPFunctionBlock, Function : BMAPFunction, Operator : BMAPOperator, Data : [UInt8]) {
        let DataLength = UInt8(Data.count)
        Header = BMAPHeader(FunctionBlock: FunctionBlock, Function: Function, Operator: Operator, DataLength: DataLength)
        Payload              = Data
    }

    // getSize - returns BMAP message length in bytes
    open func getSize() -> Int {
        return MemoryLayout<BMAPHeader>.size + Int(Header.DataLength)
    }

    // getBytes - returns a list containing the bytes that make up the BMAP message
    open func getBytes() -> [UInt8] {
        var MsgBytes : [UInt8]
        MsgBytes = [Header.Nothing, Header.FunctionBlock.rawValue, Header.Function.rawValue, Header.Operator.rawValue, Header.DataLength]
        if (Header.DataLength != 0) {
            for Byte in 0...Int(Header.DataLength-1) {
                MsgBytes.append(Payload[Byte])
            }
        }
        return MsgBytes
    }
}
