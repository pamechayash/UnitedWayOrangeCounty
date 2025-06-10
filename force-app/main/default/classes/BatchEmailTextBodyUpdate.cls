public without sharing class BatchEmailTextBodyUpdate implements Database.Batchable<Service__c>, Database.Stateful{
    public List<String> errors = new List<String>();

    public BatchEmailTextBodyUpdate() {
        this.errors = new List<String>();
    }

    public List<Service__c> start(Database.BatchableContext bc){
        return [SELECT Id, Email_Text_Body__c
                FROM Service__c];
    }

    public void execute(Database.BatchableContext bc, List<Service__c> services){
        List<Service__c> servicesToUpdate = new List<Service__c>();
        for(Service__c service : services){
            if(service.Email_Text_Body__c != null && service.Email_Text_Body__c.contains('@211oc.org')){
                service.Email_Text_Body__c = service.Email_Text_Body__c.replace('@211oc.org','@unitedwayoc.org');
                servicesToUpdate.add(service);
            }
        }
        if(!servicesToUpdate.isEmpty()){
            List<Database.SaveResult> saveResult = Database.update(servicesToUpdate, false);
            for(Database.SaveResult result : saveResult){
                if(!result.isSuccess()){
                    for(Database.Error err : result.getErrors()){
                        this.errors.add(result.getId() + ',' + err.getFields() + ',' + err.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc){
        if(!this.errors.isEmpty() || Test.isRunningTest()){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{'anne.powell+ocuw@arkusinc.com'});
            mail.setSubject('Errors from BatchEmailTextBodyUpdate');
            mail.setPlainTextBody(String.join(this.errors, '\n'));
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
    }
}