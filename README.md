[![Swift][swift-badge]][swift-url]
[![Platform][platform-badge]][platform-url]
[![License][mit-badge]][mit-url]

MQTT
=========

*Warning!*  Swift 3.0 is still under active development.  This package is continuously updated to what is in the Swift repositories, not the snapshots.  Until Swift 3.0 stabilizes this repository should be considered EXPERIMENTAL.
*August 6, 2016 Update* Swift 3.0 is still churning and the underlying libraries that this implementation of MQTT relies on are churning along with it.  I don't expect this lib to stabilize for another couple of months!


MQTT v3.1.1 client library for Linux written with Swift 3.0

### Features
This code remains beta but basic functionality is working.  
- [x] Basic MQTT connect
- [x] Basic MQTT publish
- [x] Basic MQTT subscribe
- [x] MQTT keep-alive (ping/pong)
- [x] Last Will and Testament
- [ ] MQTT SSL
- [ ] Testcases

Build
=====

Build with `swift build`.

To see the MQTT library in action try our [example client](https://github.com/iachievedit/MQTTClient).


Installation
=====
To be documented.


Usage
=====
To be documented.

In the interim, see companion articles:

* [Writing a Publisher](http://dev.iachieved.it/iachievedit/mqtt-with-swift-on-linux/)
* [Writing a Subscriber](http://dev.iachieved.it/iachievedit/mqtt-subscriptions-with-swift-on-linux/)
* [Utilizing a Last Will and Testament](http://dev.iachieved.it/iachievedit/mqtt-last-will-and-testament/)

LICENSE
=======

MIT License (see `LICENSE`)

## Contributors

This code is based upon the work done by Feng Lee <feng@emqtt.io> and others in the https://github.com/emqtt/CocoaMQTT project.

Twitter
======

https://twitter.com/iachievedit

[swift-badge]: https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat
[swift-url]: https://swift.org
[platform-badge]: https://img.shields.io/badge/OS-Linux-lightgray.svg?style=flat
[platform-url]: https://swift.org
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license
