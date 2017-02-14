/*
      Licensed Materials - Property of IBM
      © IBM Corp. 2016
*/
var urlopen = require('urlopen');
var apic = require('local:isp/policy/apim.custom.js');
var props = apic.getPolicyProperty();

function APICMQErrorHelper(name, message, code) {

    if (!code) {
        code = 400;
    }

    apic.error(name, code, message, "Please refer to the datapower log for more information")
}

function NoQueueFoundException(responseCode, queue) {
    return APICMQErrorHelper("NoQueueFoundException", "APICMQ001 : Response code '" + responseCode + "' was received when connecting to a either a request or response queue . Please check the Queue name is correct.", 404);
}

function NoQueueManagerFoundException(queueManagerObjectName) {
    return APICMQErrorHelper("NoQueueManagerFoundException", "APICMQ002 : API Connect was unable to find a QueueManager Object with the name '" + queueManagerObjectName + "'", 404);
}

function ResponseTimeOutException() {
    return APICMQErrorHelper("ResponseTimeOutException", "APICMQ004 : A response was not received in the given time. ", 408);
}

function InvalidSOAPResponse(SOAPResponse) {
    return APICMQErrorHelper("InvalidSOAPResponse", "APICMQ005 : Invalid SOAP Response  : Please check the BackOut Queue for the message", 400);
}

function InvalidRequest(SOAPResponse) {
    return APICMQErrorHelper("InvalidResponse", "APICMQ006 : Error occured when reading the input was the inputData XML or JSON", 400);
}

function NoBOQ() {
    return APICMQErrorHelper("NOBackOutQueue", "APICMQ007 : No Backout Queue Specified", 400);
}

function MessageOnBoQ(data, response) {

    if (boq == '') {
        NoBOQ();
    }
    var h = response.get({
        type: 'mq'
    }, 'MQMD')
    var newBOC = h.MQMD.BackoutCount.$ + 1
    h.MQMD.BackoutCount = {
        $: newBOC
    }
    var options = {
        target: boqURL,
        data: data,
        headers: {
            MQMD: h
        }
    };

    urlopen.open(options, function(connectError, res) {
        if (connectError) {
            APICMQErrorHelper("ErrorPuttingMessageOnBO", connectError, 400);
        }
        console.error(res.get({
            type: 'mq'
        }, 'MQMD'));
        console.error(res)
    });
}

function process(xml) {
    var options = {
        target: mqURL,
        data: xml,
        // messagetype: MsgType,
        headers: {
            MQMD: { // JSON object for specified header_name
                MQMD: {
                    MsgType: {
                        "$": MsgType
                    },
                    ReplyToQ: {
                        "$": ReplyToQ
                    }
                }
            }
        }
    }
    //Try to open the mqURL
    try {

        urlopen.open(options, function(connectError, res) {
            if (res) {
                console.critical('Received MQ ' + res.statusCode + ' for target ' + options.target);
            }
            if (connectError) {
                NoQueueManagerFoundException(qm)
            } else if (res.statusCode === 0) {
                if (respq == '') {
                    var mqmd = XML.parse(res.get('MQMD'));
                    console.debug(mqmd);
                    apic.output('application/xml');
                    session.output.write(mqmd);
                } else {
                    res.readAsXML(function(readAsXMLError, xmlDom) {
                        if (readAsXMLError) {
                            res.readAsJSON(function(readAsJSONError, jsonObj) {
                                if (readAsJSONError) {
                                    res.readAsBuffer(function(readAsBufferError, buffer) {
                                        console.error("Unable to read response as XML or JSON");
                                        if (!readAsBufferError) {
                                            MessageOnBoQ(buffer, res);
                                            InvalidSOAPResponse();
                                        } else {
                                            InvalidSOAPResponse("Error : " + readAsBufferError);
                                        }
                                    });
                                } else {
                                    console.critical(jsonObj);
                                    // apic.output('application/json');
                                    session.output.write(jsonObj);
                                }
                            });
                        } else {
                            apic.output('application/xml');
                            session.output.write(xmlDom);
                        }
                    });
                }
            } else if (res.statusCode === 2085) {
                NoQueueFoundException(2085, reqq)
            } else if (res.statusCode === 2059) {
                NoQueueManagerFoundException(qm)
            } else if (res.statusCode === 2033) {
                ResponseTimeOutException()
            } else {
                res.readAsBuffer(function(readAsBufferError, buffer) {
                    console.critical("Attempting to parse the response message to put on the BackOut Queue");
                    if (!readAsBufferError) {
                        MessageOnBoQ(buffer, res.headers);
                    }
                });
                var errorMessage = 'Thrown error on urlopen.open for target ' + options.target + ':   statusCode:' + res.statusCode
                APICMQErrorHelper("Unknown Error", errorMessage, 400)
            }

        });
    } catch (error) {
        var errorMessage = 'Thrown error on urlopen.open for target ' + options.target + ': ' + error.message + ', error object errorCode=' + error.errorCode.toString();
        APICMQErrorHelper("Unknown Error", errorMessage, 400)
    }
}


var qm = props.queuemanager
var boq = props.backoutq
var reqq = props.queue
var respq = props.replyqueue
var timeout = props.timeout

var mqURL = "unset"
var MsgType = -1;
var ReplyToQ = "";
if (respq == '') {
    MsgType = 8
    mqURL = 'dpmq://' + qm + '/?RequestQueue=' + reqq + ';timeout=' + timeout
} else {
    MsgType = 1
    ReplyToQ = respq
    mqURL = 'dpmq://' + qm + '/?RequestQueue=' + reqq + ';ReplyQueue=' + respq + ';timeout=' + timeout
}
var boqURL = 'dpmq://' + qm + '/?RequestQueue=' + boq + ';timeout=' + timeout

var outputObject = {};

//Read the payload as XML
apic.readInputAsXML(function(readError, xml) {
    if (readError) {
        apic.readInputAsJSON(function(readError, json) {
            if (readError) {
                InvalidRequest();
            } else {
                process(json)
            }
        });
    } else {
        process(xml)
    }
});
