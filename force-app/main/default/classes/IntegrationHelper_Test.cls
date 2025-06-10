@isTest
public class IntegrationHelper_Test {


  Static Map<String, Object> jsonMap =new Map<String, Object>{
  'Timestamp'=> '1212000000000',
  'SourceId'=> '1232314',
  'Type'=> 'Housing',
  'ExternalId'=> '450025',
  'CaseOrigin'=> 'Referral',
  'CaseOwner'=> 'John Doe',
  'Language'=> 'English',
  'Date0fLastConsent'=> '2025-01-01',
  'ConsentType'=> 'ShareWithOthers',
  'ConsentExpirationDate'=> '2025-02-01',
  'Gender'=> 'Female',
  'Age'=> '34',
  'RaceOrEthnicity'=> 'Latino / Hispanic',
  'HealthCoverage'=> 'Medicaid',
  'HouseholdSize'=> '4',
  'AnnualGrossHouseholdIncome'=> '145000',
  'NumberOfChildrenInHousehold'=> '2',
  'MilitaryService'=> 'None',
  'FirstName'=> 'Test',
  'LastName'=> 'Account',
  'Birthdate'=> '1970-01-01',
  'IntakeType'=> 'Veteran',
  'IntakeStatus'=> 'Completed',
  'SafePlaceToStayTonight'=> 'Yes',
  'CurrentLivingSituation'=> 'Renting',
  'HomelessType'=> 'Not Applicable',
  'Client'=> 'true',
  'ZipCode'=> '90210',
  'AnyField'=> 'Any Value'
};
    @isTest
    static void testValidHousingIntegration() {
        // Prepare valid JSON payload
         jsonMap.put('FirstName' , 'TestFName');
          jsonMap.put('LastName' , 'TestLName');
         jsonMap.put('Birthdate' , '1911-06-20');
        String validPayload = JSON.serialize(jsonMap);

        Integration__c integration = new Integration__c(
            Type__c = 'Housing',
            DxF_to_GetHelp_Put__c = validPayload
        );
        insert integration;


        // Reload updated record
        Integration__c updatedIntegration = [SELECT Intake__c, Status__c, Message__c FROM Integration__c WHERE Id = :integration.Id];
        System.assertEquals('Success', updatedIntegration.Status__c);
        System.assertNotEquals(null, updatedIntegration.Intake__c);

        Intake__c createdIntake = [SELECT Id, Client__c FROM Intake__c WHERE Id = :updatedIntegration.Intake__c];
        System.assertNotEquals(null, createdIntake.Client__c);
    }

    @isTest
    static void testInvalidJsonIntegration() {
        Integration__c integration = new Integration__c(
            Type__c = 'Housing',
            DxF_to_GetHelp_Put__c = '{bad json'
        );
        insert integration;


        Integration__c updated = [SELECT Status__c, Message__c FROM Integration__c WHERE Id = :integration.Id];
        System.assertEquals('Error', updated.Status__c);
        System.assert(updated.Message__c != null && updated.Message__c.contains('Unexpected character'));
    }



    @isTest
    static void testExistingPersonAccount() {
        // Create existing Person Account
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Person Account' LIMIT 1];
        Account existing = new Account(
            FirstName = 'Test',
            LastName = 'Account',
            PersonBirthdate = Date.newInstance(1970, 1, 1),
            RecordTypeId = rt.Id
        );
        insert existing;

        String payload = JSON.serialize(jsonMap);

        Integration__c integration = new Integration__c(
            Type__c = 'Housing',
            DxF_to_GetHelp_Put__c = payload
        );
        insert integration;

       

        Integration__c updated = [SELECT Status__c, Intake__c FROM Integration__c WHERE Id = :integration.Id];
        Intake__c intake = [SELECT Client__c FROM Intake__c WHERE Id = :updated.Intake__c];
        System.assertEquals(existing.Id, intake.Client__c);
    }
    @isTest
    static void testWrongIntakeValue() {
        jsonMap.put('AnnualGrossHouseholdIncome', 'T145000');
         String payload = JSON.serialize(jsonMap);

        Integration__c integration = new Integration__c(
            Type__c = 'Housing',
            DxF_to_GetHelp_Put__c = payload
        );
        insert integration;
                Integration__c updated = [SELECT Status__c, Message__c FROM Integration__c WHERE Id = :integration.Id];
          System.assertEquals('Error', updated.Status__c);
          jsonMap.put('AnnualGrossHouseholdIncome', '145000');
    }
       @isTest
    static void testDMLExceptionCatch() {
        jsonMap.put('CurrentLivingSituation', 'Apartment Renting'); //bad value for picklist
         String payload = JSON.serialize(jsonMap);

        Integration__c integration = new Integration__c(
            Type__c = 'Housing',
            DxF_to_GetHelp_Put__c = payload
        );
        insert integration;        
    }
    
    
}