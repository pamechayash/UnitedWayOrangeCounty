global with sharing class ResourceSearchController {

    private static final Map<String, Taxonomy__c> lowerL2Map = new Map<String, Taxonomy__c>();
    private static final Map<String, Taxonomy__c> lowerL3Map = new Map<String, Taxonomy__c>();
    private static final Map<String, Taxonomy__c> lowerL4Map = new Map<String, Taxonomy__c>();
    private static final Map<String, Taxonomy__c> lowerL5Map = new Map<String, Taxonomy__c>();
    private static final Map<String, Taxonomy__c> lowerL6Map = new Map<String, Taxonomy__c>();
    
    @AuraEnabled(cacheable=true)
    public static Boolean isHelpMeGrowAdmin() {
        // Replace 'Help Me Grow Admin' with the actual profile or permission set name
        String profileName = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
        return profileName == 'Help Me Grow Admin';
    }

    @AuraEnabled(cacheable=true)
    public static List<Taxonomy> findTaxonomy() {
        List<Taxonomy> response = new List<Taxonomy>();

        for (Taxonomy__c taxo : [   SELECT Id, Name, Level__c, Higher_Taxonomies__c, Name_and_Code__c
                                    FROM Taxonomy__c 
                                    // WHERE (NOT Code__c LIKE 'Y%') AND (Level__c = 1 OR
                                    WHERE (Level__c = 1 OR
                                    ((Level__c = 2 OR Level__c = 3) OR 
                                    ((Level__c = 4 OR Level__c = 5 OR Level__c = 6 ) AND (Service_Count__c > 0))))
                                    LIMIT 50000 ]) {

            Taxonomy taxonomy = new Taxonomy();
            List<TaxonomyChild> childs = new List<TaxonomyChild>();
            taxonomy.hasChilds = true;
            
            TaxonomyChild firstChild = new TaxonomyChild();
            firstChild.id = taxo.Id;
            firstChild.level = taxo.Level__c;
            firstChild.name = taxo.Name_and_Code__c;
            firstChild.higherTaxonomies = taxo.Id + ',';

            childs.add(firstChild);

            taxonomy.childs = childs;
            response.add(taxonomy);
        }
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<Taxonomy> getLevel1Taxonomies() {
        List<Taxonomy> response = new List<Taxonomy>();

        // iterate over all the level 1 taxonomies to get the parents only
        for (Taxonomy__c taxo : [   SELECT Id, Name, Level__c, Higher_Taxonomies__c, Name_and_Code__c,
                                    (SELECT Id, Name from Taxonomies__r)
                                    FROM Taxonomy__c 
                                    WHERE Level__c = 1
                                    // WHERE Level__c = 1 AND (NOT Code__c LIKE 'Y%') AND Code__c LIKE '_' 
                                    LIMIT 50000 ]) {

            Taxonomy taxonomy = new Taxonomy();
            List<TaxonomyChild> childs = new List<TaxonomyChild>();
            taxonomy.hasChilds = false;
            for (Taxonomy__c child : taxo.Taxonomies__r) {
                if(!String.isBlank(child.Name)) {
                    taxonomy.hasChilds = true;
                    break;
                }
            }
            
            TaxonomyChild firstChild = new TaxonomyChild();
            firstChild.id = taxo.Id;
            firstChild.level = taxo.Level__c;
            firstChild.name = taxo.Name_and_Code__c;
            firstChild.higherTaxonomies = taxo.Id + ',';

            childs.add(firstChild);

            taxonomy.childs = childs;
            response.add(taxonomy);
        }
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<TaxonomyChild> getLowerLevelTaxonomies(String higherTaxonomies, Integer currentLevel) {
        List<TaxonomyChild> response = new List<TaxonomyChild>();

        List<String> existingIds = higherTaxonomies.replaceAll('(\\s+)', '').removeEnd(',').split(',');
        String higherSoql = '';
        for (String higher : existingIds) {
            higherSoql += ' AND Higher_Taxonomies__c LIKE \'%' + higher + '%\' ';
        }

        String dSoql = 'SELECT Id, Name, Level__c, Higher_Taxonomies__c, Name_and_Code__c ' +
                        ' FROM Taxonomy__c  ' +
                        ' WHERE ((Level__c = 2 OR Level__c = 3) ' +
                        ' OR ((Level__c = 4 OR Level__c = 5 OR Level__c = 6 ) AND (Service_Count__c > 0)))  ' +
                        ' AND Level__c = ' + (currentLevel+1) + higherSoql + 
                        // ' AND (NOT Code__c LIKE \'Y%\') AND Level__c = ' + (currentLevel+1) + higherSoql + 
                        ' ORDER BY Level__c ASC ' +
                        ' LIMIT 10000 ';
    
        for (Taxonomy__c currentTaxonomy : Database.query(dSoql)) {
            
            TaxonomyChild newChild = new TaxonomyChild();     
            
            List<String> higherTaxsIds = currentTaxonomy.Higher_Taxonomies__c.replaceAll('(\\s+)', '').removeEnd(',').split(',');
            if (checkIfListContainsList(higherTaxsIds, existingIds) && (currentLevel + 1) != 7) {
                newChild.id = currentTaxonomy.Id;
                newChild.level = currentTaxonomy.Level__c;
                newChild.name = currentTaxonomy.Name_and_Code__c;
                newChild.higherTaxonomies = higherTaxonomies + currentTaxonomy.Id + ',';
                response.add(newChild);
                continue;           
            }
        }
        return response;
    }

    private static Boolean checkIfListContainsList(List<String> origin, List<String> valuesToSearch) {
        Boolean response = true;
        for (String value : valuesToSearch) {
            if (!origin.contains(value)) {
                response = false;
                break;
            }
        }
        return response;
    }

    @AuraEnabled
    public static ReferralResults searchReferrals(String inputs) {
        try {
            ReferralResults response = new ReferralResults();
            Set<String> serviceIdList = new Set<String>();
            Set<String> serviceIdListByTax = new Set<String>();
            Set<String> serviceIdListByZipC = new Set<String>();
            Boolean takeIdsInCount = false;
            Map<String, Object> searchInputs = (Map<String, Object>) JSON.deserializeUntyped(inputs);
    	
            String taxonomyId = (String)searchInputs.get('taxonomy');
            searchInputs.remove('taxonomy');
            if (!String.isBlank(taxonomyId) || (String)searchInputs.get('taxonomy') != null) {
                serviceIdListByTax = searchServiceByTaxonomy(taxonomyId);
            }
    
            String zipCode = (String)searchInputs.get('zipCode');
            String accountId = (String)searchInputs.get('accountId');
            searchInputs.remove('zipCode');
            searchInputs.remove('accountId');
            Account acc;
            Boolean updateAccount = false;

            if (!String.isBlank(zipCode)) {
                serviceIdListByZipC = searchServiceByZipCode(zipCode);
                if(!String.isBlank(accountId)){
                    acc = [SELECT Id, Zip_Last_Search__c FROM Account WHERE Id = :accountId];
                    String oldvalue = acc.Zip_Last_Search__c;
                    acc.Zip_Last_Search__c = zipCode;
                    if(searchInputs.containsKey('location')){
                        Map<String, Object> locInputs = (Map<String, Object>)searchInputs.get('location');
                        if(locInputs.containsKey('City')){
                            acc.Zip_Last_Search__c += ' - ' + (String)locInputs.get('City');
                        }
                    }
                    try {
                        if(oldvalue != acc.Zip_Last_Search__c){
                            updateAccount = true;
                        }
                    } catch (DmlException e) {
                        System.debug(LoggingLevel.INFO, e.getMessage());
                    }
                }
            }
    
            if (!String.isBlank(taxonomyId) && !String.isBlank(zipCode)) {
                serviceIdList = mergeSetResults(serviceIdListByTax, serviceIdListByZipC);
                takeIdsInCount = true;
            } else if ((!String.isBlank(taxonomyId) || taxonomyId != null )|| !String.isBlank(zipCode)){
                serviceIdList = (String.isBlank(taxonomyId)) ? serviceIdListByZipC : serviceIdListByTax;
                takeIdsInCount = true;
            } else {
                takeIdsInCount = false;
            }

            String caseId = (String)searchInputs.get('caseId');
            searchInputs.remove('caseId');
            Set<String> alredyServicesAdded = getAlreadyAddedReferralsToCase(caseId);
    
    
            Boolean searchByDistance = (Boolean)searchInputs.get('sortByDistance');
            searchInputs.remove('sortByDistance');
            if (searchByDistance) {
                response = searchReferralsByDistance(searchInputs, serviceIdList, takeIdsInCount, alredyServicesAdded);
            } else {
                response = searchReferralsByRelevance(searchInputs, serviceIdList, takeIdsInCount, alredyServicesAdded);
            }
            Integer resultSize = 0;
            if(response != null && response.data != null){
                resultSize = response.data.size();
            }
            if(updateAccount){
                update acc;
            }
            
            if(response.data != null){
                createSearchLog(searchInputs, response.data.size(), taxonomyId, caseId, zipCode, inputs);
            }
            return response;
        } catch (Exception ex) {
            throw new AuraException('Exception In ' + ex.getLineNumber() + ' line, Message: ' + ex.getMessage());
        }
    }

    private static void createSearchLog(Map<String, Object> searchInputs, Integer resultSize, String taxoId, String caseId, String zipCode, String JSONinputs){
        try {
            Search_Log__c searchLog = new Search_Log__c(
                Case__c = caseId, 
                Filters_applied__c = '',
                Results_Count__c = resultSize,
                JSON_Inputs__c = JSONinputs,
                Type__c = 'Log'
            );
            if(!String.isBlank(taxoId)){
                searchLog.Taxonomy_Name__c = [SELECT Id, Name FROM Taxonomy__c WHERE Id = :taxoId].Name;
            }
            if(!String.isBlank(zipCode)){
                searchLog.Zip_Code__c = zipCode;
            }

            for(String keyInput : searchInputs.keySet()){
                if(keyInput != 'location' && keyInput != 'servicename'){
                    searchLog.Filters_applied__c += keyInput + ': ' + (String)searchInputs.get(keyInput) + '\n';
                } else if (keyInput == 'servicename'){
                    searchLog.Search_Term__c = (String)searchInputs.get(keyInput);
                }
            }
            insert searchLog;
        } catch (Exception e) {
            System.debug(LoggingLevel.INFO, e.getMessage());
        }
        
    }

    @AuraEnabled
    public static List<RecentSearch> getSearchLogs(String caseId){
        try {
            List<RecentSearch> recentSearchs = new List<RecentSearch>();
            for(Search_Log__c searchLog : [SELECT Id, Zip_Code__c, Taxonomy_Name__c, Results_Count__c, JSON_Inputs__c, CreatedDate
                                            FROM Search_Log__c
                                            WHERE Case__c = :caseId
                                                AND Zip_Code__c <> null
                                                AND Type__c = 'Log'
                                            ORDER BY CreatedDate DESC
                                            LIMIT 3]){
                recentSearchs.add(new RecentSearch(searchLog));
            }
            return recentSearchs;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<RecentSearch> getSearchRecomendations(String caseId){
        try {
            List<RecentSearch> recentSearchs = new List<RecentSearch>();
            for(Search_Log__c searchLog : [SELECT Id, Zip_Code__c, Taxonomy_Name__c, Results_Count__c, JSON_Inputs__c, CreatedDate, Recommendation_Title__c
                                            FROM Search_Log__c
                                            WHERE Case__c = :caseId
                                                AND Type__c = 'Recommended'
                                                AND Recommendation_Title__c <> null
                                            ORDER BY CreatedDate DESC]){
                RecentSearch recent = new RecentSearch(searchLog);
                recent.taxonomy = searchLog.Recommendation_Title__c;
                recentSearchs.add(recent);
            }
            return recentSearchs;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Set<String> searchServiceByTaxonomy(String taxoId) {
        String likeSoql = '%' + taxoId + '%';
        Set<String> response = new Set<String>();
        List<Service_Taxonomy__c> taxList = [SELECT Id, Name, Taxonomy__c, Service__c
                                                FROM Service_Taxonomy__c
                                                WHERE Taxonomy__c =: taxoId OR Taxonomy__r.Higher_Taxonomies__c LIKE :likeSoql
                                                LIMIT 10000];
        if (!taxList.isEmpty()) {
            for (Service_Taxonomy__c serTax : taxList) {
                response.add(serTax.Service__c);
            }
        }
        return response;
    }

    private static Set<String> searchServiceByZipCode(String zipCode) {
        Set<String> response = new Set<String>();
        List<Service_Zip_Code__c> zipCList = [SELECT Id, Name, Service__c
                                                FROM Service_Zip_Code__c 
                                                WHERE Name =: zipCode
                                                LIMIT 10000];
        if (!zipCList.isEmpty()) {
            for (Service_Zip_Code__c serZip : zipCList) {
                response.add(serZip.Service__c);
            }
        }
        return response;
    }

    private static Set<String> mergeSetResults(Set<String> serviceIdListByTax, Set<String> serviceIdListByZipC){
        Set<String> response = new Set<String>();
        if (!serviceIdListByTax.isEmpty() && !serviceIdListByZipC.isEmpty()) { 
            for(String servZip: serviceIdListByZipC){
                if(serviceIdListByTax.contains(servZip)){
                    response.add(servZip);
                }
            }
        }
        return response;
    }

    private static ReferralResults searchReferralsByRelevance(Map<String, Object> searchInputs, Set<String> serviceIdList, Boolean takeIdsInCount, Set<String> alredyServicesAdded) {
        ReferralResults response = new ReferralResults();
        List<Referral> refList = new List<Referral>();
        if(searchInputs.containsKey('radio')){
            searchInputs.remove('radio');
        }

        String dSoql = 'SELECT Id, Name, ExcludeFromWebsite__c, Agency_Name__c, Eligibility_Extended__c, Hours_of_Operation_Long__c, PaymentMethods__c, PaymentMethodDetail__c, Intake_Line__c, ApplicationProcess__c, Service_Languages__c, DocumentsRequired__c, Coverage_Area__c, Website__c, Email__c, Description__c, Email_Text_Body__c, Text_Default_Referral_Info__c, Service_Details__c, Direct_Referral_Partner__c, Referral_Type__c, TemporaryMessage__c, TemporaryMessageAppears__c, TemporaryMessageExpires__c, Business_Line__c, Business_Line_Type__c, Business_Line_2__c, Business_Line_2_Type__c, Business_Line_3__c, Business_Line_3_Type__c, Business_Line_4__c, Business_Line_4_Type__c, Other_Phone__c, Other_Phone_Type__c, Toll_Free_Number__c, ApplicationProcessDescription__c, DocumentsRequiredDescription__c, ' +
                        ' (Select Id, Public_Name__c, Site_Phone_Number__c, Distribution_Time_and_Date__c, Site__r.Name, Site__r.Physical_Geolocation__c, Site__r.Physical_Street__c, Site__r.Physical_City__c, Site__r.Physical_State__c, Site__r.Physical_Postal_Code__c, text_info__c, Info__c FROM Service_Sites__r), ' + 
                        ' (Select Id, Taxonomy__r.Id, Taxonomy__r.Name FROM Service_Taxonomies__r WHERE NOT Code__c LIKE \'Y%\') ' + 
                        ' FROM Service__c ' + 
                        ' WHERE (Status__c = \'Active\' AND Agency__r.Active_Status__c = \'Active\') ';
        String filters = '';
        for (String Id : searchInputs.keyset()) {
            if(searchInputs.containsKey(Id) && searchInputs.get(Id) != null){
                if (!String.isBlank(searchInputs.get(Id).toString()) && Id != 'location' && Id != 'radio' && Id != 'servicename') {
                    String fieldType = Schema.getGlobalDescribe().get('Service__c').getDescribe().fields.getMap().get(Id).getDescribe().getType().name().toupperCase();
                    if (fieldType != 'MULTIPICKLIST' && fieldType != 'TEXTAREA' && fieldType != 'ADDRESS' && fieldType != 'Email' && fieldType != 'PICKLIST') {
                        filters = filters +  ' ' + Id + ' = ' + searchInputs.get(Id) + ' AND';
                    } else if(fieldType != 'MULTIPICKLIST'){
                        filters = filters + ' ' + Id + ' = \'' + searchInputs.get(Id) + '\' AND';
                    } else {
                        filters = filters + ' ' + Id + ' INCLUDES (\'' + searchInputs.get(Id) + '\') AND';
                    }
                } else if(Id == 'servicename' && !String.isBlank(searchInputs.get(Id).toString())){
                    String searchInput = '%' + searchInputs.get(Id) + '%';
                    filters = filters +  '(Name LIKE :searchInput OR Alternate_Name__c LIKE :searchInput OR Agency_Name__c LIKE :searchInput OR Search_Hints__c LIKE :searchInput) AND';
                }
            }
        }
        if (!String.isBlank(filters)) {
            dSoql += ' AND ' + filters;
            dSoql = dSoql.removeEnd('AND');
        }

        if (takeIdsInCount) {
            if (!serviceIdList.isEmpty()) {
                dSoql += ' AND Id IN ' + buildQuotesParameter(serviceIdList) + ' ';
            } else {
                dSoql += ' AND Id IN (\'\')';
            }
        }

        User user = [SELECT Profile.UserLicense.Name FROM User WHERE Id = :UserInfo.getUserId()];
        if(user.Profile.UserLicense.Name != null && user.Profile.UserLicense.Name == 'Customer Community Plus Login'){
            dSoql += ' AND ExcludeFromWebsite__c = false ';
        }

        dSoql += ' LIMIT 50000';

        for (Service__c serv : database.query(dSoql)) {
            Referral ref = new Referral();
            ref.referral = serv;
            ref.disable = alredyServicesAdded.contains(serv.Id);
            ref.fullEmailBody = serv.Email_Text_Body__c;
            ref.fullSMSBody = serv.Text_Default_Referral_Info__c;
            ref.showConsentMessage = false;
            List<GeoLocationData> locationList = new List<GeoLocationData>();
            if (!serv.Service_Sites__r.isEmpty()) {
                for(Service_Site__c site : serv.Service_Sites__r) {
                    if (site.Site__r.Physical_Geolocation__c != null) {
                        Location locSite = site.Site__r.Physical_Geolocation__c;
                        if (locSite.latitude != null && locSite.longitude != null) {
                            GeoLocationData location = new GeoLocationData();
                            location.latitude = locSite.latitude;
                            location.longitude = locSite.longitude;
                            location.name = site.Public_Name__c;
                            location.postalcode = site.Site__r.Physical_Postal_Code__c;
                            location.addressInfo = site.Site__r.Physical_Street__c + ' ' + site.Site__r.Physical_City__c + ' ' + site.Site__r.Physical_State__c + ', ' + site.Site__r.Physical_Postal_Code__c;
                            location.serviceSitePhone = site.Site_Phone_Number__c;
                            location.serviceTimeAndDate = site.Distribution_Time_and_Date__c;
                            location.emailInfo = site.Info__c;
                            location.smsInfo = site.Text_Info__c;
                            locationList.add(location);
                        }
                    }
                }
            }
            if (!locationList.isEmpty()) {
                ref.locations = locationList;
            }
            refList.add(ref);
        }

        if (!refList.isEmpty()) {
            response.data = refList;
        }
        return response;
    }

    private static ReferralResults searchReferralsByDistance(Map<String, Object> searchInputs, Set<String> serviceIdList, Boolean takeIdsInCount, Set<String> alredyServicesAdded) {
        ReferralResults response = new ReferralResults();
        
        GeoData currentGeoData = getCoordinates(searchInputs);
        if (currentGeoData != null) {
            Integer radiusSearch = Integer.valueOf(searchInputs.get('radio'));
            searchInputs.remove('location');
            searchInputs.remove('radio');
            Integer numberOfResults = Integer.valueOf(Resource_Search_Location_Search__mdt.getInstance('Number_of_Results').Value__c);

            
            List<Referral> refList = new List<Referral>();
            String dSoql = 'SELECT Id, Name, ExcludeFromWebsite__c, Agency_Name__c, Eligibility_Extended__c, Hours_of_Operation_Long__c, PaymentMethods__c, PaymentMethodDetail__c, Intake_Line__c, ApplicationProcess__c, Service_Languages__c, DocumentsRequired__c, Coverage_Area__c, Website__c, Email__c, Description__c, Email_Text_Body__c, Text_Default_Referral_Info__c, Service_Details__c, Direct_Referral_Partner__c, Referral_Type__c, TemporaryMessage__c, TemporaryMessageAppears__c, TemporaryMessageExpires__c, Business_Line__c, Business_Line_Type__c, Business_Line_2__c, Business_Line_2_Type__c, Business_Line_3__c, Business_Line_3_Type__c, Business_Line_4__c, Business_Line_4_Type__c, Other_Phone__c, Other_Phone_Type__c, Toll_Free_Number__c, ApplicationProcessDescription__c, DocumentsRequiredDescription__c, ' +
                            ' (Select Id, Public_Name__c, Site_Phone_Number__c, Distribution_Time_and_Date__c, Site__r.Name, Site__r.Physical_Geolocation__c, Site__r.Physical_Street__c, Site__r.Physical_City__c, Site__r.Physical_State__c, Site__r.Physical_Postal_Code__c, text_info__c, Info__c ' +
                                ' FROM Service_Sites__r ' +
                                ' WHERE DISTANCE(Site__r.Physical_Geolocation__c, GEOLOCATION(' + currentGeoData.lat + ',' + currentGeoData.lon + '), \'mi\') < ' + radiusSearch + ' OR (Site__r.Physical_Geolocation__latitude__s = null AND Site__r.Physical_Geolocation__longitude__s = null) OR Service__r.Coverage_Area__c = \'All Orange County\'' +
                            ' ORDER BY DISTANCE(Site__r.Physical_Geolocation__c, GEOLOCATION(' + currentGeoData.lat + ',' + currentGeoData.lon + '), \'mi\') NULLS LAST ),  ' + 
                            ' (Select Id, Taxonomy__r.Id, Taxonomy__r.Name FROM Service_Taxonomies__r WHERE NOT Code__c LIKE \'Y%\') ' + 
                            ' FROM Service__c ' + 
                            ' WHERE (Status__c = \'Active\' AND Agency__r.Active_Status__c = \'Active\') ';
            String filters = '';
            for (String Id : searchInputs.keyset()) {
                if (!String.isBlank(searchInputs.get(Id).toString()) && Id != 'location' && Id != 'radio' && Id != 'servicename') {
                    String fieldType = Schema.getGlobalDescribe().get('Service__c').getDescribe().fields.getMap().get(Id).getDescribe().getType().name().toupperCase();
                    if (fieldType != 'MULTIPICKLIST' && fieldType != 'TEXTAREA' && fieldType != 'ADDRESS' && fieldType != 'Email' && fieldType != 'PICKLIST') {
                        filters = filters +  ' ' + Id + ' = ' + searchInputs.get(Id) + ' AND';
                    } else if(fieldType != 'MULTIPICKLIST'){
                        filters = filters + ' ' + Id + ' = \'' + searchInputs.get(Id) + '\' AND';
                    } else {
                        filters = filters + ' ' + Id + ' INCLUDES (\'' + searchInputs.get(Id) + '\') AND';
                    }
                }  else if(Id == 'servicename' && !String.isBlank(searchInputs.get(Id).toString())){
                    String searchInput = '%' + searchInputs.get(Id) + '%';
                    filters = filters +  '(Name LIKE :searchInput OR Alternate_Name__c LIKE :searchInput OR Agency_Name__c LIKE :searchInput OR Search_Hints__c LIKE :searchInput) AND';
                }
            }
            if (!String.isBlank(filters)) {
                dSoql += ' AND ' + filters;
                dSoql = dSoql.removeEnd('AND');
            }
    
            if (takeIdsInCount) {
                if (!serviceIdList.isEmpty()) {
                    dSoql += ' AND Id IN ' + buildQuotesParameter(serviceIdList) + ' ';
                } else {
                    dSoql += ' AND Id IN (\'\')';
                }
            }

            User user = [SELECT Profile.UserLicense.Name FROM User WHERE Id = :UserInfo.getUserId()];
            if(user.Profile.UserLicense.Name != null && user.Profile.UserLicense.Name == 'Customer Community Plus Login'){
                dSoql += ' AND ExcludeFromWebsite__c = false ';
            }
            System.debug(dSoql);
            for (Service__c serv : database.query(dSoql)) {
                if (!serv.Service_Sites__r.isEmpty()) {
                    List<GeoLocationData> locationList = new List<GeoLocationData>();
                    Referral ref = new Referral();
                    ref.referral = serv;
                    ref.disable = alredyServicesAdded.contains(serv.Id);
                    ref.fullEmailBody = serv.Email_Text_Body__c;
                    ref.fullSMSBody = serv.Text_Default_Referral_Info__c;
                    ref.showConsentMessage = false;
                    for(Service_Site__c site : serv.Service_Sites__r) {
                        if (site.Site__r.Physical_Geolocation__c != null) {
                            Location locSite = site.Site__r.Physical_Geolocation__c;
                            if (locSite.latitude != null && locSite.longitude != null) {
                                GeoLocationData locationSite = new GeoLocationData();
                                Location currentClientLocation = Location.newInstance(Decimal.valueOf(currentGeoData.lat), Decimal.valueOf(currentGeoData.lon));
                                locationSite.latitude = locSite.latitude;
                                locationSite.longitude = locSite.longitude;
                                locationSite.name = site.Public_Name__c;
                                locationSite.postalcode = site.Site__r.Physical_Postal_Code__c;
                                locationSite.distance  = Decimal.valueOf(currentClientLocation.getDistance(site.Site__r.Physical_Geolocation__c, 'mi')).setScale(2);
                                locationSite.addressInfo = site.Site__r.Physical_Street__c + ' ' + site.Site__r.Physical_City__c + ' ' + site.Site__r.Physical_State__c + ', ' + site.Site__r.Physical_Postal_Code__c;
                                locationSite.serviceSitePhone = site.Site_Phone_Number__c;
                                locationSite.serviceTimeAndDate = site.Distribution_Time_and_Date__c;
                                locationSite.emailInfo = site.Info__c;
                                locationSite.smsInfo = site.Text_Info__c;
                                locationList.add(locationSite);
                            }
                        }
                    }
                    if (!locationList.isEmpty()) {
                        ref.locations = locationList;
                    }
                    refList.add(ref);
                }
            }
            
            if (!refList.isEmpty()) {
                response.data = refList;
            }
        }
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static ServiceFilters getServiceObjFilterValues() {
        ServiceFilters response = new ServiceFilters();
        List<ServiceFilter> nonMSP = new List<ServiceFilter>();
        List<ServiceFilter> nonMSPHmg = new List<ServiceFilter>();
        List<MultiPicklist> mSP = new List<MultiPicklist>();

        Map<String,Schema.SObjectType> gd = Schema.getGlobalDescribe(); 
        Schema.SObjectType sobjType = gd.get('Service__c'); 
        Schema.DescribeSObjectResult describeResult = sobjType.getDescribe(); 
        Map<String,Schema.SObjectField> fieldsMap = describeResult.fields.getMap(); 

        Map<String, Resource_Search_Filter__mdt> mapCMDT = new Map<String, Resource_Search_Filter__mdt>();
        for(Resource_Search_Filter__mdt rsf : [SELECT Id, DeveloperName, MasterLabel, Api_Name__c, HMG_Filter__c, Sequence__c
                                                FROM Resource_Search_Filter__mdt
                                                ORDER BY Sequence__c 
                                                NULLS LAST]){
            mapCMDT.put(rsf.DeveloperName, rsf);
        }

        for(String recordCMDT : mapCMDT.keySet()) {
            Schema.SObjectField field = fieldsMap.get(mapCMDT.get(recordCMDT).Api_Name__c);
            Schema.DisplayType fldType = field.getDescribe().getType();
            if (String.valueOf(fldType) == 'MULTIPICKLIST') {
                MultiPicklist mpck = new MultiPicklist();
                mpck.name = field.getDescribe().getLabel();
                mpck.apiName = field.getDescribe().getLocalName();
                mpck.hmg = mapCMDT.get(recordCMDT).HMG_Filter__c;
                List<PicklistValue> values = new List<PicklistValue>(); 
                for (Schema.PicklistEntry value : field.getDescribe().getPickListValues()) {
                    if (value.isActive()) {
                        PicklistValue pckVal= new PicklistValue();
                        pckVal.label = value.getLabel();
                        pckVal.value = value.getValue();
                        values.add(pckVal);
                    }
                }
                mpck.values = values;
                mpck.selected = new List<String>();
                mSP.add(mpck);
            } else {
                if(mapCMDT.get(recordCMDT).HMG_Filter__c){
                    nonMSPHmg.add(new ServiceFilter(mapCMDT.get(recordCMDT).MasterLabel, mapCMDT.get(recordCMDT).Api_Name__c));
                } else {
                    nonMSP.add(new ServiceFilter(mapCMDT.get(recordCMDT).MasterLabel, mapCMDT.get(recordCMDT).Api_Name__c));
                }
            }
        }
        response.nonMultiSelectPicklists = nonMSP;
        response.nonMultiSelectPicklistsHMG = nonMSPHmg;
        response.multiSelectPicklists = mSP;
        return response;
    }

    public class ServiceFilter {
        @AuraEnabled public String label{get;set;}
        @AuraEnabled public String apiName{get;set;}

        public ServiceFilter(String label, String apiName){
            this.label = label;
            this.apiName = apiName;
        }
    }

    private static String buildQuotesParameter(Set<String> ids){
        String idList = '(\'';
        idList += String.join((new List<String>(ids)),'\',\'');
        idList += '\')';
        return idList;
    }

    public static GeoData getCoordinates(Map<String, Object> searchInputs) {
        HttpRequest req = new HttpRequest();
        String urlParameters = '';

        for (String Id : ((Map<String, Object>)searchInputs.get('location')).keySet()) {
            String value = (String)((Map<String, Object>)searchInputs.get('location')).get(Id);
            if (!String.isBlank(value) && Id != 'Street') {
                urlParameters += '&'+Id.toLowerCase()+'=' + EncodingUtil.urlEncode(value, 'UTF-8');
            }
        }
        String url = 'https://nominatim.openstreetmap.org/search?format=json&limit=1' + urlParameters;
        System.debug(url);
        req.setEndpoint(url);
        req.setMethod('GET');
        Http http = new Http();
        HTTPResponse res = http.send(req);
        List<GeoData> geoData;
        try {
            geoData = (List<GeoData>) JSON.deserialize(res.getBody(), List<GeoData>.class);
            if (!geoData.isEmpty()) {
                return geoData[0];
            } else {
                return null;
            }
        } catch (Exception ex) {
            throw new AuraException('Exception In ' + ex.getLineNumber() + ' line, Message: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Zip_Code__c> getAllZipCodes() {
        List<Zip_Code__c> result = [SELECT Id, Zip_Code__c, City__c FROM Zip_Code__c];
        return result;
    }

    @AuraEnabled
    public static ReferralResults getExistingReferrals(String recordId){
        try {
            
            List<Id> serviceIds = new List<Id>();
            Map<Id,Id> serviceIdToReferralId = new Map<Id,Id>();
            String currentCase = [SELECT Current_Case_Id__c FROM Account WHERE Id = :recordId].Current_Case_Id__c;
            ReferralResults response = new ReferralResults();

            if(!String.isBlank(currentCase)){
                for(Referral__c referral : [SELECT Id, Service__c
                                            FROM Referral__c
                                            WHERE Case__c = :currentCase]){
                    serviceIds.add(referral.Service__c);
                }
    
                List<Referral> refList = new List<Referral>();
                String dSoql = 'SELECT Id, Name, Agency_Name__c, Eligibility_Extended__c, Hours_of_Operation_Long__c, PaymentMethods__c, PaymentMethodDetail__c, Intake_Line__c, ApplicationProcess__c, Service_Languages__c, DocumentsRequired__c, Coverage_Area__c, Website__c, Email__c, Description__c, Email_Text_Body__c, Text_Default_Referral_Info__c, Service_Details__c, Direct_Referral_Partner__c, Referral_Type__c, TemporaryMessage__c, TemporaryMessageAppears__c, TemporaryMessageExpires__c, Business_Line__c, Business_Line_Type__c, Business_Line_2__c, Business_Line_2_Type__c, Business_Line_3__c, Business_Line_3_Type__c, Business_Line_4__c, Business_Line_4_Type__c, Other_Phone__c, Other_Phone_Type__c, Toll_Free_Number__c, ' +
                                ' (Select Id, Public_Name__c, Site_Phone_Number__c, Distribution_Time_and_Date__c, Site__r.Name, Site__r.Physical_Geolocation__c, Site__r.Physical_Street__c, Site__r.Physical_City__c, Site__r.Physical_State__c, Site__r.Physical_Postal_Code__c, text_info__c, Info__c FROM Service_Sites__r), ' + 
                                ' (Select Id, Taxonomy__r.Id, Taxonomy__r.Name FROM Service_Taxonomies__r WHERE NOT Code__c LIKE \'Y%\') ' + 
                                ' FROM Service__c ' + 
                                ' WHERE Id IN :serviceIds' + 
                                ' LIMIT 10000';
                
        
                for (Service__c serv : database.query(dSoql)) {
                    Referral ref = new Referral();
                    ref.referral = serv;
                    ref.disable = true;
                    ref.fullEmailBody = serv.Email_Text_Body__c;
                    ref.fullSMSBody = serv.Text_Default_Referral_Info__c;
                    ref.showConsentMessage = false;
                    List<GeoLocationData> locationList = new List<GeoLocationData>();
                    if (!serv.Service_Sites__r.isEmpty()) {
                        for(Service_Site__c site : serv.Service_Sites__r) {
                            GeoLocationData location = new GeoLocationData();
                            if (site.Site__r.Physical_Geolocation__c != null) {
                                Location locSite = site.Site__r.Physical_Geolocation__c;
                                if (locSite.latitude != null && locSite.longitude != null) {
                                    location.latitude = locSite.latitude;
                                    location.longitude = locSite.longitude;
                                    location.name = site.Public_Name__c;
                                    location.postalcode = site.Site__r.Physical_Postal_Code__c;
                                    location.addressInfo = site.Site__r.Physical_Street__c + ' ' + site.Site__r.Physical_City__c + ' ' + site.Site__r.Physical_State__c + ', ' + site.Site__r.Physical_Postal_Code__c;
                                    location.serviceSitePhone = site.Site_Phone_Number__c;
                                    location.serviceTimeAndDate = site.Distribution_Time_and_Date__c;
                                    location.emailInfo = site.Info__c;
                                    location.smsInfo = site.Text_Info__c;
                                }
                            }
                            locationList.add(location);
                        }
                    }
                    if (!locationList.isEmpty()) {
                        ref.locations = locationList;
                    }
                    refList.add(ref);
                }
        
                if (!refList.isEmpty()) {
                    response.data = refList;
                }

            }
            return response; 
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ReferralAndService> createReferrals(String referralsJSON) {
        try {
            List<ReferralAndTaxonomies> referrals = (List<ReferralAndTaxonomies>)JSON.deserializeStrict(referralsJSON, List<ReferralAndTaxonomies>.class);
            // insert referrals;
            Integer indexKey = 0;
            Map<Integer,Referral__c> referralMap = new Map<Integer,Referral__c>();
            Map<Integer,List<String>> taxoMap = new Map<Integer,List<String>>();

            List<Referral_Need__c> needsToInsert = new List<Referral_Need__c>();

            for(ReferralAndTaxonomies refAndTax : referrals){
                indexKey += 1;
                referralMap.put(indexKey, refAndTax.referralItem);
                taxoMap.put(indexKey, refAndTax.extraTaxonomies);
            }

            insert referralMap.values();

            List<ReferralAndService> refAndServices = new List<ReferralAndService>();
            for(Referral__c ref : referralMap.values()){
                refAndServices.add(new ReferralAndService(ref.Id, ref.Service__c));
            }

            for(Integer mapKey : referralMap.keySet()){
                if(taxoMap.containsKey(mapKey)){
                    for(String taxoName : taxoMap.get(mapKey)){
                        needsToInsert.add(new Referral_Need__c(
                            Referral__c = referralMap.get(mapKey).Id,
                            Need__c = taxoName,
                            Case__c = referralMap.get(mapKey).Case__c
                        ));
                    }
                }
            }
            if(!needsToInsert.isEmpty()){
                insert needsToInsert;
            }
            return refAndServices;
        } catch (Exception ex) {
            System.debug(ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public class ReferralAndTaxonomies {
        public Referral__c referralItem{get;set;}
        public List<String> extraTaxonomies{get;set;}
    }

    public class ReferralAndService {
        @AuraEnabled public String referralId{get;set;}
        @AuraEnabled public String serviceId{get;set;}

        public ReferralAndService(String referralId, String serviceId){
            this.referralId = referralId;
            this.serviceId = serviceId;
        }
    }

    private static Set<String> getAlreadyAddedReferralsToCase(String caseId) {
        Set<String> result = new Set<String>();
        for (Referral__c ref : [SELECT Id, Name, Service__c, Service__r.Name from Referral__c where Case__c = :caseId LIMIT 50000]) {
            result.add(ref.Service__c);
        }
        return result;
    }

    @AuraEnabled(cacheable=true) 
    public static Integer getCustomMetadata(){
        return Integer.valueOf(Resource_Search_Location_Search__mdt.getInstance('Sites_to_Show').Value__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getSearchTerms(){
        try {
            List<String> terms = new List<String>();
            for(Common_Search_Term__c cst : [SELECT Name 
                                                FROM Common_Search_Term__c
                                                WHERE Active__c = true
                                                ORDER BY Sequence__c
                                                LIMIT 10000]){
                terms.add(cst.Name);
            }
            return terms;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static RecommendedLogInfo getRecommendedLog(String logId){
        try {
            Search_Log__c log = [SELECT Id, Recommendation_Title__c, Filters_applied__c, Taxonomy_Name__c, Zip_Code__c, Search_Term__c
                                FROM Search_Log__c
                                WHERE Id = :logId];
            RecommendedLogInfo recommendation = new RecommendedLogInfo(log);

            if(log.Taxonomy_Name__c != null){
                Taxonomy__c taxonomy = [SELECT Id, Name
                                        FROM Taxonomy__c
                                        WHERE Name = :log.Taxonomy_Name__c
                                        LIMIT 1];
                recommendation.taxonomyId = taxonomy.Id;
                recommendation.taxonomyName = taxonomy.Name;
            }
            return recommendation;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class RecommendedLogInfo {
        @AuraEnabled public String logId{get;set;}
        @AuraEnabled public String taxonomyId{get;set;}
        @AuraEnabled public String taxonomyName{get;set;}
        @AuraEnabled public String term{get;set;}
        @AuraEnabled public String zipCode{get;set;}
        @AuraEnabled public String filters{get;set;}

        public RecommendedLogInfo(Search_Log__c log){
            this.logId = log.Id;
            this.zipCode = log.Zip_Code__c;
            this.term = log.Search_Term__c;
            this.filters = log.Filters_applied__c;
        }
    }

    global class Taxonomy {
        @AuraEnabled
        global List<TaxonomyChild> childs {get;set;}
        @AuraEnabled
        global Boolean hasChilds {get;set;}
    }

    global class TaxonomyChild {
        @AuraEnabled
        global String name {get;set;}
        @AuraEnabled
        global String id {get;set;} 
        @AuraEnabled
        global Decimal level {get;set;} 
        @AuraEnabled
        global String higherTaxonomies {get;set;} 
    }

    global class ReferralResults {
        @AuraEnabled
        global List<Referral> data {get;set;}
    }

    global class Referral {
        @AuraEnabled
        global Service__c referral {get;set;}
        @AuraEnabled
        global Boolean disable {get;set;}
        @AuraEnabled
        global List<GeoLocationData> locations {get;set;}
        @AuraEnabled
        global String fullEmailBody {get;set;}
        @AuraEnabled
        global String fullSMSBody {get;set;}
        @AuraEnabled
        global Boolean showConsentMessage {get;set;}
    }

    global class GeoLocationData {
        @AuraEnabled
        global Double latitude {get;set;}
        @AuraEnabled
        global Double longitude {get;set;}
        @AuraEnabled
        global String name {get;set;}
        @AuraEnabled
        global Double distance {get;set;}
        @AuraEnabled
        global String addressInfo {get;set;}
        @AuraEnabled
        global String serviceSitePhone {get;set;}
        @AuraEnabled
        global String serviceTimeAndDate {get;set;}
        @AuraEnabled
        global String postalcode {get;set;}
        @AuraEnabled
        global String emailInfo {get;set;}
        @AuraEnabled
        global String smsInfo {get;set;}
    }

    global class GeoData {
        @AuraEnabled
        global String lat{get;set;}
        @AuraEnabled
        global String lon{get;set;}
    }

    global class ServiceFilters {
        @AuraEnabled
        global List<ServiceFilter> nonMultiSelectPicklists{get;set;}
        @AuraEnabled
        global List<ServiceFilter> nonMultiSelectPicklistsHMG{get;set;}
        @AuraEnabled
        global List<MultiPicklist> multiSelectPicklists{get;set;}
    }

    global class MultiPicklist {
        @AuraEnabled
        global String name{get;set;}
        @AuraEnabled
        global String apiName{get;set;}
        @AuraEnabled
        global Boolean hmg{get;set;}
        @AuraEnabled
        global List<PicklistValue> values{get;set;}
        @AuraEnabled
        global List<String> selected{get;set;}
    }

    global class PicklistValue {
        @AuraEnabled
        global String label{get;set;}
        @AuraEnabled
        global String value{get;set;}
    }

    public class RecentSearch {
        @AuraEnabled public String id{get;set;}
        @AuraEnabled public String zipCode{get;set;}
        @AuraEnabled public String taxonomy{get;set;}
        @AuraEnabled public Decimal resultCount{get;set;}
        @AuraEnabled public String jsonInput{get;set;}

        public RecentSearch(Search_Log__c log){
            this.id = log.Id;
            this.zipCode = log.Zip_Code__c;
            this.taxonomy = log.Taxonomy_Name__c;
            this.resultCount = log.Results_Count__c;
            this.jsonInput = log.JSON_Inputs__c;
        }
    }

}