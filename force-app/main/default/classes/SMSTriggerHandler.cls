/**
 * This class controls the trigger actions
 */
public with sharing class SMSTriggerHandler {
    public static void onAfterInsert(){
        if (Trigger.isInsert && Trigger.isAfter) {
            Set<Id> smsIds= new Set<Id>(); 
            for(SMS__c sms:(List<SMS__c>)Trigger.New){
                if(sms.Status__c=='Send'){
                    smsIds.add(sms.Id);
                }
            }
            callAPIBatch(smsIds);
        }
    }
    public static void onAfterUpdate(){
        if (Trigger.isUpdate && Trigger.isAfter) {
            Set<Id> smsIds= new Set<Id>(); 
            Map<Id, SMS__c> oldValues = (Map<Id, SMS__c>)Trigger.oldMap;
            for(SMS__c sms:(List<SMS__c>)Trigger.New){
                if(oldValues.get(sms.Id).Status__c=='Draft' && sms.Status__c=='Send'){
                    smsIds.add(sms.Id);
                }
            }
            callAPIBatch(smsIds);
        }
    }
    public static void callAPIBatch(Set<Id> smsIds){
        if (smsIds.size() > 0){
            SMSRestApiBatch objbatch = new SMSRestApiBatch();
            objbatch.smsIds = smsIds;   
            Database.executeBatch(objbatch, 50);
        }
    }
}