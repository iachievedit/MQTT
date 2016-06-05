//
//  main.swift
//  
//

import Foundation

class Client:MQTT, MQTTDelegate {
  
  init(clientId:String) {
    super.init(clientId:clientId)
    super.delegate = self
  }
  
  func mqtt(mqtt: MQTT, didConnect host: String, port: Int) {
    print("didConnect")
  }
  func mqtt(mqtt: MQTT, didConnectAck ack: MQTTConnAck) {
    print("didConnectAck")
  }
  func mqtt(mqtt: MQTT, didPublishMessage message: MQTTMessage, id: UInt16) {
    print("didPublishMessage")
  }
  
  func mqtt(mqtt: MQTT, didPublishAck id: UInt16) {
    print("didPublishAck")
  }
  func mqtt(mqtt: MQTT, didReceiveMessage message: MQTTMessage, id: UInt16 ) {
    print("didReceiveMessage")
  }
  
  func mqtt(mqtt: MQTT, didSubscribeTopic topic: String) {
    print("didSubscribeTopic")
  }
  func mqtt(mqtt: MQTT, didUnsubscribeTopic topic: String) {
    print("didUnsubscribeTopic")
  }
  
  func mqttDidPing(mqtt: MQTT) {
    print("mqttDidPing")
  }
  func mqttDidReceivePong(mqtt: MQTT) {
    print("mqttDidReceivePong")
  }
  func mqttDidDisconnect(mqtt: MQTT, withError err: NSError?) {
    print("mqttDidDisconnect")
  }
}

let client = Client(clientId:"temperature")
client.host = "test.mosquitto.org"
client.port = 1883
client.connect()
client.publish(topic:"temp/random", withString:"30")