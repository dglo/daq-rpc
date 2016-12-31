import XCTest
@testable import daq_rpcTests

XCTMain([
     testCase(MsgPackTests.allTests),
     testCase(PyEvalEncoderTests.allTests),
])
