@isTest
public with sharing class ResourceSearchControllerTest {

    
    private static void createData(){
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

    @isTest
    public static void getLevel1TaxonomiesTest() {
        createData();
        List<ResourceSearchController.Taxonomy> taxonomiesLevel1 = ResourceSearchController.getLevel1Taxonomies();
        System.assertEquals(5, taxonomiesLevel1.size(), 'The list should contains 5 records');
    }

    @isTest
    public static void getLowerLevelTaxonomiesTest() {
        createData();
        Taxonomy__c parent = [SELECT Id, Name, Level__c FROM Taxonomy__c WHERE Name = 'Basic Needs0' LIMIT 1];
        List<ResourceSearchController.TaxonomyChild> taxonomiesChilds = ResourceSearchController.getLowerLevelTaxonomies(parent.Id, Integer.valueOf(parent.Level__c));
        System.assertEquals(1, taxonomiesChilds.size(), 'The list should contains 1 record childs that belongs to the level 2 child');
    }

    @isTest
    public static void searchReferralsTestByRelevance() {
        createData();
        Taxonomy__c parent = [SELECT Id, Name, Level__c FROM Taxonomy__c WHERE Name = 'Basic Needs0' LIMIT 1];
        Map<String, Object> obj = new Map<String, Object>();
        obj.put('taxonomy', parent.Id);
        obj.put('zipCode', '10014');
        obj.put('sortByDistance', false);
        obj.put('Veteran_Specialty__c', 'Veteran');
        String inputs = JSON.serialize(obj);
        ResourceSearchController.ReferralResults referralResults = ResourceSearchController.searchReferrals(inputs);
        System.assertEquals(10, referralResults.data.size(), 'The list should contains 5 services');
    }

    @isTest
    public static void searchReferralsTestByDistance() {
        createData();
        Taxonomy__c parent = [SELECT Id, Name, Level__c FROM Taxonomy__c WHERE Name = 'Basic Needs0' LIMIT 1];
        Map<String, Object> obj = new Map<String, Object>();
        obj.put('taxonomy', parent.Id);
        obj.put('sortByDistance', true);
        obj.put('zipCode', '10014');
        obj.put('radio', '100');
        obj.put('Veteran_Specialty__c', 'Veteran');
        
        Map<String, Object> location = new Map<String, Object>();
        location.put('PostalCode', '10014');
        location.put('Country', 'USA');
        
        obj.put('location', location);
        String inputs = JSON.serialize(obj);
        Test.setMock(HttpCalloutMock.class, new GetCoordinatesMock());  
        Test.startTest();
        ResourceSearchController.ReferralResults referralResults = ResourceSearchController.searchReferrals(inputs);
        Test.stopTest();
        System.assertEquals(5, referralResults.data.size(), 'The list should contains 5 services');
    }

    @isTest
    public static void findTaxonomyTest() {
        createData();
        List<Taxonomy__c> taxList = [SELECT Id, Name, Level__c FROM Taxonomy__c];
        
        Test.startTest();
        List<ResourceSearchController.Taxonomy> results = ResourceSearchController.findTaxonomy();
        Test.stopTest();
        System.assertEquals(taxList.size(), results.size(), 'The list should contains 10 services');
    }

    @isTest(SeeAllData=true)
    public static void getServiceObjFilterValuesTest() {

        Map<String, Resource_Search_Filter__mdt > mapCMDT = Resource_Search_Filter__mdt.getAll();
        
        Test.startTest();
        ResourceSearchController.ServiceFilters results = ResourceSearchController.getServiceObjFilterValues();
        Test.stopTest();

        Integer result = results.multiSelectPicklists.size() + results.nonMultiSelectPicklists.size() + results.nonMultiSelectPicklistsHMG.size();
        
        System.assertEquals(mapCMDT.size(), result, 'The list should contains the same quantity of records');
    }

    @IsTest
    static void getSearchLogsTest(){
        Case newCase = new Case(
            Subject = 'Test'
        );
        insert newCase;

        insert new Search_Log__c(
            Zip_Code__c = 'Test',
            Taxonomy_Name__c = 'Test',
            Type__c = 'Log',
            Case__c = newCase.Id
        );
        List<ResourceSearchController.RecentSearch> searchs = new List<ResourceSearchController.RecentSearch>();

        Test.startTest();
            searchs = ResourceSearchController.getSearchLogs(newCase.Id);
        Test.stopTest();
        
        System.assertEquals(false, searchs.isEmpty());
    }

    @IsTest
    static void getSearchRecomendationsTest(){
        Case newCase = new Case(
            Subject = 'Test'
        );
        insert newCase;

        insert new Search_Log__c(
            Zip_Code__c = 'Test',
            Taxonomy_Name__c = 'Test',
            Type__c = 'Recommended',
            Case__c = newCase.Id,
            Recommendation_Title__c = 'Test'
        );
        List<ResourceSearchController.RecentSearch> searchs = new List<ResourceSearchController.RecentSearch>();

        Test.startTest();
            searchs = ResourceSearchController.getSearchRecomendations(newCase.Id);
        Test.stopTest();
        
        System.assertEquals(false, searchs.isEmpty());
    }

    @IsTest
    static void getSearchTermsTest(){
        Case newCase = new Case(
            Subject = 'Test'
        );
        insert newCase;

        insert new Common_Search_Term__c(
            Name = 'Test',
            Active__c = true
        );
        List<String> searchs = new List<String>();

        Test.startTest();
            searchs = ResourceSearchController.getSearchTerms();
        Test.stopTest();
        
        System.assertEquals(false, searchs.isEmpty());
    }

    @IsTest
    static void getRecommendedLogTest(){
        Case newCase = new Case(
            Subject = 'Test'
        );
        insert newCase;

        Taxonomy__c parent = new Taxonomy__c();
        parent.Name = 'Basic Needs Test';
        parent.Code__c = '1';
        parent.Level__c = 1;
        insert parent;

        Search_Log__c sl = new Search_Log__c(
            Zip_Code__c = 'Test',
            Taxonomy_Name__c = [SELECT Id, Name FROM Taxonomy__c WHERE Name = 'Basic Needs Test' LIMIT 1].Name,
            Type__c = 'Recommended',
            Case__c = newCase.Id,
            Recommendation_Title__c = 'Test'
        );
        insert sl;

        ResourceSearchController.RecommendedLogInfo searchs;

        Test.startTest();
            searchs = ResourceSearchController.getRecommendedLog(sl.Id);
        Test.stopTest();
        
        System.assertEquals(sl.Id, searchs.logId);
    }

    @IsTest
    static void getExistingReferralsTest(){
        Case newCase = new Case(
            Subject = 'Test'
        );
        insert newCase;

        Account acc = new Account(
            Name = 'Test',
            Current_Case_Id__c = newCase.Id
        );
        insert acc;

        ResourceSearchController.ReferralResults results;

        Test.startTest();
            results = ResourceSearchController.getExistingReferrals(acc.Id);
        Test.stopTest();
        
    }
}