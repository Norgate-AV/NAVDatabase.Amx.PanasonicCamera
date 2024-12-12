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
#include 'NAVFoundation.Encoding.Base64.axi'
#include 'LibPanasonicCamera.axi'

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

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _Context context


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


define_function OpenSocketConnection() {
    if (module.Device.SocketConnection.IsConnected) {
        return
    }

    NAVClientSocketOpen(dvPort.PORT,
                        module.Device.SocketConnection.Address,
                        module.Device.SocketConnection.Port,
                        IP_TCP)
}


define_function BuildPayload(char type[], char cmd[]) {
    stack_var char result[NAV_MAX_BUFFER]

    if (!length_array(module.Device.SocketConnection.Address) || module.Device.SocketConnection.IsConnected) {
        return
    }

    if (!length_array(cmd) || !length_array(type)) {
        return
    }

    result =    "
                    'GET /cgi-bin/aw_', type, '?cmd=', cmd, '&res=1 HTTP/1.1', NAV_CR, NAV_LF,
                    // 'User-Agent: AMX-Master', NAV_CR, NAV_LF,
                    'Host: ', module.Device.SocketConnection.Address, NAV_CR, NAV_LF,
                    'Connection: Close', NAV_CR, NAV_LF
                "

    if (length_array(context.basicAuthB64)) {
        result =    "
                        result,
                        'Authorization: Basic ', context.basicAuthB64, NAV_CR, NAV_LF
                    "
    }

    if (!length_array(context.basicAuthB64) && length_array(context.credential.Username) && length_array(context.credential.Password)) {
        result =    "
                        result,
                        'Authorization: Basic ', GetAuth(context.credential), NAV_CR, NAV_LF
                    "
    }

    context.payload = "result, NAV_CR, NAV_LF"

    if (!module.Device.SocketConnection.IsConnected) {
        OpenSocketConnection()
        return
    }

    Send(context.payload)
}


define_function Reset() {
    module.Device.SocketConnection.IsConnected = false
    module.Device.IsCommunicating = false
    module.Device.IsInitialized = false
    context.payload = ''
}


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    switch (event.Name) {
        case NAV_MODULE_PROPERTY_EVENT_IP_ADDRESS: {
            module.Device.SocketConnection.Address = NAVTrimString(event.Args[1])
            module.Device.SocketConnection.Port = IP_PORT

            if (context.autoFocus == AUTO_FOCUS_STATUS_UNKNOWN) {
                wait 50 {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', ''))
                }
            }
        }
        case 'BASIC_AUTH_B64': {
            // Pass the base64 encoded string directly
            // Eg. YW14OjE5ODg= => amx:1988
            context.basicAuthB64 = NAVTrimString(event.Args[1])
        }
        case 'BASIC_AUTH': {
            // Pass the username and password separated by a colon to be base64 encoded
            // Eg. username:password => amx:1988 => YW14OjE5ODg=
            context.basicAuthB64 = NAVBase64Encode(NAVTrimString(event.Args[1]))
        }
        case 'USERNAME': {
            context.credential.Username = NAVTrimString(event.Args[1])
        }
        case 'PASSWORD': {
            context.credential.Password = NAVTrimString(event.Args[1])
        }
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
define_function NAVModulePassthruEventCallback(_NAVModulePassthruEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    if (NAVStartsWith(event.Payload, '#')) {
        BuildPayload(COMMAND_TYPE_PTZ, event.Payload)
        return
    }

    BuildPayload(COMMAND_TYPE_CAMERA, event.Payload)
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


define_function ContextInit(_Context context) {
    context.payload = ''

    context.basicAuthB64 = ''

    context.tiltSpeed = DEFAULT_TILT_SPEED
    context.panSpeed = DEFAULT_PAN_SPEED
    context.zoomSpeed = DEFAULT_ZOOM_SPEED
    context.focusSpeed = DEFAULT_FOCUS_SPEED

    context.autoFocus = AUTO_FOCUS_STATUS_UNKNOWN

    context.getAutoFocus = false

    context.credential.Username = ''
    context.credential.Password = ''
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, module.RxBuffer.Data

    set_virtual_level_count(vdvObject, 30)

    ContextInit(context)
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mPanasonicCamera => ', NAVDeviceToString(data.device), ' Socket Online'")

        if (data.device.number == 0) {
            module.Device.SocketConnection.IsConnected = true
        }

        Send(context.payload)
    }
    offline: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mPanasonicCamera => ', NAVDeviceToString(data.device), ' Socket Offline'")

        if (data.device.number == 0) {
            NAVClientSocketClose(data.device.port)
            Reset()
        }

        if (context.getAutoFocus) {
            BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', ''))
            context.getAutoFocus = false
        }
    }
    onerror: {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mPanasonicCamera => ', NAVDeviceToString(data.device),
                    ' Socket Error:: ', NAVGetSocketError(type_cast(data.number))")

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
                context.autoFocus = AUTO_FOCUS_STATUS_ON
            }
            active (NAVContains(data.text, 'd10')): {
                context.autoFocus = AUTO_FOCUS_STATUS_OFF
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
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'R', format('%02d', atoi(message.Parameter[1]) - 1)))
            }
            case 'PRESETSAVE': {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'M', format('%02d', atoi(message.Parameter[1]) - 1)))
            }
            case 'AUTOTRACK': {
                switch (message.Parameter[1]) {
                    case 'ON': {
                        BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B6', '1'))
                    }
                    case 'OFF': {
                        BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B6', '0'))
                    }
                }
            }
            case 'AUTOTRACK_ANGLE': {
                switch (message.Parameter[1]) {
                    case 'OFF': {
                        BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '0'))
                    }
                    case 'UPPER': {
                        BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '2'))
                    }
                    case 'FULL': {
                        BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '1'))
                    }
                }
            }
        }
    }
}


channel_event[vdvObject, 0] {
    on: {
        context.getAutoFocus = false

        switch (channel.channel) {
            case PWR_ON: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'O', '1'))
            }
            case PWR_OFF: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'O', '0'))
            }
            case TILT_UP: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'T', itoa(PTZ_STOP + context.tiltSpeed)))
            }
            case TILT_DN: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'T', itoa(PTZ_STOP - context.tiltSpeed)))
            }
            case PAN_LT: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'P', itoa(PTZ_STOP - context.panSpeed)))
            }
            case PAN_RT: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'P', itoa(PTZ_STOP + context.panSpeed)))
            }
            case ZOOM_IN: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'Z', itoa(PTZ_STOP + context.zoomSpeed)))
            }
            case ZOOM_OUT: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'Z', itoa(PTZ_STOP - context.zoomSpeed)))
            }
            case FOCUS_NEAR: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'F', itoa(PTZ_STOP + context.focusSpeed)))
            }
            case FOCUS_FAR: {
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'F', itoa(PTZ_STOP - context.focusSpeed)))
            }
            case AUTO_FOCUS_ON: {
                context.getAutoFocus = true;
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '1'))
            }
            case AUTO_FOCUS: {
                context.getAutoFocus = true;

                if (context.autoFocus == AUTO_FOCUS_STATUS_ON) {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '0'))
                }
                else {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '1'))
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
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'R', format('%02d', NAVFindInArrayINTEGER(NAV_PRESET, channel.channel) - 1)))
            }
        }
    }
    off: {
        context.getAutoFocus = false;

        switch (channel.channel) {
            case TILT_UP:
            case TILT_DN: {
                wait 1 {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'T', itoa(PTZ_STOP)))
                }
            }
            case PAN_LT:
            case PAN_RT: {
                wait 1 {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'P', itoa(PTZ_STOP)))
                }
            }
            case ZOOM_IN:
            case ZOOM_OUT: {
                wait 1 {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'Z', itoa(PTZ_STOP)))
                }
            }
            case FOCUS_NEAR:
            case FOCUS_FAR: {
                wait 1 {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'F', itoa(PTZ_STOP)))
                }
            }
            case AUTO_FOCUS_ON: {
                context.getAutoFocus = true;
                BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '0'))
            }
        }
    }
}


level_event[vdvObject, TILT_SPEED_LVL] {
    context.tiltSpeed = level.value

    if (context.tiltSpeed <= 0) {
        context.tiltSpeed = DEFAULT_TILT_SPEED
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                "'mPanasonicCamera => Tilt Speed: ', itoa(context.tiltSpeed)")
}


level_event[vdvObject, PAN_SPEED_LVL] {
    context.panSpeed = level.value

    if (context.panSpeed <= 0) {
        context.panSpeed = DEFAULT_PAN_SPEED
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                "'mPanasonicCamera => Pan Speed: ', itoa(context.panSpeed)")
}


level_event[vdvObject, ZOOM_SPEED_LVL] {
    context.zoomSpeed = level.value

    if (context.zoomSpeed <= 0) {
        context.zoomSpeed = DEFAULT_ZOOM_SPEED
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                "'mPanasonicCamera => Zoom Speed: ', itoa(context.zoomSpeed)")
}


level_event[vdvObject, FOCUS_SPEED_LVL] {
    context.focusSpeed = level.value

    if (context.focusSpeed <= 0) {
        context.focusSpeed = DEFAULT_FOCUS_SPEED
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                "'mPanasonicCamera => Focus Speed: ', itoa(context.focusSpeed)")
}


timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, AUTO_FOCUS_FB] = (context.autoFocus == AUTO_FOCUS_STATUS_ON)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)







