//
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


import TCP
import Foundation
import swiftlog

public protocol AsyncSocketDelegate {
  func socket(socket:AsyncSocket, didConnectToHost host:String, port:UInt16)
  func socket(socket:AsyncSocket, didReadData:NSData!, withTag tag:Int)
  func socket(socket:AsyncSocket, didWriteDataWithTag tag:Int)
  func socketDidDisconnect(socket:AsyncSocket, withError error:NSError!)
}

public class AsyncSocket {
  var host:String = ""
  var port:UInt16    = 0
  var socket:TCPConnection?
  var delegate:AsyncSocketDelegate?
  
  init(host:String, port:UInt16, delegate:AsyncSocketDelegate?) {
    self.host     = host
    self.port     = port
    self.delegate = delegate
    socket = try! TCPConnection(host:host,port:Int(port))
  }

  func connect() {
    do {
      try self.socket?.open()
      self.delegate?.socket(socket:self,
                           didConnectToHost:self.host,
                           port:self.port)
    } catch {
      self.delegate?.socketDidDisconnect(socket:self,
                                         withError:nil)
    }
  }
  
  func readDataToLength(length:UInt, withTimeout timeout:NSTimeInterval, tag:Int) {
    SLogVerbose("AysncSocket:  Read up to \(length) bytes with timeout \(timeout)")
    let thread = NSThread(){
      do {
          let data = try self.socket?.receive(upTo: Int(length))
          self.delegate?.socket(socket:self, didReadData:data!.toNSData(), withTag:tag)
      } catch StreamError.closedStream(let data) {
          SLogError("readDataToLength error:  received data \(data)")
          self.delegate?.socketDidDisconnect(socket:self, withError:nil)
        }
      catch {
        
      }
    }
    thread.start()
  }
  
  func writeData(data:NSData, withTimeout timeout:NSTimeInterval, tag:Int) {
    let thread = NSThread(){
      do {
        try self.socket?.send(data.toC7Data())
        self.delegate?.socket(socket:self, didWriteDataWithTag:tag)
      } catch {
        SLogError("writeData error")
        self.delegate?.socketDidDisconnect(socket:self,
          withError:nil)
      }
    }
    thread.start()
  }
}

extension NSData {
  func toC7Data() -> C7.Data {
    let start = UnsafePointer<UInt8>(self.bytes)
    let bytes = UnsafeBufferPointer<UInt8>(start: start, count: self.length)
    let array = Array<UInt8>(bytes) // <-- How do I stop this from copying?
    let data = Data(array)
    return data
  }
}

extension C7.Data {
  func toNSData() -> NSData {
    
    // This version does *not* make a copy, so it basically toll-free & is still safe
    let bytes = self.bytes
    let mutable = UnsafeMutablePointer<UInt8>(bytes)
    return NSData(bytesNoCopy: mutable, length: bytes.count, freeWhenDone: false)
    
    // Copying version below, just in case of issues
    //return NSData(bytes: bytes, length: bytes.count)
  }
}

