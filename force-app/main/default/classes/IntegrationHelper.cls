public class IntegrationHelper {
    public static void beforeIntegrationInsertAndUpdate(List<Integration__c> newIntegrations,Map<Id,Integration__c> newMap,Map<Id,Integration__c> oldMap){
        List<Intake__c> intakesToInsert = new List<Intake__c>();
        Map<String, Account> existingAccountsMap = new Map<String, Account>();
        Integer intToUniquelyIdentify=0;
        List<Id> intakesToDeleteIds= new List<Id>();
        for (Integration__c integration : newIntegrations) {
            if(oldMap==null || (newMap.get(integration.Id).DxF_to_GetHelp_Put__c != oldMap.get(integration.Id).DxF_to_GetHelp_Put__c)){
            Intake__c intake = new Intake__c();
            if (integration.Type__c == 'Housing' && integration.DxF_to_GetHelp_Put__c!=null) {
                try {
                    Map<String, Object> payload;
                    
                    try {
                        payload = (Map<String, Object>) JSON.deserializeUntyped(integration.DxF_to_GetHelp_Put__c);
                    } catch (Exception e) {
                        integration.Status__c = 'Error';
                        integration.Message__c = e.getMessage();  
                        System.debug('Invalid JSON: ' + e.getMessage());
                        continue;
                    }
                    // Extract identity details
                    String firstName = (String) payload.get('FirstName');
                    String lastName = (String) payload.get('LastName');
                    Date birthdate = tryParseDate((String) payload.get('Birthdate'));
                    system.debug(firstName+' '+lastName+' '+birthdate);
                    // Try to find existing PersonAccount
                    Account client = findOrCreatePersonAccount(firstName, lastName, birthdate, payload);
                    
                    // Build Intake__c 
                    intake.Client__c = client.Id;
                    intake.Homeless_Type__c = 'Do not know';//(String) payload.get('HomelessType');
                    intake.Language__c = (String) payload.get('Language');
                    intake.Gender_Person_in_need__c = (String) payload.get('Gender');
                    intake.Intake_Type__c=  payload.get('IntakeType')==null?'Veteran':(String) payload.get('IntakeType');
                    intake.Intake_Status__c = 'Open';//(String) payload.get('IntakeStatus');
                    intake.Zip_Code__c = (String) payload.get('ZipCode');
                    intake.Racial_Ethnic_Identity__c =(String) payload.get('RaceOrEthnicity');           
                    if(payload.get('HouseholdSize')!=null){
                        intake.Total_Household_Members__c =  Integer.valueOf((String) payload.get('HouseholdSize'));
                    }                        
                    intake.Annual_Household_Income__c=Decimal.valueOf((String) payload.get('AnnualGrossHouseholdIncome'));
                    if(payload.get('NumberOfChildrenInHousehold')!=null){
                        intake.Number_of_children_05_in_household__c =  Integer.valueOf((String) payload.get('NumberOfChildrenInHousehold'));
                    }     
                    
                    intake.Has_Served_in_the_Military__c = (String) payload.get('MilitaryService');
                    intake.First_Name__c = (String) payload.get('FirstName');
                    intake.Last_Name__c = (String) payload.get('LastName');
                    intake.Birthdate__c = tryParseDate((String) payload.get('Birthdate'));
                    intake.Current_Living_Situation__c = (String) payload.get('CurrentLivingSituation');
                    intake.Do_you_have_a_safe_place_to_stay__c = (String) payload.get('SafePlaceToStayTonight');
                    intake.Status__c = 'Success';
                    
                    intakesToInsert.add(intake);
                    integration.Status__c='Success';
                    integration.Message__c = '';
                    
                }catch (exception e){
                    integration.Status__c = 'Error';
                    integration.Message__c = e.getMessage();
                    
                    system.debug('Error: '+e.getmessage());
                    continue;
                }
            }
        }
        }
        if (!intakesToInsert.isEmpty()) {
            try{
                insert intakesToInsert;
                Integer intakeIndex=0;
                for(Integration__c integration: newIntegrations){
                    if(integration.Status__c != 'Error'){
                        integration.Intake__c = intakesToInsert[intakeIndex].Id;
                        intakeIndex++;
                    }
                }   
            } catch (Exception ex){    
                system.debug('DML '+ex.getmessage());
            }
            
        }
        
    }
    
    private static Account findOrCreatePersonAccount(String firstName, String lastName, Date birthdate, Map<String, Object> payload) {
        List<Account> existing = [
            SELECT Id , FirstName , LastName FROM Account
            WHERE FirstName = :firstName AND LastName = :lastName AND PersonBirthdate = :birthdate
            AND IsPersonAccount = true
            LIMIT 1
        ];
        
        if (!existing.isEmpty()) {
            system.debug(existing[0].FirstName+' '+existing[0].LastName);
            return existing[0];
        }
        
        // Create PersonAccount
        Account newPerson = new Account();
        newPerson.FirstName = firstName;
        newPerson.LastName = lastName;
        newPerson.PersonBirthdate = birthdate;
        newPerson.RecordTypeId = getPersonAccountRecordTypeId();
        
        // Optional: additional fields
        newPerson.PersonMailingPostalCode = (String) payload.get('ZipCode');
        
        insert newPerson;
        return newPerson;
    }
    
    private static Date tryParseDate(String dateString) {
        if (String.isBlank(dateString)) return null;
        try {
            return Date.valueOf(dateString);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static Id getPersonAccountRecordTypeId() {
        return [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Person Account' LIMIT 1].Id;
    }
    
    
}