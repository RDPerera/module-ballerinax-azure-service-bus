// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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
import ballerina/lang.runtime;
import ballerina/test;

Duration maxPeekLockDue = {
    seconds: 30,
    nanoseconds: 0
};
int ttl_serverwt = 60;


Message testMessage = {
    body: byteContent,
    contentType: TEXT,
    timeToLive: ttl_serverwt
};

ASBServiceSenderConfig testSender = {
    connectionString: connectionString,
    entityType: QUEUE,
    topicOrQueueName: testQueue5
};

ASBServiceReceiverConfig testReceiver = {
    connectionString: connectionString,
    entityConfig: {
        queueName: testQueue5
    },
    receiveMode: PEEK_LOCK
};
string testTopic3 = "topic3";
string testQueue5 = "queue5";
string nonExistingName = "nonExistingTopicName";
string invalidName = "#TEST";
string testSubscription3 = "subscription3";
string testRule3 = "rule3";
string testQueue3 = "queue3";
string duplicateTopicQueueErrorPrefix = string `Error occurred while processing request: SubCode=40900. Conflict. You're requesting an operation that isn't allowed in the resource's current state. To know more visit https://aka.ms/sbResourceMgrExceptions.`;
string duplicateSubscriptionErrorPrefix = string `Error occurred while processing request: The messaging entity`;
string duplicateRuleErrorPrefix = string `Error occurred while processing request: The messaging entity`;
string nonExistingQueueError = string `error("Error occurred while processing request: Queue '${nonExistingName}' does not exist.",error("com.azure.core.exception.ResourceNotFoundException: Queue '${nonExistingName}' does not exist."))`;
string nonExistingTopicError = string `error("Error occurred while processing request, Status Code:200",error("com.azure.core.exception.ResourceNotFoundException: Topic '${nonExistingName}' does not exist."))`;
string nonExistingSubscriptionErrorPrefix = string `Error occurred while processing request: Entity `;
string nonExistingRuleErrorPrefix = string `error("Error occurred while processing request, Status Code:404",error("com.azure.core.exception.ResourceNotFoundException: Entity`;
string invalidNameErrorPrefix = string `Error occurred while processing request: SubCode=40000.`;
string invalidSubscriptionNameErrorPrefix = string `Error occurred while processing request:`;
string invalidRuleNameErrorPrefix = string `Error occurred while processing request: 'sb://`;

@test:Config {
    groups: ["asb_admin_negative"],
    enable: true
}
function testLockExpire() returns error?{
    log:printInfo("[[testLockExpiration]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);
    QueueProperties? testQueue = check adminClient->createQueue(testQueue5,lockDuration = maxPeekLockDue);
    test:assertTrue(testQueue is QueueProperties, msg = "Queue creation failed.");

    log:printInfo("Initializing Asb sender client.");
    MessageSender sender = check new (testSender);

    log:printInfo("Initializing Asb receiver client.");
    MessageReceiver receiver = check new (testReceiver);

    log:printInfo("Sending via Asb sender client.");
    check sender->send(testMessage);

    log:printInfo("Receiving from Asb receiver client.");
    Message|Error? messageReceived = receiver->receive(ttl_serverwt);

    if (messageReceived is Message) {
        log:printInfo("Message received.");

        log:printInfo("Waiting for 35 seconds to ensure the message is deleted from the queue.");
        runtime:sleep(35);

        log:printInfo("Completing the message.");
        error? e = receiver->complete(messageReceived);
        if (e is error) {
            test:assertTrue(e.message().startsWith("ASB Error: Message lockToken:"),"Incorrect exception message for lock expiration failure.");
        } else {
            test:assertFail(msg = "The lock expiration mechanism is not working properly.");
        }
    } else {
        test:assertFail(msg = "Message receive failed.");
    }

    log:printInfo("Closing Asb sender client.");
    check sender->close();

    log:printInfo("Closing Asb receiver client.");
    check receiver->close();
    
    log:printInfo("Deleting the queue.");
    check adminClient->deleteQueue(testQueue5);
}
@test:Config {
    groups: ["asb_admin_negative"],
    enable: true
}
function testCreateQTSR() returns error? {
    log:printInfo("[[testCreateQueue/Topic/Subscription/Rule]]");
    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    TopicProperties? topicProp = check adminClient->createTopic(testTopic3);
    QueueProperties? queueProp = check adminClient->createQueue(testQueue3);
    SubscriptionProperties? subProp = check adminClient->createSubscription(testTopic3, testSubscription3);
    RuleProperties? ruleProp = check adminClient->createRule(testTopic3, testSubscription3, testRule3);
    test:assertTrue(topicProp is TopicProperties && queueProp is QueueProperties && subProp is SubscriptionProperties && ruleProp is RuleProperties, msg = "Topic, Queue, Subscription and Rule creation failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testDuplicateTopicCreation() returns error? {
    log:printInfo("[[testDuplicateTopicCreation]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);
    TopicProperties|Error? failedReq = adminClient->createTopic(testTopic3);
    test:assertTrue(failedReq is Error, msg = "Duplicate creation failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(duplicateTopicQueueErrorPrefix), msg = "Duplicate creation message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testDuplicateQueueCreation() returns error? {
    log:printInfo("[[testDuplicateQueueCreation]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    QueueProperties|Error? failedReq = adminClient->createQueue(testQueue3);
    test:assertTrue(failedReq is Error, msg = "Duplicate creation failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(duplicateTopicQueueErrorPrefix), msg = "Duplicate creation message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testDuplicateSubscriptionCreation() returns error? {
    log:printInfo("[[testDuplicateSubscriptionCreation]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    SubscriptionProperties|Error? failedReq = adminClient->createSubscription(testTopic3, testSubscription3);
    test:assertTrue(failedReq is Error, msg = "Duplicate creation failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(duplicateSubscriptionErrorPrefix), msg = "Duplicate creation message failed.");

}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testDuplicateRuleCreation() returns error? {
    log:printInfo("[[testDuplicateRuleCreation]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    RuleProperties|Error? failedReq = adminClient->createRule(testTopic3, testSubscription3, testRule3);
    test:assertTrue(failedReq is Error, msg = "Duplicate creation failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(duplicateRuleErrorPrefix), msg = "Duplicate creation message failed.");

}

@test:Config {
    groups: ["asb_admin_negative"],
    enable: true
}
function testGetNonExistingTopic() returns error? {
    log:printInfo("[[testGetNonExistingTopic]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    TopicProperties|Error? failedReq = adminClient->getTopic(nonExistingName);
    test:assertTrue(failedReq is Error, msg = "Get non existing topic failed.");
    test:assertEquals((<Error>failedReq).toString(), nonExistingTopicError);
}

@test:Config {
    groups: ["asb_admin_negative"],
    enable: true
}
function testGetNonExistingQueue() returns error? {
    log:printInfo("[[testGetNonExistingQueue]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    QueueProperties|Error? failedReq = adminClient->getQueue(nonExistingName);
    test:assertTrue(failedReq is Error, msg = "Get non existing queue failed.");
    test:assertEquals((<Error>failedReq).toString(), nonExistingQueueError);
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testGetNonExistingSubscription() returns error? {
    log:printInfo("[[testGetNonExistingSubscription]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    SubscriptionProperties|Error? failedReq = adminClient->getSubscription(testTopic3, nonExistingName);
    test:assertTrue(failedReq is Error, msg = "Get non existing subscription failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(nonExistingSubscriptionErrorPrefix), msg = "Get non existing subscription message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testGetNonExistingRule() returns error? {
    log:printInfo("[[testGetNonExistingRule]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    RuleProperties|Error? failedReq = adminClient->getRule(testTopic3, testSubscription3, nonExistingName);
    test:assertTrue(failedReq is Error, msg = "Get non existing rule failed.");
    test:assertTrue((<Error>failedReq).toString().startsWith(nonExistingRuleErrorPrefix), msg = "Get non existing rule message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    enable: true
}
function testCreateInvalidTopic() returns error? {
    log:printInfo("[[testCreateInvalidTopic]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    TopicProperties|Error? failedReq = adminClient->createTopic(invalidName);
    test:assertTrue(failedReq is Error, msg = "Create invalid topic failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(invalidNameErrorPrefix), msg = "Create invalid topic message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    enable: true
}
function testCreateInvalidQueue() returns error? {
    log:printInfo("[[testCreateInvalidQueue]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    QueueProperties|Error? failedReq = adminClient->createQueue(invalidName);
    test:assertTrue(failedReq is Error, msg = "Create invalid queue failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(invalidNameErrorPrefix), msg = "Create invalid queue message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testCreateInvalidSubscription() returns error? {
    log:printInfo("[[testCreateInvalidSubscription]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    SubscriptionProperties|Error? failedReq = adminClient->createSubscription(testTopic3, invalidName);
    test:assertTrue(failedReq is Error, msg = "Create invalid subscription failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(invalidSubscriptionNameErrorPrefix), msg = "Create invalid subscription message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testCreateInvalidRule() returns error? {
    log:printInfo("[[testCreateInvalidRule]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    RuleProperties|Error? failedReq = adminClient->createRule(testTopic3, testSubscription3, invalidName);
    test:assertTrue(failedReq is Error, msg = "Create invalid rule failed.");
    test:assertTrue((<Error>failedReq).message().startsWith(invalidRuleNameErrorPrefix), msg = "Create invalid rule message failed.");
}

@test:Config {
    groups: ["asb_admin_negative"],
    dependsOn: [testCreateQTSR],
    enable: true
}
function testDeleteQTSR() returns error? {
    log:printInfo("[[testDeleteQueue/Topic/Subscription/Rule]]");

    log:printInfo("Initializing Asb admin client.");
    Administrator adminClient = check new (connectionString);

    check adminClient->deleteTopic(testTopic3);
    check adminClient->deleteQueue(testQueue3);
    log:printInfo("Topic, Queue, Subscription and Rule deleted successfully.");
}
