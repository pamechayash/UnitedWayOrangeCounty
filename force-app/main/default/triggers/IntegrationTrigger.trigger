trigger IntegrationTrigger on Integration__c (before insert,before update) {
  IntegrationHelper.beforeIntegrationInsertAndUpdate(Trigger.new,Trigger.newMap, Trigger.oldMap);
}