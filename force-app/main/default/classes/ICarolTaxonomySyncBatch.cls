public class ICarolTaxonomySyncBatch implements Database.Batchable<Taxonomy__c>, Database.Stateful, Database.AllowsCallouts {
    
    private static final String BASE_URL = 'https://api.icarol.com/v1';
    private static final String BEARER_TOKEN = 'Bearer E4F42E57-A48C-4962-9474-AF119555EEA9'; 
    
    public List<Taxonomy__c> start(Database.BatchableContext bc) {
        List<Taxonomy__c> taxonomiesToUpsert = new List<Taxonomy__c>();
        
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + '/Resource/Taxonomy');
            req.setMethod('GET');
            req.setHeader('Authorization', BEARER_TOKEN);
            req.setHeader('Accept', 'application/json');
            
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                try {
                    List<Object> taxonomies = (List<Object>) JSON.deserializeUntyped(res.getBody());
                    
                    for (Object taxonomy : taxonomies) {
                        
                        Map<String, Object> record = (Map<String, Object>) taxonomy;
                        String code = (String) record.get('code');
                        String dbId = String.valueOf(record.get('databaseID'));
                        String combinedId = dbId + '-' + code;
                        Integer randomFourDigit = Math.mod(Math.abs(Crypto.getRandomInteger()), 9000) + 1000;
                        
                        Taxonomy__c tax = new Taxonomy__c();
                        tax.iCarol_Id__c = combinedId;
                        tax.iCarol_Code__c = code;
                        tax.Code__c = 'Code' + String.valueOf(randomFourDigit); // Required field
                        tax.Name = (String) record.get('name');
                        tax.Path__c = (String) record.get('path');
                        tax.Definition__c = (String) record.get('definition');
                        tax.Keywords__c = String.join((List<Object>) record.get('synonyms'), ', ');
                        taxonomiesToUpsert.add(tax);
                        
                    }
                } catch (Exception parseEx) {
                    System.debug('Error parsing response JSON: ' + parseEx.getMessage());
                }
            } else {
                System.debug('Failed to fetch Taxonomy. Status Code: ' + res.getStatusCode() + ' | Body: ' + res.getBody());
            }
        } catch (Exception ex) {
            System.debug('HTTP callout failed: ' + ex.getMessage());
        }
        
        return taxonomiesToUpsert;
    }
    
    public void execute(Database.BatchableContext bc, List<Taxonomy__c> taxonomiesToUpsert) {
        try {
            upsert taxonomiesToUpsert iCarol_Id__c;
        } catch (DmlException dmlEx) {
            System.debug('DML Exception during upsert: ' + dmlEx.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        
    }
}