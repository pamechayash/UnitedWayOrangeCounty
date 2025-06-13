public class ICarolServiceSyncBatch implements Database.Batchable<Service__c> , Database.Stateful, Database.AllowsCallouts {
    
    private static final String BASE_URL = 'https://api.icarol.com/v1';
    private static final String BEARER_TOKEN = 'Bearer E4F42E57-A48C-4962-9474-AF119555EEA9'; 
    public Map<String,List<Site__c>>  serviceSiteMapping = new Map<String,List<Site__c>>();    
    
    public List<Service__c> start(Database.BatchableContext bc) {
        List<Service__c> recordsToInsert = new List<Service__c>();
        
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + '/Resource/Search');
            req.setMethod('POST');
            req.setHeader('Authorization', BEARER_TOKEN);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            
            String jsonBody = JSON.serialize(new Map<String, Object>{
                'term' => '*',
                    'take' => 5,
                    'resourceType' => 'Program',
                    'status' => 'Active'
                    });
            req.setBody(jsonBody);
            
            HttpResponse httpResponse = http.send(req);
            System.debug('Response Body: ' + httpResponse.getBody());
            
            if (httpResponse.getStatusCode() == 200) {
                try {
                    ICarolServiceWrapper searchServiceResponse = (ICarolServiceWrapper) JSON.deserialize(httpResponse.getBody(), ICarolServiceWrapper.class);

                    System.debug('searchServiceResponse'+searchServiceResponse);

            
                    for (ICarolServiceWrapper.Result result : searchServiceResponse.results) {
                       
                        ICarolServiceWrapper.Resource res = result.resource;
                        Service__c svc = new Service__c();
                        
                        svc.iCarol_Id__c = res.id;
                        svc.Description__c = res.description;
                        svc.Taxonomy_Level_Name__c = res.type;
                        svc.Status__c = 'Inactive';
                        
                        // Names
                        for (ICarolServiceWrapper.Name name : res.names) {
                            if (name.purpose == 'Primary') svc.Name = name.value;
                            if (name.purpose == 'Alternate') svc.Alternate_Name__c = name.value;
                        }
                        
                        // Related Agencies
                        List<Site__c> siteList = new List<Site__c>();
                        for (ICarolServiceWrapper.Related rel : res.related) {
                            
                            if (rel.type == 'Agency') {
                                Account  accountRec = findOrCreateAgencyAccountByName(rel.name);
                                svc.Agency__c = accountRec.Id;
                                recordsToInsert.add(svc); 
                            }
                            
                            if (rel.type == 'Site'){
                                Site__c siteRec = new Site__c();
                                siteRec.Name = rel.name;
                                siteRec.Physical_Geolocation__Latitude__s = rel.contact.latitude;
                                siteRec.Physical_Geolocation__Longitude__s = rel.contact.longitude;
                                // siteRec.City__c = rel.contact.city; restricted picklist
                                siteRec.Physical_Postal_Code__c = rel.contact.zipPostalCode;
                                if(svc.Agency__c!=null){
                                    siteRec.Agency__c  =  svc.Agency__c;
                                }
                                siteList.add(siteRec);
                                
                                
                            }
                            
                            
                        }
         
                        insert siteList;
                        serviceSiteMapping.put(res.id,siteList);
                    } 
                    System.debug('serviceSiteMapping'+serviceSiteMapping);
                } catch (Exception parseEx) {
                    System.debug('Error parsing service response: ' + parseEx.getMessage());
                }
            } else {
                System.debug('Service callout failed with status ' + httpResponse.getStatusCode() + ': ' + httpResponse.getBody());
            }
        } catch (Exception ex) {
            System.debug('HTTP request failed: ' + ex.getMessage());
        }
        
        return recordsToInsert;
    }
    
    public void execute(Database.BatchableContext bc, List<Service__c> recordsToInsert) {
        try {
            System.debug('serviceSiteMapping'+serviceSiteMapping);
            insert recordsToInsert;
            List<Service_Site__c> serviceSiteToInsert = new  List<Service_Site__c>();
            for(Service__c serviceRecord : recordsToInsert){
                List<Site__c> siteListForService = serviceSiteMapping.get(serviceRecord.iCarol_Id__c);
                
                for(Site__c siteRec:siteListForService){
                    Service_Site__c serviceSite = new Service_Site__c();
                    serviceSite.Site__c = siteRec.Id;
                    serviceSite.Service__c = serviceRecord.Id; 
                    serviceSiteToInsert.add(serviceSite);
                }
                
            }
            system.debug('serviceSiteToInsertBefore'+serviceSiteToInsert);
            insert serviceSiteToInsert;
            system.debug('serviceSiteToInsert'+serviceSiteToInsert);
            
        } catch (DmlException dmlEx) {
            System.debug('DML error while inserting services: ' + dmlEx.getMessage());
        }
    }
    
    private static Account findOrCreateAgencyAccountByName(String agencyName) {
        try {
            List<Account> accs = [SELECT Id FROM Account WHERE  RecordType.Name = 'Agency' and Name = :agencyName LIMIT 1];
            if(accs.size()>0){
                return accs[0];
            }
            else
            {
                Account newAcc = new Account(Name=agencyName,recordTypeId = [
                    SELECT Id 
                    FROM RecordType 
                    WHERE SObjectType = 'Account' 
                    AND Name = 'Agency' 
                    LIMIT 1
                ].Id);
                insert newAcc;
                return newAcc;
            }
            
            
        } catch (Exception ex) {
            System.debug('Error fetching agency by name (' + agencyName + '): ' + ex.getMessage());
            return null;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        
    }
}