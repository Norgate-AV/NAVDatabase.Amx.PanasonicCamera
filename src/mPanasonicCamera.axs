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
#include 'NAVFoundation.Queue.axi'
#include 'NAVFoundation.Url.axi'
#include 'NAVFoundation.HttpUtils.axi'
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

constant long TL_SOCKET_WAIT    = 1
constant long TL_INIT_WAIT      = 2
constant long TL_SOCKET_FIRST_CONNECTION_RETRY = 3

constant long TL_SOCKET_WAIT_INTERVAL[] = { 50 }
constant long TL_INIT_WAIT_INTERVAL[] = { 30000 }
constant long TL_SOCKET_FIRST_CONNECTION_RETRY_INTERVAL[] = { 5000 }


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
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO,
                                            dvPort,
                                            GetCommand(payload)))

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
    stack_var _NAVUrl url
    stack_var _NAVHttpRequest request
    stack_var char endpoint[255]
    stack_var char payload[NAV_MAX_BUFFER]

    if (!length_array(module.Device.SocketConnection.Address) ||
        module.Device.SocketConnection.IsConnected) {
        return
    }

    if (!length_array(cmd) || !length_array(type)) {
        return
    }

    endpoint = GetApiEndpoint(
        module.Device.SocketConnection.Address,
        "'aw_', type, '?cmd=', cmd, '&res=1'"
    )

    if (!NAVParseUrl(endpoint, url)) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ': Failed to parse URL'")

        return
    }

    if (!NAVHttpRequestInit(request, NAV_HTTP_METHOD_GET, url, '')) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ': Failed to initialize HTTP request'")

        return
    }

    NAVHttpRequestAddHeader(request, NAV_HTTP_HEADER_CONNECTION, 'Close')

    if (length_array(context.basicAuthB64)) {
        NAVHttpRequestAddHeader(request, NAV_HTTP_HEADER_AUTHORIZATION, "'Basic ', context.basicAuthB64")
    }

    if (!length_array(context.basicAuthB64) && length_array(context.credential.Username) && length_array(context.credential.Password)) {
        NAVHttpRequestAddHeader(request, NAV_HTTP_HEADER_AUTHORIZATION, "'Basic ', GetAuth(context.credential)")
    }

    if (!NAVHttpBuildRequest(request, payload)) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ': Failed to build HTTP request'")

        return
    }

    NAVQueueEnqueue(context.queue, payload)

    if (!module.Device.SocketConnection.IsConnected) {
        if (!timeline_active(TL_SOCKET_WAIT)) {
            OpenSocketConnection()
        }

        return
    }

    context.payload = NAVQueueDequeue(context.queue)
    Send(context.payload)
}


define_function char[NAV_MAX_BUFFER] GetCommand(char payload[]) {
    return NAVGetStringBetween(payload, 'cmd=', '&res')
}


define_function Reset() {
    module.Device.SocketConnection.IsConnected = false
    // module.Device.IsCommunicating = false
    // module.Device.IsInitialized = false
    context.payload = ''
    context.lastCommand = ''
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

            if (!context.initialized) {
                NAVTimelineStart(TL_INIT_WAIT, TL_INIT_WAIT_INTERVAL, TIMELINE_ABSOLUTE, TIMELINE_ONCE)
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
    stack_var char response[NAV_MAX_BUFFER]

    data = args.Data
    delimiter = args.Delimiter

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                            dvPort,
                                            data))

    context.lastCommand = GetCommand(context.payload)

    if (!NAVContains(data, 'HTTP/1.1 200 OK')) {
        stack_var char code[3]
        stack_var char header[255]
        stack_var char message[255]

        header = NAVStripRight(remove_string(data, "NAV_CR", 1), 1)
        code = NAVGetStringBetween(header, 'HTTP/1.1 ', ' ')
        message = NAVStringSubstring(header, NAVLastIndexOf(header, ' ') + 1, 0)

        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Error: ', code, ' ', message")

        return
    }

    if (NAVStartsWith(data, 'HTTP')) {
        // Responses are prepended to the HTTP header
        // If the response starts with HTTP, then there is no response to parse

        // If it is just a simple 200 response, then we could reference the last
        // command sent to immediately set some feedback
        select {
            active (NAVContains(context.lastCommand, 'D11')): {
                context.autoFocus = AUTO_FOCUS_STATUS_ON
            }
            active (NAVContains(context.lastCommand, 'D10')): {
                context.autoFocus = AUTO_FOCUS_STATUS_OFF
            }
            active (NAVContains(context.lastCommand, 'B6:1')): {
                context.autoTrack = AUTO_TRACK_STATUS_ON
            }
            active (NAVContains(context.lastCommand, 'B6:0')): {
                context.autoTrack = AUTO_TRACK_STATUS_OFF
            }
            active (NAVContains(context.lastCommand, 'B7:1')): {
                context.autoTrackAngle = AUTO_TRACK_ANGLE_STATUS_FULL
            }
            active (NAVContains(context.lastCommand, 'B7:2')): {
                context.autoTrackAngle = AUTO_TRACK_ANGLE_STATUS_UPPER
            }
            active (NAVContains(context.lastCommand, 'B7:0')): {
                context.autoTrackAngle = AUTO_TRACK_ANGLE_STATUS_OFF
            }
        }

        return
    }

    response = NAVStringSubstring(data, 1, NAVIndexOf(data, 'HTTP', 1) - 1)

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Response: ', response")

    select {
        active (NAVContains(response, 'd11')): {
            context.autoFocus = AUTO_FOCUS_STATUS_ON
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Auto Focus: ON'")

            context.initialized = true
        }
        active (NAVContains(response, 'd10')): {
            context.autoFocus = AUTO_FOCUS_STATUS_OFF
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Auto Focus: OFF'")

            context.initialized = true
        }
        active (NAVContains(response, 'B6:1')): {
            context.autoTrack = AUTO_TRACK_STATUS_ON
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Auto Track: ON'")

            context.initialized = true
        }
        active (NAVContains(response, 'B6:0')): {
            context.autoTrack = AUTO_TRACK_STATUS_OFF
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Auto Track: OFF'")

            context.initialized = true
        }
        active (NAVContains(response, 'B7:1')): {
            context.autoTrackAngle = AUTO_TRACK_ANGLE_STATUS_FULL
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Auto Track Angle: FULL'")

            context.initialized = true
        }
        active (NAVContains(response, 'B7:2')): {
            context.autoTrackAngle = AUTO_TRACK_ANGLE_STATUS_UPPER
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Auto Track Angle: UPPER'")

            context.initialized = true
        }
        active (NAVContains(response, 'B7:0')): {
            context.autoTrackAngle = AUTO_TRACK_ANGLE_STATUS_OFF
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(dvPort), ' Auto Track Angle: OFF'")

            context.initialized = true
        }
    }
}
#END_IF


define_function ContextInit(_Context context) {
    context.payload = ''
    context.lastCommand = ''

    context.basicAuthB64 = ''

    context.tiltSpeed = DEFAULT_TILT_SPEED
    context.panSpeed = DEFAULT_PAN_SPEED
    context.zoomSpeed = DEFAULT_ZOOM_SPEED
    context.focusSpeed = DEFAULT_FOCUS_SPEED

    context.autoFocus = AUTO_FOCUS_STATUS_UNKNOWN
    context.autoTrack = AUTO_TRACK_STATUS_UNKNOWN
    context.autoTrackAngle = AUTO_TRACK_ANGLE_STATUS_UNKNOWN

    context.credential.Username = ''
    context.credential.Password = ''

    context.firstConnectionEstablished = false
    context.initialized = false

    NAVQueueInit(context.queue, 50)
}


define_function HandleCommandDataEvent(tdata data, _NAVSnapiMessage message) {
    if (!context.initialized) {
        return
    }

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
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B6', ''))
                }
                case 'OFF': {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B6', '0'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B6', ''))
                }
                case 'START': {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:BC', '1'))
                }
                case 'STOP': {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:BC', '0'))
                }
            }
        }
        case 'AUTOTRACK_ANGLE': {
            switch (message.Parameter[1]) {
                case 'OFF': {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '0'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B7', ''))
                }
                case 'UPPER': {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '2'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B7', ''))
                }
                case 'FULL': {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '1'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B7', ''))
                }
            }
        }
    }
}


define_function HandleChannelEvent(tchannel channel, char state) {
    if (!context.initialized) {
        return
    }

    switch (state) {
        case true: {
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
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '1'))
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', ''))
                }
                case AUTO_FOCUS: {
                    if (context.autoFocus == AUTO_FOCUS_STATUS_ON) {
                        BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '0'))
                    }
                    else {
                        BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '1'))
                    }

                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', ''))
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
                case AUTO_TRACK_ON: {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B6', '1'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B6', ''))
                }
                case AUTO_TRACK_OFF: {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B6', '0'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B6', ''))
                }
                case AUTO_TRACK_ANGLE_FULL: {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '1'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B7', ''))
                }
                case AUTO_TRACK_ANGLE_UPPER: {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '2'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B7', ''))
                }
                case AUTO_TRACK_ANGLE_OFF: {
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'OSL:B7', '0'))
                    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B7', ''))
                }
            }
        }
        case false: {
            switch (channel.channel) {
                case TILT_UP:
                case TILT_DN: {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'T', itoa(PTZ_STOP)))
                }
                case PAN_LT:
                case PAN_RT: {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'P', itoa(PTZ_STOP)))
                }
                case ZOOM_IN:
                case ZOOM_OUT: {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'Z', itoa(PTZ_STOP)))
                }
                case FOCUS_NEAR:
                case FOCUS_FAR: {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'F', itoa(PTZ_STOP)))
                }
                case AUTO_FOCUS_ON: {
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', '0'))
                    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', ''))
                }
            }
        }
    }
}


define_function Init() {
    BuildPayload(COMMAND_TYPE_PTZ, BuildCommand(COMMAND_TYPE_PTZ, 'D1', ''))
    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B6', ''))
    BuildPayload(COMMAND_TYPE_CAMERA, BuildCommand(COMMAND_TYPE_CAMERA, 'QSL:B7', ''))

    // Kick things off
    OpenSocketConnection()
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
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    "'mPanasonicCamera => ', NAVDeviceToString(data.device), ' Socket Online'")

        if (data.device.number == 0) {
            module.Device.SocketConnection.IsConnected = true

            if (!context.firstConnectionEstablished) {
                context.firstConnectionEstablished = true
                NAVTimelineStop(TL_SOCKET_FIRST_CONNECTION_RETRY)
            }
        }

        if (NAVQueueHasItems(context.queue)) {
            context.payload = NAVQueueDequeue(context.queue)

            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mPanasonicCamera => ', NAVDeviceToString(data.device), ' Sending: ', GetCommand(context.payload)")

            Send(context.payload)
        }
    }
    offline: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    "'mPanasonicCamera => ', NAVDeviceToString(data.device), ' Socket Offline'")

        if (data.device.number == 0) {
            module.Device.SocketConnection.IsConnected = false
        }

        if (NAVQueueHasItems(context.queue)) {
            // Wait for little bit before trying to reconnect
            NAVTimelineStart(TL_SOCKET_WAIT, TL_SOCKET_WAIT_INTERVAL, TIMELINE_ABSOLUTE, TIMELINE_ONCE)
        }
    }
    onerror: {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mPanasonicCamera => ', NAVDeviceToString(data.device),
                    ' Socket Error:: ', NAVGetSocketError(type_cast(data.number))")

        if (data.device.number == 0) {
            Reset()
        }

        if (!context.firstConnectionEstablished) {
            NAVTimelineStart(TL_SOCKET_FIRST_CONNECTION_RETRY,
                            TL_SOCKET_FIRST_CONNECTION_RETRY_INTERVAL,
                            TIMELINE_ABSOLUTE,
                            TIMELINE_REPEAT)
        }
    }
    string: {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                dvPort,
                                                data.text))

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

        NAVParseSnapiMessage(data.text, message)

        HandleCommandDataEvent(data, message)
    }
}


channel_event[vdvObject, 0] {
    on: {
        HandleChannelEvent(channel, true)
    }
    off: {
        HandleChannelEvent(channel, false)
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


timeline_event[TL_SOCKET_WAIT]
timeline_event[TL_SOCKET_FIRST_CONNECTION_RETRY] {
    OpenSocketConnection()
}


timeline_event[TL_INIT_WAIT] {
    Init()
}


timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, AUTO_FOCUS_FB] = (context.autoFocus == AUTO_FOCUS_STATUS_ON)
    [vdvObject, AUTO_TRACK_FB] = (context.autoTrack == AUTO_TRACK_STATUS_ON)
    [vdvObject, AUTO_TRACK_ANGLE_FULL_FB] = (context.autoTrackAngle == AUTO_TRACK_ANGLE_STATUS_FULL)
    [vdvObject, AUTO_TRACK_ANGLE_UPPER_FB] = (context.autoTrackAngle == AUTO_TRACK_ANGLE_STATUS_UPPER)
    [vdvObject, AUTO_TRACK_ANGLE_OFF_FB] = (context.autoTrackAngle == AUTO_TRACK_ANGLE_STATUS_OFF)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
