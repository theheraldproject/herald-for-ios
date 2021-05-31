# Herald-for-iOS

![Epidemiology](images/epidemiology.png)

Continuous proximity detection across iOS and Android devices in background mode for contact tracing and infection control according to epidemiology requirements. 

All files are copyright 2020-2021 Herald Project Contributors and
are provided under the Apache 2.0 license.

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache2.0-yellow.svg)](https://opensource.org/licenses/Apache-2.0)

See LICENSE.txt and NOTICE.txt for details.

### Contents

- [Introduction](#introduction)
- [Key features](#key-features)
- [Hardware requirements](#hardware-requirements)
- [Quick start](#quick-start)
- [Test results](#test-results)
- [References](#references)

## Introduction

![Efficacy](images/efficacy.png)

This solution will:

- Operate on 98.0% of UK phones and 97.5% of phones worldwide without requiring a software update.
- Detect 100% of iOS and Android devices within 8 metres for contact tracing.
- Measure distance between devices at least once every 30 seconds for infection risk estimation.

This is a new, original, free and open source cross-platform proximity detection solution that has been developed according to epidemiology requirements (Ferretti, et al., 2020) for controlling COVID-19. This Bluetooth Low Energy (BLE) based solution offers accurate and frequent distance measurements between phones running iOS 9.3+ and Android 5.0+, including devices that do not support BLE advertising (circa 35% in the UK).

## Key features

- Works on the vast majority of phones in the UK (98.0%) and worldwide (97.5%) by minimising operating system and hardware requirements (Statcounter, 2020).
- Fully operational as a background app on both iOS and Android devices for consistent and continuous use to maximise disease transmission monitoring and control across the population.
- Low power usage (circa 2% per hour) to maximise population acceptance for continuous use.
- Detection and identification of iOS and Android devices in both foreground and background modes is 100% to maximise contact tracing coverage. 
- One or more distance measurement per 30 second window for devices within epidemiologically relevant range (8 metres) for accurate infection risk estimation and case isolation; coverage is > 99.5% of 30 second windows for 2 to 3 devices, and 93% - 96% of windows for 9 to 10 devices.
- RSSI measurements for distance estimation is 98.5% accurate within epidemiologically relevant range (8 metres).
- Device identification payload agnostic to support both centralised, and decentralised approaches, as well as retrospective integration into existing solutions.
  - Transmit and receive for Herald Protocol based payloads
  - Transmit and receive for BlueTrace payloads
  - Receive for GAEN payloads
- Apache-2.0 licensed and open source for ease of integration, reuse and transparency.

## Hardware requirements

- Operating system

  - iOS 9.3+, tested up to iOS 14.6.
  - Android 5.0+, tested up to Android 10.0 (API level 29).

- Hardware

  - Apple iPhone 4S+, tested up to iPhone 11 Pro.
  - Android phones with BLE, including phones that do not support BLE advertising (circa 35% in UK).

## Quick start

Please see the [developer guide](https://heraldprox.io/guide/add)
for how to integrate your app to Herald.

## Test results

For current and historic test and efficacy results please see the 
[Efficacy section](https://heraldprox.io/efficacy/results)
of the Herald website.

## References

Ferretti, L., Wymant, C., Kendall, M., Zhao, L., Nurtay, A., Abeler-Dörner, L., Parker, M., Bonsall, D., and Fraser, C. (2020) "Quantifying SARS-CoV-2 transmission suggests epidemic control with digital contact tracing", *Science*, vol. 368, no. 6491, New York.

Statcounter 2020, *Mobile Operating System Market Share*, Statcounter Global Stats, viewed August 2020, <https://gs.statcounter.com/os-market-share/mobile/worldwide>
