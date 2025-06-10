/**
 * @description SMSTrigger
 */
trigger SMSTrigger on SMS__c (after insert, after update) {
    Air_flow_users__c afcs = Air_flow_users__c.getInstance();
    if(String.isBlank(afcs.User_Id__c) || afcs.User_Id__c != String.ValueOf(UserInfo.getUserId()).substring(0,15)){
        SMSTriggerHandler.onAfterInsert();
    	SMSTriggerHandler.onAfterUpdate();
    }
    
}