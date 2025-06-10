public without sharing class PublicResourceSearchController {
    
    @AuraEnabled
    public static InitialFilters getInitialFilters(String taxonomyParam){
        InitialFilters init = new InitialFilters();
        // init.taxonomies = getTaxonomies('{}');
        init.filters = getFilters();
        init.zipsAndCity = getCityByZips();

        if(!String.isBlank(taxonomyParam)){
            List<Taxonomy__c> tax = [SELECT Id, Name FROM Taxonomy__c WHERE Name = :taxonomyParam LIMIT 1];
            if(!tax.isEmpty()){
                init.defaultTaxonomy = new Taxonomy(tax[0].Id, tax[0].Name);
            }
        }
        return init;
    }

    // public static List<Taxonomy> getAllTaxonomies(){
    //     List<Taxonomy> taxonomyList = new List<Taxonomy>();
    //     for(Taxonomy__c tax : [SELECT Id, Level__c, Name_and_Code__c, Level_1L__c, Level_2L__c, Level_3L__c, Level_4L__c, Level_5L__c, Level_6L__c,
    //                                 (SELECT Id, Level__c, Name_and_Code__c, Level_1L__c, Level_2L__c, Level_3L__c, Level_4L__c, Level_5L__c, Level_6L__c
    //                                 FROM Taxonomies__r WHERE Level__c = 2)
    //                             FROM Taxonomy__c
    //                             WHERE Level__c = 1]){
    //         taxonomyList.add(new Taxonomy(tax));
    //     }
    //     return taxonomyList;                        
    // }
    // @AuraEnabled
    // public static List<Taxonomy> getTaxonomies(String taxonomyString){
    //     try {
    //         Taxonomy deserializedTaxonomy = (Taxonomy)JSON.deserialize(taxonomyString, Taxonomy.class);
    //         List<Taxonomy> taxonomyList = new List<Taxonomy>();
    //         String taxonomyQuery = 'SELECT Id, Level__c, Name_and_Code__c, Level_1L__c, Level_2L__c, Level_3L__c, Level_4L__c, Level_5L__c, Level_6L__c'
    //                                 + ' FROM Taxonomy__c';
    //         if(String.isBlank(deserializedTaxonomy.taxonomyId)){
    //             taxonomyQuery += ' WHERE Level__c = 1';
    //         } else {
    //             taxonomyQuery += ' WHERE Level__c = ' + (deserializedTaxonomy.taxonomyLevel + 1) 
    //                         + ' AND Level_' + deserializedTaxonomy.taxonomyLevel + 'L__c = \'' + deserializedTaxonomy.taxonomyId + '\'';
    //         }
    //         for(Taxonomy__c tax : Database.query(taxonomyQuery)){
    //             taxonomyList.add(new Taxonomy(tax));
    //         }                 
    //         return taxonomyList;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    public static List<ZipAndCity> getCityByZips() {
        List<ZipAndCity> zipsAndCity = new List<ZipAndCity>();
        for(Zip_Code__c zip : [SELECT Id, Zip_Code__c, City__c FROM Zip_Code__c]){
            zipsAndCity.add(new ZipAndCity(zip));
        }
        return zipsAndCity;
    }

    // @AuraEnabled
    // public static List<Taxonomy> searchTaxonomy(String searchTerm){
    //     try {
    //         String keyTerm = '%' + searchTerm + '%';
    //         List<Taxonomy> taxonomyList = new List<Taxonomy>();
    //         for(Taxonomy__c taxonomy : [SELECT Id, Level__c, Name_and_Code__c, Level_1L__c, Level_2L__c, Level_3L__c, Level_4L__c, Level_5L__c, Level_6L__c
    //                                     FROM Taxonomy__c 
    //                                     WHERE Name_and_Code__c LIKE :keyTerm
    //                                     ORDER BY Name_and_Code__c]){
    //             taxonomyList.add(new Taxonomy(taxonomy));
    //         }
    //         return taxonomyList;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    public static List<Filter> getFilters(){
        Map<String,Schema.SObjectField> serviceFieldsSchemaMap = Schema.getGlobalDescribe().get('Service__c').getDescribe().fields.getMap(); 
        List<Filter> filters = new List<Filter>();

        for(Resource_Search_Filter__mdt filter : [SELECT Id, DeveloperName, MasterLabel, Api_Name__c, Public_Sequence__c
                                                FROM Resource_Search_Filter__mdt
                                                WHERE HMG_Filter__c = false
                                                ORDER BY Public_Sequence__c 
                                                NULLS LAST]){
            Schema.DescribeFieldResult fieldDescribe = serviceFieldsSchemaMap.get(filter.Api_Name__c).getDescribe();
            filters.add(new Filter(fieldDescribe));
        }

        return filters;
    }

    @AuraEnabled
    public static List<ServiceResult> searchResources(String additionalFiltersJSON, String searchFiltersJSON, String caseId){
        try {
            List<Filter> additionalFilters = (List<Filter>)JSON.deserialize(additionalFiltersJSON, List<Filter>.class);
            SearchFilter searchFilters = (SearchFilter)JSON.deserialize(searchFiltersJSON, SearchFilter.class);
            GeoData geoLocationData;

            if(searchFilters.sortedBy == 'Distance'){
                List<String> locationFilters = new List<String>{'country=USA'};
                if(!String.isBlank(searchFilters.city)){
                    locationFilters.add('city=' + EncodingUtil.urlEncode(searchFilters.city, 'UTF-8'));
                }
                if(!String.isBlank(searchFilters.postalCode)){
                    locationFilters.add('postalcode=' + EncodingUtil.urlEncode(searchFilters.postalCode, 'UTF-8'));
                }
                HttpRequest request = new HttpRequest();
                request.setMethod('GET');
                request.setEndpoint('https://nominatim.openstreetmap.org/search?format=json&limit=1&' + String.join(locationFilters,'&'));
                Http http = new Http();
                HTTPResponse response = http.send(request);
                List<GeoData> geoData = (List<GeoData>) JSON.deserialize(response.getBody(), List<GeoData>.class);
                if (!geoData.isEmpty()) {
                    geoLocationData = geoData[0];
                }
            }
            String serviceSOQL = 'SELECT Id, Name, Agency_Name__c, Eligibility_Extended__c, Hours_of_Operation_Long__c, PaymentMethods__c, PaymentMethodDetail__c, Intake_Line__c, ApplicationProcess__c, ApplicationProcessDescription__c, Service_Languages__c, DocumentsRequired__c, DocumentsRequiredDescription__c, Coverage_Area__c, Website__c, Email__c, Description__c, Email_Text_Body__c, Text_Default_Referral_Info__c, Service_Details__c, Direct_Referral_Partner__c, Referral_Type__c, TemporaryMessage__c, TemporaryMessageAppears__c, TemporaryMessageExpires__c, Business_Line__c, Business_Line_Type__c, Business_Line_2__c, Business_Line_2_Type__c, Business_Line_3__c, Business_Line_3_Type__c, Business_Line_4__c, Business_Line_4_Type__c, Other_Phone__c, Other_Phone_Type__c, Toll_Free_Number__c, '
                        + ' (Select Id, Public_Name__c, Site_Phone_Number__c, Distribution_Time_and_Date__c, Site__r.Name, Site__r.Physical_Geolocation__c, Site__r.Physical_Street__c, Site__r.Physical_City__c, Site__r.Physical_State__c, Site__r.Physical_Postal_Code__c, text_info__c, Info__c FROM Service_Sites__r ';
                        
            //if(geoLocationData != null && searchFilters.sortedBy == 'Distance'){
                serviceSOQL += ' WHERE DISTANCE(Site__r.Physical_Geolocation__c, GEOLOCATION(' + geoLocationData.lat + ',' + geoLocationData.lon + '), \'mi\') < ' + searchFilters.radius + ' OR (Site__r.Physical_Geolocation__latitude__s = null AND Site__r.Physical_Geolocation__longitude__s = null) OR Service__r.Coverage_Area__c = \'All Orange County\'' 
                                + ' ORDER BY DISTANCE(Site__r.Physical_Geolocation__c, GEOLOCATION(' + geoLocationData.lat + ',' + geoLocationData.lon + '), \'mi\') NULLS LAST ) ';
            //} else {
            //    serviceSOQL += ')';
            //}
            
            serviceSOQL += ' FROM Service__c WHERE (Status__c = \'Active\' AND Agency__r.Active_Status__c = \'Active\' AND ExcludeFromWebsite__c = false) ';

            // Filter Using the Search Filters
            if(!String.isBlank(searchFilters.agency)){
                // String taxSelected = searchFilters.taxonomySelected;
                // String taxoLike = '%' + searchFilters.taxonomySelected + '%';
                String taxoNameLike = '%' + searchFilters.agency + '%';
                List<Id> servicesWithTaxonomy = new List<Id>();
                List<String> whereClauses = new List<String>();
                // if(!String.isBlank(searchFilters.taxonomySelected)){
                //     whereClauses.add('Taxonomy__c = :taxSelected');
                //     whereClauses.add('Taxonomy__r.Higher_Taxonomies__c LIKE :taxoLike');
                // }
                if(!String.isBlank(searchFilters.agency)){
                    whereClauses.add('Taxonomy__r.Name LIKE :taxoNameLike');
                }
                String taxonomySearchQuery = 'SELECT Service__c'
                                            + ' FROM Service_Taxonomy__c'
                                            + ' WHERE '
                                            + String.join(whereClauses, ' OR ');
                for (Service_Taxonomy__c serviceByTaxonomy : Database.query(taxonomySearchQuery)) {
                    if(!servicesWithTaxonomy.contains(serviceByTaxonomy.Service__c)){
                        servicesWithTaxonomy.add(serviceByTaxonomy.Service__c);
                    }
                }
            }

            // Get Services with the selected Postal Code
            if(!String.isBlank(searchFilters.postalCode)){
                List<Id> servicesWithPostalCode = new List<Id>();
                for (Service_Zip_Code__c serviceWithZip : [SELECT Service__c
                                                    FROM Service_Zip_Code__c 
                                                    WHERE Name = :searchFilters.postalCode]) {
                    servicesWithPostalCode.add(serviceWithZip.Service__c);
                }
                serviceSOQL += ' AND Id IN :servicesWithPostalCode ';
            }

            // Get service based in Key Search Word
            if(!String.isBlank(searchFilters.agency)){
                String searchInput = '%' + searchFilters.agency + '%';
                serviceSOQL += ' AND (Name LIKE :searchInput OR Alternate_Name__c LIKE :searchInput OR Agency_Name__c LIKE :searchInput OR Search_Hints__c LIKE :searchInput OR Service_Agency__c LIKE :searchInput OR Id IN :servicesWithTaxonomy) ';
            }

            // Search by Additional Filters
            for(Filter additionalFilter : additionalFilters){
                if(additionalFilter.type == 'MULTIPICKLIST'){
                    if(!additionalFilter.selected.isEmpty()){
                        serviceSOQL += ' AND ' + additionalFilter.apiName + ' INCLUDES (\'' + String.join(additionalFilter.selected, ';') + '\') ';
                    }
                } else {
                    if(!String.isBlank(additionalFilter.singleValue)){
                        serviceSOQL += ' AND ' + additionalFilter.apiName + ' = \'' + additionalFilter.singleValue + '\' ';
                    }
                }
            }
            List<ServiceResult> serviceResults = new List<ServiceResult>();

            for(Service__c service : Database.query(serviceSOQL)){
                if(searchFilters.sortedBy == 'Distance' && service.Service_Sites__r.isEmpty()){
                    continue;
                }
                serviceResults.add(new ServiceResult(service, geoLocationData));
            }
            createSearchLog(additionalFilters, searchFilters, serviceResults.size(), caseId);
            return serviceResults;
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void createSearchLog(List<Filter> filters, SearchFilter searchFilter, Integer totalResults, String caseId){
        Search_Log__c searchLog = new Search_Log__c(
            Results_Count__c = totalResults,
            Type__c = 'Log',
            Case__c = caseId
        );
        // if(!String.isBlank(searchFilter.taxonomySelected)){
        //     searchLog.Taxonomy_Name__c = [SELECT Id, Name FROM Taxonomy__c WHERE Id = :searchFilter.taxonomySelected].Name;
        // }
        if(!String.isBlank(searchFilter.postalcode)){
            searchLog.Zip_Code__c = searchFilter.postalcode;
        }
        if(!String.isBlank(searchFilter.agency)){
            searchLog.Search_Term__c = searchFilter.agency;
        }

        for(Filter filter : filters){
            if(!String.isBlank(filter.singleValue) || !filter.selected.isEmpty()){
                searchLog.Filters_applied__c += filter.name + ': ' + (filter.isMulti ? String.join(filter.selected, ', ') : filter.singleValue) + '\n';
            }
        }

        insert searchLog;
    }

    public class InitialFilters {
        @Auraenabled public List<Taxonomy> taxonomies {get;set;}
        @Auraenabled public Taxonomy defaultTaxonomy {get;set;}
        @Auraenabled public List<Filter> filters {get;set;}
        @Auraenabled public List<ZipAndCity> zipsAndCity {get;set;}
        @Auraenabled public String caseId {get;set;}

        public InitialFilters(){
            Group queue = [SELECT Id 
                            FROM Group
                            WHERE Type = 'Queue' AND Name LIKE '%Anonymous Search Owners' AND (NOT Name LIKE '%DEPRECATED%')
                            LIMIT 1];
            
            Case resourceSearchCase =  new Case(Status = 'Closed', Subject = 'Public Resource Search', OwnerId = queue.Id);
            insert resourceSearchCase;
            this.caseId = resourceSearchCase.Id;

            Integer caseCounter = [SELECT COUNT() FROM Case WHERE OwnerId = :queue.Id];
            if(caseCounter > 9989){
                System.enqueueJob(new PublicSearchQueueHandler(queue.Id));
            }
        }
    }

    public class ZipAndCity {
        @AuraEnabled public String zip{get;set;}
        @AuraEnabled public String city{get;set;}

        public ZipAndCity(Zip_Code__c zipCode){
            this.zip = zipCode.Zip_Code__c;
            this.city = zipCode.City__c;
        }
    }

    public class Taxonomy {
        @Auraenabled public String taxonomyId {get;set;}
        @Auraenabled public String taxonomyName {get;set;}
        @Auraenabled public Decimal taxonomyLevel {get;set;}
        @Auraenabled public String level1 {get;set;}
        @Auraenabled public String level2 {get;set;}
        @Auraenabled public String level3 {get;set;}
        @Auraenabled public String level4 {get;set;}
        @Auraenabled public String level5 {get;set;}
        @Auraenabled public String level6 {get;set;}

        public Taxonomy(Taxonomy__c taxo){
            this.taxonomyId = taxo.Id;
            this.taxonomyName = taxo.Name_and_Code__c;
            this.taxonomyLevel = taxo.Level__c;
            this.level1 = taxo.Level_1L__c;
            this.level2 = taxo.Level_2L__c;
            this.level3 = taxo.Level_3L__c;
            this.level4 = taxo.Level_4L__c;
            this.level5 = taxo.Level_5L__c;
            this.level6 = taxo.Level_6L__c;
            
        }

        public Taxonomy(String taxoId, String taxoName){
            this.taxonomyId = taxoId;
            this.taxonomyName = taxoName;
        }
    }

    public class GeoData {
        @AuraEnabled public String lat{get;set;}
        @AuraEnabled public String lon{get;set;}
    }

    public class Filter {
        @Auraenabled public String name {get;set;}
        @Auraenabled public String apiName {get;set;}
        @Auraenabled public String type {get;set;}
        @Auraenabled public List<PicklistValue> options {get;set;}
        @Auraenabled public List<String> selected {get;set;}
        @Auraenabled public String singleValue {get;set;}
        @Auraenabled public Boolean isMulti {get;set;}

        public Filter(Schema.DescribeFieldResult fieldDescribe){
            this.name = fieldDescribe.getLabel();
            this.apiName = fieldDescribe.getLocalName();
            this.type = String.valueOf(fieldDescribe.getType());
            this.isMulti = String.valueOf(fieldDescribe.getType()) == 'MULTIPICKLIST';
            this.singleValue = '';
            if(fieldDescribe.getPickListValues() != null){
                this.options = new List<PicklistValue>();
                for (Schema.PicklistEntry entry : fieldDescribe.getPickListValues()) {
                    if (entry.isActive()) {
                        this.options.add(new PicklistValue(entry));
                    }
                }
            }
            this.selected = new List<String>();
        }
    }

    public class PicklistValue {
        @AuraEnabled public String label{get;set;}
        @AuraEnabled public String value{get;set;}

        public PicklistValue(Schema.PicklistEntry entry){
            this.label = entry.getLabel();
            this.value = entry.getValue();
        }
    }

    public class SearchFilter {
        @AuraEnabled public String agency {get;set;}
        @AuraEnabled public String city {get;set;}
        @AuraEnabled public String postalCode {get;set;}
        @AuraEnabled public String radius {get;set;}
        @AuraEnabled public String street {get;set;}
        // @AuraEnabled public String taxonomySelected {get;set;}
        @AuraEnabled public String sortedBy {get;set;}

        public SearchFilter(){}
    }

    public class ServiceResult {
        @AuraEnabled public String id{get;set;}
        @AuraEnabled public String name{get;set;}
        @AuraEnabled public String agency_Name{get;set;}
        @AuraEnabled public String eligibility_Extended{get;set;}
        @AuraEnabled public String hours_of_Operation_Long{get;set;}
        @AuraEnabled public String paymentMethods{get;set;}
        @AuraEnabled public String intake_Line{get;set;}
        @AuraEnabled public String applicationProcess{get;set;}
        @AuraEnabled public String applicationProcessDesc{get;set;}
        @AuraEnabled public String service_Languages{get;set;}
        @AuraEnabled public String documentsRequired{get;set;}
        @AuraEnabled public String documentsRequiredDesc{get;set;}
        @AuraEnabled public String coverage_Area{get;set;}
        @AuraEnabled public String website{get;set;}
        @AuraEnabled public String email{get;set;}
        @AuraEnabled public String description{get;set;}
        @AuraEnabled public String email_Text_Body{get;set;}
        @AuraEnabled public String text_Default_Referral_Info{get;set;}
        @AuraEnabled public String service_Details{get;set;}
        @AuraEnabled public Boolean direct_Referral_Partner{get;set;}
        @AuraEnabled public String referral_Type{get;set;}
        @AuraEnabled public String temporaryMessage{get;set;}
        @AuraEnabled public DateTime temporaryMessageAppears{get;set;}
        @AuraEnabled public DateTime temporaryMessageExpires{get;set;}
        @AuraEnabled public String business_Line{get;set;}
        @AuraEnabled public String business_Line_Type{get;set;}
        @AuraEnabled public String business_Line_2{get;set;}
        @AuraEnabled public String business_Line_2_Type{get;set;}
        @AuraEnabled public String business_Line_3{get;set;}
        @AuraEnabled public String business_Line_3_Type{get;set;}
        @AuraEnabled public String business_Line_4{get;set;}
        @AuraEnabled public String business_Line_4_Type{get;set;}
        @AuraEnabled public String other_Phone{get;set;}
        @AuraEnabled public String other_Phone_Type{get;set;}
        @AuraEnabled public String toll_Free_Number{get;set;}

        
        @AuraEnabled public Boolean showTemporaryMessage{get;set;}
        @AuraEnabled public List<GeoLocationData> sites{get;set;}

        public ServiceResult(Service__c service, GeoData locationInSearch){
            this.id = service.Id;
            this.name = service.Name;
            this.agency_Name = service.Agency_Name__c;
            this.eligibility_Extended = service.Eligibility_Extended__c;
            this.hours_of_Operation_Long = service.Hours_of_Operation_Long__c;
            this.paymentMethods = service.PaymentMethods__c;
            if(service.PaymentMethodDetail__c != null){
                this.paymentMethods += '. ' + service.PaymentMethodDetail__c; 
            }
            this.intake_Line = service.Intake_Line__c;
            this.applicationProcess = service.ApplicationProcess__c;
            this.applicationProcessDesc = service.ApplicationProcessDescription__c;
            this.service_Languages = service.Service_Languages__c;
            this.documentsRequired = service.DocumentsRequired__c;
            this.documentsRequiredDesc = service.DocumentsRequiredDescription__c;
            this.coverage_Area = service.Coverage_Area__c;
            this.website = service.Website__c;
            this.email = service.Email__c;
            this.description = service.Description__c;
            this.email_Text_Body = service.Email_Text_Body__c;
            this.text_Default_Referral_Info = service.Text_Default_Referral_Info__c;
            this.service_Details = service.Service_Details__c;
            this.direct_Referral_Partner = service.Direct_Referral_Partner__c;
            this.referral_Type = service.Referral_Type__c;
            this.temporaryMessage = service.TemporaryMessage__c;
            this.temporaryMessageAppears = service.TemporaryMessageAppears__c;
            this.temporaryMessageExpires = service.TemporaryMessageExpires__c;
            this.business_Line = service.Business_Line__c;
            this.business_Line_Type = service.Business_Line_Type__c;
            this.business_Line_2 = service.Business_Line_2__c;
            this.business_Line_2_Type = service.Business_Line_2_Type__c;
            this.business_Line_3 = service.Business_Line_3__c;
            this.business_Line_3_Type = service.Business_Line_3_Type__c;
            this.business_Line_4 = service.Business_Line_4__c;
            this.business_Line_4_Type = service.Business_Line_4_Type__c;
            this.other_Phone = service.Other_Phone__c;
            this.other_Phone_Type = service.Other_Phone_Type__c;
            this.toll_Free_Number = service.Toll_Free_Number__c;
            
            this.showTemporaryMessage = service.TemporaryMessageAppears__c != null && service.TemporaryMessageExpires__c >= Date.today();
            this.sites = new List<GeoLocationData>();
            if(!service.Service_Sites__r?.isEmpty()){
                for(Service_Site__c site : service.Service_Sites__r) {
                    if (site.Site__r.Physical_Geolocation__c != null) {
                        Location locSite = site.Site__r.Physical_Geolocation__c;
                        if (locSite.latitude != null && locSite.longitude != null) {
                            GeoLocationData locationSite = new GeoLocationData();
                            locationSite.latitude = locSite.latitude;
                            locationSite.longitude = locSite.longitude;
                            locationSite.name = site.Public_Name__c;
                            locationSite.id = site.Id;
                            locationSite.city = site.Site__r.Physical_City__c;
                            locationSite.country = 'USA';
                            locationSite.postalcode = site.Site__r.Physical_Postal_Code__c;
                            locationSite.state = site.Site__r.Physical_State__c;
                            locationSite.street = site.Site__r.Physical_Street__c;
                            locationSite.addressInfo = site.Site__r.Physical_Street__c + ' ' + site.Site__r.Physical_City__c + ' ' + site.Site__r.Physical_State__c + ', ' + site.Site__r.Physical_Postal_Code__c;
                            locationSite.sitePhone = site.Site_Phone_Number__c;
                            locationSite.sitetimeAndDate = site.Distribution_Time_and_Date__c;
                            if(locationInSearch != null){
                                Location locationSearched = Location.newInstance(Decimal.valueOf(locationInSearch.lat), Decimal.valueOf(locationInSearch.lon));
                                locationSite.distance  = Decimal.valueOf(locationSearched.getDistance(site.Site__r.Physical_Geolocation__c, 'mi')).setScale(2);
                                locationSite.hasDistance = true;
                            }
                            this.sites.add(locationSite);
                        }
                    }
                }
            }
        }
    }

    public class GeoLocationData {
        @AuraEnabled public Double latitude {get;set;}
        @AuraEnabled public Double longitude {get;set;}
        @AuraEnabled public String id {get;set;}
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public Double distance {get;set;}
        @AuraEnabled public String addressInfo {get;set;}
        @AuraEnabled public String sitePhone {get;set;}
        @AuraEnabled public String sitetimeAndDate {get;set;}
        @AuraEnabled public Boolean hasDistance {get;set;}

        @AuraEnabled public String city {get;set;}
        @AuraEnabled public String country {get;set;}
        @AuraEnabled public String postalcode {get;set;}
        @AuraEnabled public String state {get;set;}
        @AuraEnabled public String street {get;set;}
    }
}