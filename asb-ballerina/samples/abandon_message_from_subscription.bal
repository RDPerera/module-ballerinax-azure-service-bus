// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerinax/asb;

// Connection Configurations

configurable string connectionString = ?;
configurable string topicName = ?;
configurable string subscriptionName1 = ?;

// This sample demonstrates a scneario where azure service bus connecter is used to 
// send a message to a topic using topic sender, receive that message using subscription receiver with PEEKLOCK mode, 
// abadon that message (discards the message and relinquishes the message lock ownership),
// finally complete the processing of message using complete function of the caller. 
// After this point, we cannot futher perform operations on message.
public function main() returns error? {

    // Input values
    string stringContent = "This is My Message Body";
    byte[] byteContent = stringContent.toBytes();
    int timeToLive = 60; // In seconds
    int serverWaitTime = 60; // In seconds

    asb:ApplicationProperties applicationProperties = {
        properties: {a: "propertyValue1", b: "propertyValue2"}
    };

    asb:Message message1 = {
        body: byteContent,
        contentType: asb:TEXT,
        timeToLive: timeToLive,
        applicationProperties: applicationProperties
    };

    asb:ASBServiceSenderConfig senderConfig = {
        connectionString: connectionString,
        entityType: asb:TOPIC,
        topicOrQueueName: topicName
    };

    asb:ASBServiceReceiverConfig receiverConfig = {
        connectionString: connectionString,
        entityConfig: {
            topicName: topicName,
            subscriptionName: subscriptionName1
        },
        receiveMode: asb:PEEK_LOCK
    };

    log:printInfo("Initializing Asb sender client.");
    asb:MessageSender topicSender = check new (senderConfig);

    log:printInfo("Initializing Asb receiver client.");
    asb:MessageReceiver subscriptionReceiver = check new (receiverConfig);

    log:printInfo("Sending via Asb sender client.");
    check topicSender->send(message1);

    log:printInfo("Receiving from Asb receiver client.");
    asb:Message|error? messageReceived = subscriptionReceiver->receive(serverWaitTime);

    if (messageReceived is asb:Message) {
        check subscriptionReceiver->abandon(messageReceived);
        asb:Message|error? messageReceivedAgain = subscriptionReceiver->receive(serverWaitTime);
        if (messageReceivedAgain is asb:Message) {
            check subscriptionReceiver->complete(messageReceivedAgain);
            log:printInfo("Abandon message successful");
        } else {
            log:printError("Abandon message not succesful.");
        }
    } else if (messageReceived is ()) {
        log:printError("No message in the subscription.");
    } else {
        log:printError("Receiving message via Asb receiver connection failed.");
    }

    log:printInfo("Closing Asb sender client.");
    check topicSender->close();

    log:printInfo("Closing Asb receiver client.");
    check subscriptionReceiver->close();
}
