/**
 * Class that uses Batch to perform various calls to a REST API to send SMS
 */
global class SMSRestApiBatch implements
    Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    // instance member to retain state across transactions
    public Set<Id> smsIds;
    public String message = '';
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Phone_Number__c, BodyLong__c FROM SMS__c WHERE Id IN :smsIds]);
    }
    global void execute(Database.BatchableContext bc, List<SMS__c> smsList){
        // process each batch of records
        for(SMS__c sms : smsList){
            HttpResponse response = SMSRestApiController.makeSMSRestCalloutFormData(sms);
            SMSRestApiController.ApiResponse apiConvert = (SMSRestApiController.ApiResponse)JSON.deserializeStrict(
                response.getBody(),
                SMSRestApiController.ApiResponse.class);
            if (!apiConvert.success.isEmpty()) {
                sms.Status__c = 'Sent';
            }
        }
        update smsList;
    }
    global void finish(Database.BatchableContext bc){
        return;
    }
}