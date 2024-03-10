MODULE_NAME='mPanasonicCamera'  (
                                    dev vdvObject,
                                    dev dvPort
                                )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
#DEFINE USING_NAV_STRING_GATHER_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'
#include 'NAVFoundation.ArrayUtils.axi'
#include 'NAVFoundation.StringUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant integer IP_PORT    = 80

constant integer PTZ_STOP = 50

constant integer AUTO_FOCUS_STATUS_UNKNOWN  = 0
constant integer AUTO_FOCUS_STATUS_ON       = 1
constant integer AUTO_FOCUS_STATUS_OFF      = 2

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile char basicAuthB64[255]

volatile char payload[NAV_MAX_BUFFER]

volatile integer tiltSpeed     = 20
volatile integer panSpeed      = 20
volatile integer zoomSpeed     = 10
volatile integer focusSpeed    = 10

volatile integer autoFocus = AUTO_FOCUS_STATUS_UNKNOWN

volatile integer getAutoFocus = false


(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function Send(char payload[]) {
    if (!length_array(payload)) {
        return
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO,
                                            dvPort,
                                            payload))

    send_string dvPort, "payload"
}


define_function BuildPayload(char cmd[]) {
    stack_var char result[NAV_MAX_BUFFER]

    if (!length_array(module.Device.SocketConnection.Address) || module.Device.SocketConnection.IsConnected) {
        return
    }

    if (!length_array(cmd)) {
        return
    }

    result =    "
                    'GET /cgi-bin/aw_ptz?cmd=', cmd, '&res=1 HTTP/1.1', NAV_CR, NAV_LF,
                    // 'User-Agent: AMX-Master', NAV_CR, NAV_LF,
                    'Host: ', module.Device.SocketConnection.Address, NAV_CR, NAV_LF,
                    'Connection: Close', NAV_CR, NAV_LF
                "

    if (length_array(basicAuthB64)) {
        result =    "
                        result,
                        'Authorization: Basic ', basicAuthB64, NAV_CR, NAV_LF
                    "
    }

    payload = "result, NAV_CR, NAV_LF"

    OpenSocketConnection()
}


define_function char[NAV_MAX_CHARS] BuildCommand(char att[], char value[]) {
    return "'#', att, value"
}


define_function OpenSocketConnection() {
    if (module.Device.SocketConnection.IsConnected) {
        return
    }

    NAVClientSocketOpen(dvPort.PORT,
                        module.Device.SocketConnection.Address,
                        module.Device.SocketConnection.Port,
                        IP_TCP)
}


define_function Reset() {
    module.Device.SocketConnection.IsConnected = false
    module.Device.IsCommunicating = false
    module.Device.IsInitialized = false
}


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    switch (event.Name) {
        case NAV_MODULE_PROPERTY_EVENT_IP_ADDRESS: {
            module.Device.SocketConnection.Address = event.Args[1]
            module.Device.SocketConnection.Port = IP_PORT

            if (autoFocus == AUTO_FOCUS_STATUS_UNKNOWN) {
                wait 50 {
                    BuildPayload(BuildCommand('D1', ''))
                }
            }
        }
        case 'BASIC_AUTH_B64': {
            basicAuthB64 = event.Args[1]
        }
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
define_function NAVModulePassthruEventCallback(_NAVModulePassthruEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    BuildPayload(event.Payload)
}
#END_IF


#IF_DEFINED USING_NAV_STRING_GATHER_CALLBACK
define_function NAVStringGatherCallback(_NAVStringGatherResult args) {
    stack_var char data[NAV_MAX_BUFFER]
    stack_var char delimiter[NAV_MAX_CHARS]

    data = args.Data
    delimiter = args.Delimiter

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                            dvPort,
                                            data))
}
#END_IF


// define_function ChannelEventHandler(tchannel channel, char state) {
//     stack_var char payload[NAV_MAX_BUFFER]

//     getAutoFocus = false

//     switch (state) {
//         case true: {
//             switch (channel.channel) {
//                 case PWR_ON: {
//                     payload = BuildPayload(BuildCommand('O', '1'))
//                 }
//                 case PWR_OFF: {
//                     payload = BuildPayload(BuildCommand('O', '0'))
//                 }
//                 case TILT_UP: {
//                     payload = BuildPayload(BuildCommand('T', itoa(PTZ_STOP + tiltSpeed)))
//                 }
//                 case TILT_DN: {
//                     payload = BuildPayload(BuildCommand('T', itoa(PTZ_STOP - tiltSpeed)))
//                 }
//                 case PAN_LT: {
//                     payload = BuildPayload(BuildCommand('P', itoa(PTZ_STOP - panSpeed)))
//                 }
//                 case PAN_RT: {
//                     payload = BuildPayload(BuildCommand('P', itoa(PTZ_STOP + panSpeed)))
//                 }
//                 case ZOOM_IN: {
//                     payload = BuildPayload(BuildCommand('Z', itoa(PTZ_STOP + zoomSpeed)))
//                 }
//                 case ZOOM_OUT: {
//                     payload = BuildPayload(BuildCommand('Z', itoa(PTZ_STOP - zoomSpeed)))
//                 }
//                 case FOCUS_NEAR: {
//                     payload = BuildPayload(BuildCommand('F', itoa(PTZ_STOP + focusSpeed)))
//                 }
//                 case FOCUS_FAR: {
//                     payload = BuildPayload(BuildCommand('F', itoa(PTZ_STOP - focusSpeed)))
//                 }
//                 case AUTO_FOCUS_ON: {
//                     getAutoFocus = true;
//                     payload = BuildPayload(BuildCommand('D1', '1'))
//                 }
//                 case AUTO_FOCUS: {
//                     getAutoFocus = true;

//                     if (autoFocus == AUTO_FOCUS_STATUS_ON) {
//                         payload = BuildPayload(BuildCommand('D1', '0'))
//                     }
//                     else {
//                         payload = BuildPayload(BuildCommand('D1', '1'))
//                     }

//                 }
//                 case NAV_PRESET_1:
//                 case NAV_PRESET_2:
//                 case NAV_PRESET_3:
//                 case NAV_PRESET_4:
//                 case NAV_PRESET_5:
//                 case NAV_PRESET_6:
//                 case NAV_PRESET_7:
//                 case NAV_PRESET_8: {
//                     payload = BuildPayload(BuildCommand('R', format('%02d', NAVFindInArrayINTEGER(NAV_PRESET, channel.channel) - 1)))
//                 }
//             }
//         }
//         case false: {
//             switch (channel.channel) {
//                 case TILT_UP:
//                 case TILT_DN: {
//                     wait 1 {
//                         payload = BuildPayload(BuildCommand('T', itoa(PTZ_STOP)))
//                     }
//                 }
//                 case PAN_LT:
//                 case PAN_RT: {
//                     wait 1 {
//                         payload = BuildPayload(BuildCommand('P', itoa(PTZ_STOP)))
//                     }
//                 }
//                 case ZOOM_IN:
//                 case ZOOM_OUT: {
//                     wait 1 {
//                         payload = BuildPayload(BuildCommand('Z', itoa(PTZ_STOP)))
//                     }
//                 }
//                 case FOCUS_NEAR:
//                 case FOCUS_FAR: {
//                     wait 1 {
//                         payload = BuildPayload(BuildCommand('F', itoa(PTZ_STOP)))
//                     }
//                 }
//                 case AUTO_FOCUS_ON: {
//                     getAutoFocus = true;
//                     payload = BuildPayload(BuildCommand('D1', '0'))
//                 }
//             }
//         }
//     }

//     if (!length_array(payload)) {
//         return
//     }

//     payload = payload
//     OpenSocketConnection()
// }


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, module.RxBuffer.Data
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'mPanasonicCamera => Socket Online')

        if (data.device.number == 0) {
            module.Device.SocketConnection.IsConnected = true
        }

        Send(payload)
    }
    offline: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'mPanasonicCamera => Socket Offline')

        if (data.device.number == 0) {
            NAVClientSocketClose(data.device.port)
            Reset()
        }

        if (getAutoFocus) {
            BuildPayload(BuildCommand('D1', ''))
            getAutoFocus = false
        }
    }
    onerror: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'mPanasonicCamera => Socket Error')

        if (data.device.number == 0) {
            Reset()
        }
    }
    string: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                dvPort,
                                                data.text))

        select {
            active (NAVContains(data.text, 'd11')): {
                autoFocus = AUTO_FOCUS_STATUS_ON
            }
            active (NAVContains(data.text, 'd10')): {
                autoFocus = AUTO_FOCUS_STATUS_OFF
            }
        }

        select {
            active (true): {
                NAVStringGather(module.RxBuffer, "NAV_CR, NAV_LF, NAV_CR, NAV_LF")
            }
        }
    }
}


data_event[vdvObject] {
    command: {
        stack_var _NAVSnapiMessage message

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM,
                                                data.device,
                                                data.text))

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case 'PRESET': {
                BuildPayload(BuildCommand('R', format('%02d', atoi(message.Parameter[1]) - 1)))
            }
            case 'PRESETSAVE': {
                BuildPayload(BuildCommand('M', format('%02d', atoi(message.Parameter[1]) - 1)))
            }
        }
    }
}


channel_event[vdvObject, 0] {
    on: {
        getAutoFocus = false

        switch (channel.channel) {
            case PWR_ON: {
                BuildPayload(BuildCommand('O', '1'))
            }
            case PWR_OFF: {
                BuildPayload(BuildCommand('O', '0'))
            }
            case TILT_UP: {
                BuildPayload(BuildCommand('T', itoa(PTZ_STOP + tiltSpeed)))
            }
            case TILT_DN: {
                BuildPayload(BuildCommand('T', itoa(PTZ_STOP - tiltSpeed)))
            }
            case PAN_LT: {
                BuildPayload(BuildCommand('P', itoa(PTZ_STOP - panSpeed)))
            }
            case PAN_RT: {
                BuildPayload(BuildCommand('P', itoa(PTZ_STOP + panSpeed)))
            }
            case ZOOM_IN: {
                BuildPayload(BuildCommand('Z', itoa(PTZ_STOP + zoomSpeed)))
            }
            case ZOOM_OUT: {
                BuildPayload(BuildCommand('Z', itoa(PTZ_STOP - zoomSpeed)))
            }
            case FOCUS_NEAR: {
                BuildPayload(BuildCommand('F', itoa(PTZ_STOP + focusSpeed)))
            }
            case FOCUS_FAR: {
                BuildPayload(BuildCommand('F', itoa(PTZ_STOP - focusSpeed)))
            }
            case AUTO_FOCUS_ON: {
                getAutoFocus = true;
                BuildPayload(BuildCommand('D1', '1'))
            }
            case AUTO_FOCUS: {
                getAutoFocus = true;

                if (autoFocus == AUTO_FOCUS_STATUS_ON) {
                    BuildPayload(BuildCommand('D1', '0'))
                }
                else {
                    BuildPayload(BuildCommand('D1', '1'))
                }

            }
            case NAV_PRESET_1:
            case NAV_PRESET_2:
            case NAV_PRESET_3:
            case NAV_PRESET_4:
            case NAV_PRESET_5:
            case NAV_PRESET_6:
            case NAV_PRESET_7:
            case NAV_PRESET_8: {
                BuildPayload(BuildCommand('R', format('%02d', NAVFindInArrayINTEGER(NAV_PRESET, channel.channel) - 1)))
            }
        }
    }
    off: {
        getAutoFocus = false;

        switch (channel.channel) {
            case TILT_UP:
            case TILT_DN: {
                wait 1 {
                    BuildPayload(BuildCommand('T', itoa(PTZ_STOP)))
                }
            }
            case PAN_LT:
            case PAN_RT: {
                wait 1 {
                    BuildPayload(BuildCommand('P', itoa(PTZ_STOP)))
                }
            }
            case ZOOM_IN:
            case ZOOM_OUT: {
                wait 1 {
                    BuildPayload(BuildCommand('Z', itoa(PTZ_STOP)))
                }
            }
            case FOCUS_NEAR:
            case FOCUS_FAR: {
                wait 1 {
                    BuildPayload(BuildCommand('F', itoa(PTZ_STOP)))
                }
            }
            case AUTO_FOCUS_ON: {
                getAutoFocus = true;
                BuildPayload(BuildCommand('D1', '0'))
            }
        }
    }
}


level_event[vdvObject, TILT_SPEED_LVL] {
    tiltSpeed = level.value
}


level_event[vdvObject, PAN_SPEED_LVL] {
    panSpeed = level.value
}


level_event[vdvObject, ZOOM_SPEED_LVL] {
    zoomSpeed = level.value
}


level_event[vdvObject, FOCUS_SPEED_LVL] {
    focusSpeed = level.value
}


timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, AUTO_FOCUS_FB] = (autoFocus == AUTO_FOCUS_STATUS_ON)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)







