# Third-party code

## MonitorControl — Arm64 DDC (MIT)

The following files are adapted from [MonitorControl](https://github.com/MonitorControl/MonitorControl) (MIT License):

- `Arm64DDC.swift` — Apple Silicon DDC/CI over `IOAVService` I²C
- `Bridging-Header.h` — private CoreDisplay / IOAVService declarations

**Source:** [MonitorControl/Support/Arm64DDC.swift](https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Support/Arm64DDC.swift)  
**Source:** [MonitorControl/Support/Bridging-Header.h](https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Support/Bridging-Header.h)

Copyright © MonitorControl contributors (@JoniVR, @theOneyouseek, @waydabber, and others).

```
MIT License

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
```

MyMenu uses this code only for external-monitor brightness via MCCS VCP `0x10` (luminance). The app is not affiliated with MonitorControl.
