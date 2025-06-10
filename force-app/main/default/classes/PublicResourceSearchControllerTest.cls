@isTest
public with sharing class PublicResourceSearchControllerTest {
    public PublicResourceSearchControllerTest() {

    }

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
    static void getInitialFiltersTest(){
        
        Test.startTest();
        PublicResourceSearchController.getInitialFilters('Basic Needs0');
        Test.stopTest();
        
    }

    @IsTest
    static void searchResourcesTest(){
        Test.setMock(HttpCalloutMock.class, new GetCoordinatesMock()); 
        Taxonomy__c tax = [SELECT Id FROM Taxonomy__c WHERE Level__c = 1 LIMIT 1];
        Case resourceSearchCase =  new Case(Status = 'Closed', Subject = 'Public Resource Search');
        PublicResourceSearchController.SearchFilter searchFilterDistance = new PublicResourceSearchController.SearchFilter();
        searchFilterDistance.agency = 'Service 0';
        searchFilterDistance.city = 'Test';
        searchFilterDistance.postalCode = '10014';
        searchFilterDistance.radius = '100';
        searchFilterDistance.street = 'Test';
        searchFilterDistance.sortedBy = 'Distance';
        PublicResourceSearchController.SearchFilter searchFilterRelevance = new PublicResourceSearchController.SearchFilter();
        searchFilterRelevance.agency = 'Service 0';
        searchFilterRelevance.city = '';
        searchFilterRelevance.postalCode = '10014';
        searchFilterRelevance.radius = '';
        searchFilterRelevance.street = '';
        searchFilterRelevance.sortedBy = 'Relevance';
        Test.startTest();
        PublicResourceSearchController.searchResources(JSON.serialize(PublicResourceSearchController.getFilters()), JSON.serialize(searchFilterDistance), resourceSearchCase.Id);
        PublicResourceSearchController.searchResources(JSON.serialize(PublicResourceSearchController.getFilters()), JSON.serialize(searchFilterRelevance), resourceSearchCase.Id);
        Test.stopTest();
        
    }

    public class Taxonomy {
        @Auraenabled public String taxonomyId {get;set;}
        @Auraenabled public String taxonomyName {get;set;}
        @Auraenabled public Decimal taxonomyLevel {get;set;}

        public Taxonomy(Taxonomy__c taxo){
            this.taxonomyId = taxo.Id;
            this.taxonomyName = taxo.Name_and_Code__c;
            this.taxonomyLevel = taxo.Level__c;
        }

    }

    @IsTest
    static void testQueueHandler(){
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())){
            Group newQueue = new Group(
                Name = '1. Anonymous Search Owners', 
                Type = 'Queue'
            );
            insert newQueue;

            System.enqueueJob(new PublicSearchQueueHandler(newQueue.Id));
        }
        Test.stopTest();
        
    }
}