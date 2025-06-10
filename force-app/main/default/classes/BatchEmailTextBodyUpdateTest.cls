@isTest
public with sharing class BatchEmailTextBodyUpdateTest {

    @TestSetup
    static void makeData(){
        // Creating Taxonomies
        for (Integer i = 0; i < 5; i++){
            Taxonomy__c parent = new Taxonomy__c();
            parent.Name = 'Basic Needs' + String.valueOf(i);
            parent.Code__c = String.valueOf(i);
            parent.Level__c = 1;
            insert parent;
        }
        List<Taxonomy__c> parentsList = [SELECT Id, Name FROM Taxonomy__c WHERE Name = 'Basic Needs0' LIMIT 1];
        createTreeChilds(parentsList[0].Id);

        Account accForService = new Account();
        accForService.Name = 'Agency Test';
        accForService.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId();
        accForService.Active_Status__c = 'Active';
        insert accForService;

        Zip_Code__c zipC = new Zip_Code__c();
        zipC.Name = 'ZIP Code 10014';
        zipC.Zip_Code__c = '10014';
        insert zipC;

        // Creating Services without locations
        for (Integer i = 0; i < 5; i++) {
            Service__c serv = new Service__c();
            serv.Name = 'Service ' + i;
            serv.Agency__c = accForService.Id;
            serv.Description__c = 'Description__c test';
            serv.Veteran_Specialty__c = 'Veteran';
            serv.Status__c = 'Active';
            serv.Email_Text_Body__c = 'Test @211oc.org';
            insert serv;

            Service_Taxonomy__c serTax = new Service_Taxonomy__c();
            serTax.Taxonomy__c = parentsList[0].Id;
            serTax.Service__c = serv.Id;
            insert serTax;

            Service_Zip_Code__c serZip = new Service_Zip_Code__c();
            serZip.Zip_Code__c = zipC.Id;
            serZip.Service__c = serv.Id;
            insert serZip;
        }

        Site__c siteR = new Site__c();
        siteR.Agency__c = accForService.Id;
        siteR.Name = accForService.Name + ' Site';
        siteR.Physical_Geolocation__latitude__s = 40.733821830927724;
        siteR.Physical_Geolocation__longitude__s = -74.00563113591113;
        insert siteR;


        // Creating Services with locations
        for (Integer i = 0; i < 5; i++) {
            Service__c serv = new Service__c();
            serv.Name = 'ServiceLoc' + i;
            serv.Agency__c = accForService.Id;
            serv.Description__c = 'Description__c Loc test';
            serv.Veteran_Specialty__c = 'Veteran';
            serv.Status__c = 'Active';
            serv.Email_Text_Body__c = 'Test @211oc.org';
            insert serv;

            Service_Taxonomy__c serTax = new Service_Taxonomy__c();
            serTax.Taxonomy__c = parentsList[0].Id;
            serTax.Service__c = serv.Id;
            insert serTax;

            Service_Zip_Code__c serZip = new Service_Zip_Code__c();
            serZip.Zip_Code__c = zipC.Id;
            serZip.Service__c = serv.Id;
            insert serZip;

            Service_Site__c serSite = new Service_Site__c();
            serSite.Service__c = serv.Id;
            serSite.Site__c = siteR.Id;
            insert serSite;

        }
    }

    private static void createTreeChilds(String parentId) {
        // Level 2
        Taxonomy__c childlevel2 = new Taxonomy__c();
        childlevel2.Name = 'Child-Tax 2';
        childlevel2.Code__c = '02';
        childlevel2.Level__c = 2;
        childlevel2.Level_1L__c = parentId;
        childlevel2.Higher_Taxonomies__c = parentId;
        insert childlevel2;

        // Level 3
        Taxonomy__c childlevel3 = new Taxonomy__c();
        childlevel3.Name = 'Child-Tax 3';
        childlevel3.Code__c = '02-3';
        childlevel3.Level__c = 3;
        childlevel3.Level_2L__c = childlevel2.Id;
        childlevel3.Higher_Taxonomies__c = childlevel2.Higher_Taxonomies__c + ',' + childlevel2.Id;
        insert childlevel3;
    }

    @IsTest
    static void testBatch(){
        
        Test.startTest();
        Database.executeBatch(new BatchEmailTextBodyUpdate());
        Test.stopTest();

        List<Service__c> services = [SELECT Id, Email_Text_Body__c FROM Service__c];

        for(Service__c service : services){
            System.assertEquals(service.Email_Text_Body__c.contains('@unitedwayoc.org'), true);
        }
        
    }
}