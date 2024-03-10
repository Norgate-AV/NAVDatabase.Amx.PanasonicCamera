# NAVDatabase.Amx.PanasonicCamera

<!-- <div align="center">
 <img src="./" alt="logo" width="200" />
</div> -->

---

[![CI](https://github.com/Norgate-AV/NAVDatabase.Amx.PanasonicCamera/actions/workflows/main.yml/badge.svg)](https://github.com/Norgate-AV/NAVDatabase.Amx.PanasonicCamera/actions/workflows/main.yml)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

AMX NetLinx module for Panasonic cameras.

## Contents :book:

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

-   [Installation :zap:](#installation-zap)
-   [Usage :rocket:](#usage-rocket)
-   [Team :soccer:](#team-soccer)
-   [Contributors :sparkles:](#contributors-sparkles)
-   [LICENSE :balance_scale:](#license-balance_scale)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation :zap:

This module can be installed using [Scoop](https://scoop.sh/).

```powershell
scoop bucket add norgateav-amx https://github.com/Norgate-AV/scoop-norgateav-amx
scoop install navdatabase-amx-panasonic-camera
```

## Usage :rocket:

Use standard SNAPI channels to control the PTZ of camera.

```netlinx
DEFINE_DEVICE

// The real device
// dvPanasonicCamera           = 0:4:0             // IP/Socket Connection

// Virtual Devices
vdvPanasonicCamera             = 33201:1:0         // The interface between the device and the control system

// User Interface
dvTP                            = 10001:1:0         // Main UI


define_module 'mPanasonicCamera' PanasonicCameraComm(vdvPanasonicCamera, dvPanasonicCamera)


DEFINE_EVENT

data_event[vdvPanasonicCamera] {
    online: {
        send_command data.device, "'PROPERTY-IP_ADDRESS,', '192.168.1.21'"

        // Camera should be setup with a user specifically for the control system
        // User type should be "Camera Control" with "Basic Auth" enabled
        // Basic auth is the base64 encoded string of <username:password>
        send_command data.device, "'PROPERTY-BASIC_AUTH_B64,', 'YW14OjE5ODg='"
    }
}

```

## Team :soccer:

This project is maintained by the following person(s) and a bunch of [awesome contributors](https://github.com/Norgate-AV/NAVDatabase.Amx.PanasonicCamera/graphs/contributors).

<table>
  <tr>
    <td align="center"><a href="https://github.com/damienbutt"><img src="https://avatars.githubusercontent.com/damienbutt?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Damien Butt</b></sub></a><br /></td>
  </tr>
</table>

## Contributors :sparkles:

<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->

[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)

<!-- ALL-CONTRIBUTORS-BADGE:END -->

Thanks go to these awesome people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://allcontributors.org) specification.
Contributions of any kind are welcome!

## LICENSE :balance_scale:

[MIT](LICENSE)
