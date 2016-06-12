//
// MQTT.swift
//
// Original source created by Feng Lee<feng@eqmtt.io> on 14/8/3 and
// Copyright (c) 2015 emqtt.io MIT License.
// Copyright (c) 2016 iAchieved.it LLC
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import swiftlog

/**
 * MQTT Delegate
 */
public protocol MQTTDelegate:class {
  func mqtt(mqtt: MQTT, didConnect host: String, port: Int)
  func mqtt(mqtt: MQTT, didConnectAck ack: MQTTConnAck)
  func mqtt(mqtt: MQTT, didPublishMessage message: MQTTMessage, id: UInt16)
  
  func mqtt(mqtt: MQTT, didPublishAck id: UInt16)
  func mqtt(mqtt: MQTT, didReceiveMessage message: MQTTMessage, id: UInt16 )
  
  func mqtt(mqtt: MQTT, didSubscribeTopic topic: String)
  func mqtt(mqtt: MQTT, didUnsubscribeTopic topic: String)
  
  func mqttDidPing(mqtt: MQTT)
  func mqttDidReceivePong(mqtt: MQTT)
  func mqttDidDisconnect(mqtt: MQTT, withError err: NSError?)
  
}

/**
 * Blueprint of the MQTT client
 */
public protocol MQTTClient {
  
  var host: String { get set }
  var port: UInt16 { get set }
  var clientId: String { get }
  var username: String? {get set}
  var password: String? {get set}
  var secureMQTT: Bool {get set}
  var cleanSess: Bool {get set}
  var keepAlive: UInt16 {get set}
  var willMessage: MQTTWill? {get set}
  
  func connect() -> Bool
  func publish(topic: String, withString string: String, qos: MQTTQOS, retained: Bool, dup: Bool) -> UInt16
  func publish(message: MQTTMessage) -> UInt16
  func subscribe(topic: String, qos: MQTTQOS) -> UInt16
  func unsubscribe(topic: String) -> UInt16
  func ping()
  func disconnect()
}


public enum MQTTQOS: UInt8 {
  case QOS0 = 0
  case QOS1
  case QOS2
}

/**
 * Connection State
 */
public enum MQTTConnState: UInt8 {
  case INIT = 0
  case CONNECTING
  case CONNECTED
  case DISCONNECTED
}


/**
 * Conn Ack
 */
public enum MQTTConnAck: UInt8 {
  case ACCEPT  = 0
  case PROTO_VER
  case INVALID_ID
  case SERVER
  case CREDENTIALS
  case AUTH
}

/**
 * asyncsocket read tag
 */
enum MQTTReadTag: Int {
  case TAG_HEADER = 0
  case TAG_LENGTH
  case TAG_PAYLOAD
}

/**
 * Main MQTT Class
 */
public class MQTT: NSObject, MQTTClient, MQTTReaderDelegate, AsyncSocketDelegate {
  
  public var host = "localhost"
  public var port: UInt16 = 1883
  public var clientId: String
  public var username: String?
  public var password: String?
  public var secureMQTT: Bool = false
  public var backgroundOnSocket: Bool = false
  public var cleanSess: Bool = true
  
  //keep alive
  public var keepAlive: UInt16 = 60
  var aliveTimer: NSTimer?
  
  //will message
  public var willMessage: MQTTWill?
  
  //delegate weak??
  public weak var delegate: MQTTDelegate?
  
  //socket and connection
  public var connState = MQTTConnState.INIT
  var socket: AsyncSocket?
  var reader: MQTTReader?
  
  //global message id
  var gmid: UInt16 = 1
  
  //subscribed topics
  var subscriptions = Dictionary<UInt16, String>()
  
  //published messages
  public var messages = Dictionary<UInt16, MQTTMessage>()
  
  public init(clientId: String, host: String = "localhost", port: UInt16 = 1883) {
    self.clientId = clientId
    self.host = host
    self.port = port
  }
  
  //  API Functions
  
  public func connect() -> Bool {
    self.socket = AsyncSocket(host:self.host, port:self.port, delegate:self)
    reader = MQTTReader(socket: socket!, delegate: self)
    do {
      try socket!.connect()
      connState = MQTTConnState.CONNECTING
      return true
    } catch  {
      print("you just got thrown")
      SLogVerbose("MQTT: socket connect error")//: \(error.description)")
      return false
    }
  }
  
  public func publish(topic: String, withString string: String, qos: MQTTQOS = .QOS1, retained: Bool = false, dup: Bool = false) -> UInt16 {
    let message = MQTTMessage(topic: topic, string: string, qos: qos, retained: retained, dup: dup)
    return publish(message:message)
  }
  
  public func publish(message: MQTTMessage) -> UInt16 {
    let msgId: UInt16 = _nextMessageId()
    let frame = MQTTFramePublish(msgid: msgId, topic: message.topic, payload: message.payload)
    frame.qos = message.qos.rawValue
    frame.retained = message.retained
    frame.dup = message.dup
    send(frame:frame, tag: Int(msgId))
    if message.qos != MQTTQOS.QOS0 {
      messages[msgId] = message //cache
    }
    
    delegate?.mqtt(mqtt:self, didPublishMessage: message, id: msgId)
    
    return msgId
  }
  
  public func subscribe(topic: String, qos: MQTTQOS = .QOS1) -> UInt16 {
    let msgId = _nextMessageId()
    let frame = MQTTFrameSubscribe(msgid: msgId, topic: topic, reqos: qos.rawValue)
    send(frame:frame, tag: Int(msgId))
    subscriptions[msgId] = topic //cache?
    return msgId
  }
  
  public func unsubscribe(topic: String) -> UInt16 {
    let msgId = _nextMessageId()
    let frame = MQTTFrameUnsubscribe(msgid: msgId, topic: topic)
    subscriptions[msgId] = topic //cache
    send(frame:frame, tag: Int(msgId))
    return msgId
  }
  
  public func ping() {
    send(frame:MQTTFrame(type: MQTTFrameType.PINGREQ), tag: -0xC0)
    self.delegate?.mqttDidPing(mqtt:self)
  }
  
  public func disconnect() {
    ENTRY_LOG()
    send(frame:MQTTFrame(type: MQTTFrameType.DISCONNECT), tag: -0xE0)
    socket!.disconnect()
  }
  
  func send(frame: MQTTFrame, tag: Int = 0) {
    let data = frame.data()
    socket!.writeData(data:NSData(bytes: data, length: data.count), withTimeout: -1, tag: tag)
  }
  
  func sendConnectFrame() {
    let frame = MQTTFrameConnect(client: self)
    send(frame:frame)
    reader!.start()
    delegate?.mqtt(mqtt:self, didConnect: host, port: Int(port))
  }
  
  //AsyncSocket Delegate
  public func socket(socket: AsyncSocket, didConnectToHost host: String, port: UInt16) {
    SLogVerbose("MQTT: connected to \(host) : \(port)")
    
    /*
     if secureMQTT {
     #if DEBUG
     sock.startTLS(["AsyncSocketManuallyEvaluateTrust": true, kCFStreamSSLPeerName: self.host])
     #else
     sock.startTLS([kCFStreamSSLPeerName: self.host])
     #endif
     } else {
     */
    sendConnectFrame()
    
  }
  
  /*
   public func socket(sock: AsyncSocket!, didReceiveTrust trust: SecTrust!, completionHandler: ((Bool) -> Void)!) {
   #if DEBUG
   NSLog("MQTT: didReceiveTrust")
   #endif
   completionHandler(true)
   }
   */
  
  /*
   public func socketDidSecure(sock: AsyncSocket!) {
   #if DEBUG
   NSLog("MQTT: socketDidSecure")
   #endif
   sendConnectFrame()
   }
   */
  
  public func socket(socket: AsyncSocket, didWriteDataWithTag tag: Int) {
    SLogVerbose("MQTT: Socket write message with tag: \(tag)")
  }
  
  public func socket(socket: AsyncSocket, didReadData data: NSData!, withTag tag: Int) {
    let etag: MQTTReadTag = MQTTReadTag(rawValue: tag)!
    var bytes = [UInt8]([0])
    switch etag {
    case MQTTReadTag.TAG_HEADER:
      data.getBytes(&bytes, length: 1)
      reader!.headerReady(header:bytes[0])
    case MQTTReadTag.TAG_LENGTH:
      data.getBytes(&bytes, length: 1)
      reader!.lengthReady(byte:bytes[0])
    case MQTTReadTag.TAG_PAYLOAD:
      reader!.payloadReady(data:data)
    }
  }
  
  public func socketDidDisconnect(socket:AsyncSocket, withError err: NSError!) {
    connState = MQTTConnState.DISCONNECTED
    delegate?.mqttDidDisconnect(mqtt:self, withError: err)
  }
  
  //MQTTReader Delegate
  
  public func didReceiveConnAck(reader: MQTTReader, connack: UInt8) {
    connState = MQTTConnState.CONNECTED
    SLogVerbose("MQTT: CONNACK Received: \(connack)")
    
    let ack = MQTTConnAck(rawValue: connack)!
    delegate?.mqtt(mqtt:self, didConnectAck: ack)
    
    if ack == MQTTConnAck.ACCEPT && keepAlive > 0 {
      SLogVerbose("MQTT: Set keepAlive for \(keepAlive) seconds")
      let keepAliveThread = NSThread(){
        SLogVerbose("MQTT:  keepAlive thread started")
        self.aliveTimer = NSTimer.scheduledTimer(NSTimeInterval(self.keepAlive),
                                                 repeats:true){ timer in
          SLogVerbose("MQTT:  KeepAlive timer fired")
          if self.connState == MQTTConnState.CONNECTED {
            self.ping()
          } else {
            self.aliveTimer?.invalidate()
          }
        }
        SLogVerbose("MQTT:  Adding timer to run loop")
        NSRunLoop.currentRunLoop().addTimer(self.aliveTimer!,
                                            forMode:NSDefaultRunLoopMode)
        NSRunLoop.currentRunLoop().run()
      }
      SLogVerbose("MQTT:  Starting keepAlive thread")
      keepAliveThread.start()
    }
  }
  
  func didReceivePublish(reader: MQTTReader, message: MQTTMessage, id: UInt16) {
    SLogVerbose("MQTT: PUBLISH Received from \(message.topic)")
    delegate?.mqtt(mqtt:self, didReceiveMessage: message, id: id)
    if message.qos == MQTTQOS.QOS1 {
      _puback(type:MQTTFrameType.PUBACK, msgid: id)
    } else if message.qos == MQTTQOS.QOS2 {
      _puback(type:MQTTFrameType.PUBREC, msgid: id)
    }
  }
  
  func _puback(type: MQTTFrameType, msgid: UInt16) {
    var descr: String?
    switch type {
    case .PUBACK: descr = "PUBACK"
    case .PUBREC: descr = "PUBREC"
    case .PUBREL: descr = "PUBREL"
    case .PUBCOMP: descr = "PUBCOMP"
    default: assert(false)
    }
    if descr != nil {
      SLogVerbose("MQTT: Send \(descr!), msgid: \(msgid)")
    }
    send(frame:MQTTFramePubAck(type: type, msgid: msgid))
  }
  
  func didReceivePubAck(reader: MQTTReader, msgid: UInt16) {
    SLogVerbose("MQTT: PUBACK Received: \(msgid)")
    messages.removeValue(forKey:msgid)
    delegate?.mqtt(mqtt:self, didPublishAck: msgid)
  }
  
  func didReceivePubRec(reader: MQTTReader, msgid: UInt16) {
    SLogVerbose("MQTT: PUBREC Received: \(msgid)")
    _puback(type:MQTTFrameType.PUBREL, msgid: msgid)
  }
  
  func didReceivePubRel(reader: MQTTReader, msgid: UInt16) {
    SLogVerbose("MQTT: PUBREL Received: \(msgid)")
    if let message = messages[msgid] {
      messages.removeValue(forKey:msgid)
      delegate?.mqtt(mqtt:self, didPublishMessage: message, id: msgid)
    }
    _puback(type:MQTTFrameType.PUBCOMP, msgid: msgid)
  }
  
  func didReceivePubComp(reader: MQTTReader, msgid: UInt16) {
    SLogVerbose("MQTT: PUBCOMP Received: \(msgid)")
  }
  
  func didReceiveSubAck(reader: MQTTReader, msgid: UInt16) {
    SLogVerbose("MQTT: SUBACK Received: \(msgid)")
    if let topic = subscriptions.removeValue(forKey:msgid) {
      delegate?.mqtt(mqtt:self, didSubscribeTopic: topic)
    }
  }
  
  func didReceiveUnsubAck(reader: MQTTReader, msgid: UInt16) {
    SLogVerbose("MQTT: UNSUBACK Received: \(msgid)")
    if let topic = subscriptions.removeValue(forKey:msgid) {
      delegate?.mqtt(mqtt:self, didUnsubscribeTopic: topic)
    }
  }
  
  func didReceivePong(reader: MQTTReader) {
    SLogVerbose("MQTT: PONG Received")
    delegate?.mqttDidReceivePong(mqtt:self)
  }
  
  func _nextMessageId() -> UInt16 {
    self.gmid += 1
    let id = self.gmid
    if  id >= UInt16.max { self.gmid = 1 }
    return id
  }
  
}

/**
 * MQTT Reader Delegate
 */
protocol MQTTReaderDelegate {
  
  func didReceiveConnAck(reader: MQTTReader, connack: UInt8)
  func didReceivePublish(reader: MQTTReader, message: MQTTMessage, id: UInt16)
  func didReceivePubAck(reader: MQTTReader, msgid: UInt16)
  func didReceivePubRec(reader: MQTTReader, msgid: UInt16)
  func didReceivePubRel(reader: MQTTReader, msgid: UInt16)
  func didReceivePubComp(reader: MQTTReader, msgid: UInt16)
  func didReceiveSubAck(reader: MQTTReader, msgid: UInt16)
  func didReceiveUnsubAck(reader: MQTTReader, msgid: UInt16)
  func didReceivePong(reader: MQTTReader)
  
}

public class MQTTReader {
  
  var socket: AsyncSocket
  var header: UInt8 = 0
  var data: [UInt8] = []
  var length: UInt = 0
  var multiply: Int = 1
  var delegate: MQTTReaderDelegate
  var timeout: Int = 30000
  
  init(socket: AsyncSocket, delegate: MQTTReaderDelegate) {
    self.socket = socket
    self.delegate = delegate
  }
  
  func start() { readHeader() }
  
  func readHeader() {
    ENTRY_LOG()
    _reset(); socket.readDataToLength(length:1, withTimeout: -1, tag: MQTTReadTag.TAG_HEADER.rawValue)
  }
  
  func headerReady(header: UInt8) {
    SLogVerbose("MQTTReader: header ready: \(header) ")
    self.header = header
    readLength()
  }
  
  func readLength() {
    ENTRY_LOG()
    socket.readDataToLength(length:1, withTimeout: NSTimeInterval(timeout), tag: MQTTReadTag.TAG_LENGTH.rawValue)
  }
  
  func lengthReady(byte: UInt8) {
    length += (UInt)((Int)(byte & 127) * multiply)
    if byte & 0x80 == 0 { //done
      if length == 0 {
        frameReady()
      } else {
        readPayload()
      }
    } else { //more
      multiply *= 128
      readLength()
    }
  }
  
  func readPayload() {
    ENTRY_LOG()
    socket.readDataToLength(length:length, withTimeout: NSTimeInterval(timeout), tag: MQTTReadTag.TAG_PAYLOAD.rawValue)
  }
  
  func payloadReady(data: NSData) {
    self.data = [UInt8](repeating:0, count: data.length)
    data.getBytes(&(self.data), length: data.length)
    frameReady()
  }
  
  func frameReady() {
    //handle frame
    let frameType = MQTTFrameType(rawValue: UInt8(header & 0xF0))!
    switch frameType {
    case .CONNACK:
      delegate.didReceiveConnAck(reader:self, connack: data[1])
    case .PUBLISH:
      let (msgId, message) = unpackPublish()
      delegate.didReceivePublish(reader:self, message: message, id: msgId)
    case .PUBACK:
      delegate.didReceivePubAck(reader:self, msgid: _msgid(bytes:data))
    case .PUBREC:
      delegate.didReceivePubRec(reader:self, msgid: _msgid(bytes:data))
    case .PUBREL:
      delegate.didReceivePubRel(reader:self, msgid: _msgid(bytes:data))
    case .PUBCOMP:
      delegate.didReceivePubComp(reader:self, msgid: _msgid(bytes:data))
    case .SUBACK:
      delegate.didReceiveSubAck(reader:self, msgid: _msgid(bytes:data))
    case .UNSUBACK:
      delegate.didReceiveUnsubAck(reader:self, msgid: _msgid(bytes:data))
    case .PINGRESP:
      delegate.didReceivePong(reader:self)
    default:
      assert(false)
    }
    readHeader()
  }
  
  func unpackPublish() -> (UInt16, MQTTMessage) {
    let frame = MQTTFramePublish(header: header, data: data)
    frame.unpack()
    let msgId = frame.msgid!
    let qos = MQTTQOS(rawValue: frame.qos)!
    let message = MQTTMessage(topic: frame.topic!, payload: frame.payload, qos: qos, retained: frame.retained, dup: frame.dup)
    return (msgId, message)
  }
  
  func _msgid(bytes: [UInt8]) -> UInt16 {
    if bytes.count < 2 { return 0 }
    return UInt16(bytes[0]) << 8 + UInt16(bytes[1])
  }
  
  func _reset() {
    length = 0; multiply = 1; header = 0; data = []
  }
  
}
