/**
 * Test if the SMS__c trigger is working correctly
 */
@isTest
public with sharing class SMSTriggerHandlerTest {

    @isTest 
    static void onAfterInsertTrigger() {
        Test.setMock(HttpCalloutMock.class, new SMSRestApiMock());
        SMS__c sms = new SMS__c(Body__c='TestBody',
                                Phone_Number__c='12099216581',
                                Status__c = 'Send');
        Test.startTest();
        insert sms;
        Test.stopTest();
        // after the testing stops, assert records were updated properly
        List<AsyncApexJob> aajList = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors FROM AsyncApexJob];
        List<SMS__c> insertedSMS = [SELECT Id, Name, Status__c FROM SMS__c WHERE Id =:sms.Id LIMIT 1];
        System.assertEquals('Sent', insertedSMS[0].Status__c, 'The current state should now be set to "Sent"');
        System.assert(aajList.size() > 0, 'The number of Async Apex Job should be more than zero');
    }
    @isTest 
    static void onAfterUpdateTrigger() {
        Test.setMock(HttpCalloutMock.class, new SMSRestApiMock());
        SMS__c sms = new SMS__c(BodyLong__c ='TestBody',
                                Phone_Number__c='12099216581',
                                Status__c = 'Draft');
        insert sms;

        Test.startTest();
        sms.Status__c = 'Send';
        update sms;
        Test.stopTest();
        // after the testing stops, assert records were updated properly
        List<AsyncApexJob> aajList = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors FROM AsyncApexJob];
        List<SMS__c> insertedSMS = [SELECT Id, Name, Status__c FROM SMS__c WHERE Id =:sms.Id LIMIT 1];
        System.assertEquals('Sent', insertedSMS[0].Status__c, 'The current state should now be set to "Sent"');
        System.assert(aajList.size() > 0, 'The number of Async Apex Job should be more than zero');
    }
}