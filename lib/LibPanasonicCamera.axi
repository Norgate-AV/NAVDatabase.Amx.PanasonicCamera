PROGRAM_NAME='LibPanasonicCamera'

(***********************************************************)
#include 'NAVFoundation.Core.axi'
#include 'NAVFoundation.Encoding.Base64.axi'

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


#IF_NOT_DEFINED __LIB_PANASONIC_CAMERA__
#DEFINE __LIB_PANASONIC_CAMERA__ 'LibPanasonicCamera'

#include 'NAVFoundation.Core.axi'


DEFINE_CONSTANT

constant integer IP_PORT    = 80

constant char COMMAND_TYPE_CAMERA[] = 'cam'
constant char COMMAND_TYPE_PTZ[] = 'ptz'

constant integer PTZ_STOP = 50

constant integer AUTO_FOCUS_STATUS_UNKNOWN  = 0
constant integer AUTO_FOCUS_STATUS_ON       = 1
constant integer AUTO_FOCUS_STATUS_OFF      = 2

constant integer DEFAULT_TILT_SPEED = 40
constant integer DEFAULT_PAN_SPEED = 40
constant integer DEFAULT_ZOOM_SPEED = 20
constant integer DEFAULT_FOCUS_SPEED = 20


DEFINE_TYPE

struct _Context {
    char payload[NAV_MAX_BUFFER]

    char basicAuthB64[255]

    integer tiltSpeed
    integer panSpeed
    integer zoomSpeed
    integer focusSpeed

    integer autoFocus

    integer getAutoFocus

    _NAVCredential credential
}


define_function char[NAV_MAX_CHARS] BuildCommand(char type[], char cmd[], char data[]) {
    if (type == COMMAND_TYPE_PTZ) {
        return "'#', cmd, data"
    }

    if (length_array(data)) {
        return "cmd, ':', data"
    }

    return cmd
}


define_function char[NAV_MAX_BUFFER] GetAuth(_NAVCredential credential) {
    return NAVBase64Encode("credential.Username, ':', credential.Password")
}


#END_IF // __LIB_PANASONIC_CAMERA__
