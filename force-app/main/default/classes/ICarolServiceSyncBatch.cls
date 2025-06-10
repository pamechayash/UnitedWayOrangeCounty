public class ICarolServiceSyncBatch implements Database.Batchable<Service__c>, Database.Stateful, Database.AllowsCallouts {
    
    private static final String BASE_URL = 'https://api.icarol.com/v1';
    private static final String BEARER_TOKEN = 'Bearer E4F42E57-A48C-4962-9474-AF119555EEA9'; 
    
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
                    
                    Integer i = 0;
                    for (ICarolServiceWrapper.Result result : searchServiceResponse.results) {
                        if (i >= 1) break;
                        i++;
                        
                        
                        ICarolServiceWrapper.Resource res = result.resource;
                        Service__c svc = new Service__c();
                        
                        svc.iCarol_Id__c = res.id;
                        svc.Description__c = res.description;
                        svc.Taxonomy_Level_Name__c = res.type;
                        svc.Status__c = res.status;
                        
                        // Names
                        for (ICarolServiceWrapper.Name name : res.names) {
                            if (name.purpose == 'Primary') svc.Name = name.value;
                            if (name.purpose == 'Alternate') svc.Alternate_Name__c = name.value;
                        }
                        
                        // Related Agencies
                        for (ICarolServiceWrapper.Related rel : res.related) {
                            if (rel.type == 'Agency') {
                                Id agencyId = getAgencyAccountIdByName(rel.name);
                                if (agencyId != null) svc.Agency__c = agencyId;
                            }
                        }
                        
                        recordsToInsert.add(svc);
                    }
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
            insert recordsToInsert;
        } catch (DmlException dmlEx) {
            System.debug('DML error while inserting services: ' + dmlEx.getMessage());
        }
    }
    
    private static Id getAgencyAccountIdByName(String name) {
        try {
            List<Account> accs = [SELECT Id FROM Account WHERE Name = :name LIMIT 2];
            return accs.size() == 1 ? accs[0].Id : null;
        } catch (Exception ex) {
            System.debug('Error fetching agency by name (' + name + '): ' + ex.getMessage());
            return null;
        }
    }
    
    public void finish(Database.BatchableContext bc) {

    }
}