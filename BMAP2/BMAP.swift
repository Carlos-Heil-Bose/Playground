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
    case ProductInfo  = 0,
    Settings          = 1,
    Status            = 2,
    FirmwareUpdate    = 3,
    DeviceManagement  = 4,
    AudioManagement   = 5,
    CallManagement    = 6,
    SessionManagement = 7,
    Debug             = 8,
    Unused            = 9,
    DSP               = 10,
    BOSEbuild         = 11,
    HearingAssistance = 12,
    DataCollection    = 13
}

enum BMAPOperator : UInt8 {
    case Op_Set   = 0,
    Op_Get        = 1,
    Op_SetGet     = 2,
    Op_Status     = 3,
    Op_Error      = 4,
    Op_Start      = 5,
    Op_Result     = 6,
    Op_Processing = 7
}

enum BMAPFunction : UInt8 {
    // BOSEbuild Functions
    case BB_FBlockInfo        = 0,
    BB_GetAll                 = 1,
    BB_ConnectedAccessories   = 2,
    BB_LEDSupportedModes      = 3,
    BB_LEDMode                = 4,
    BB_LEDModeInfo            = 5,
    BB_LEDUserControlListSize = 6,
    BB_LEDUserControlInfo     = 7,
    BB_LEDUserControlValue    = 8,
    BB_Disconnecting          = 9,
    BB_SaveLEDSetting         = 10,
    BB_Analytics              = 11
}

enum BB_LEDModes : UInt8 {
    case LEDMode_RGB      = 0,
    LEDMode_Dancing  = 1,
    LEDMode_Initial  = 2
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
public class BMAP {

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
    public func getSize() -> Int {
        return sizeof(BMAPHeader) + Int(Header.DataLength)
    }

    // getBytes - returns a list containing the bytes that make up the BMAP message
    public func getBytes() -> [UInt8] {
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
