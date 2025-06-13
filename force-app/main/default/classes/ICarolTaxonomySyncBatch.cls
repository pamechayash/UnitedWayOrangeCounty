public class ICarolTaxonomySyncBatch implements Database.Batchable<Taxonomy__c>, Database.Stateful, Database.AllowsCallouts {
    
    private static final String BASE_URL = 'https://api.icarol.com/v1';
    private static final String BEARER_TOKEN = 'Bearer E4F42E57-A48C-4962-9474-AF119555EEA9'; 
    
    public List<Taxonomy__c> start(Database.BatchableContext bc) {
        List<Taxonomy__c> taxonomiesForDml = new List<Taxonomy__c>();
        
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
                    
                    Set<String> taxonomyNames = new Set<String>();
                    for (Object item : taxonomies) {
                        Map<String,Object> tax = (Map<String,Object>) JSON.deserializeUntyped(json.serialize(item));
                        taxonomyNames.add((String)tax.get('name'));
                    }
                    
                    // Fetch existing taxonomy records in a single query
                    Map<String, Taxonomy__c> existingMap = new Map<String, Taxonomy__c>();
                    for( Taxonomy__c taxonomy  :[SELECT Id, Name, iCarol_Id__c FROM Taxonomy__c WHERE Name IN :taxonomyNames]){
                        existingMap.put(taxonomy.Name,taxonomy);
                    }
                    
                    
                    System.debug('existingMap'+json.serializePretty(existingMap));
                    for (Object taxonomy : taxonomies) {
                        
                        Map<String, Object> record = (Map<String, Object>) taxonomy;
                        String name = (String)record.get('name');
                        String code = (String)record.get('code');
                        String path = (String)record.get('path');
                        String definition = (String)record.get('definition');
                        String keywords = (String) record.get('keywords');
                        Integer dbId = (Integer)record.get('databaseID');
                        String combinedId = dbId + '-' + code;
                        
                        if (existingMap.containsKey(name)) {
                            Taxonomy__c existing = existingMap.get(name);
                            if(existing.iCarol_Id__c!=combinedId){
                                existing.iCarol_Id__c = combinedId;
                                taxonomiesForDml.add(existing);  
                            }      
                        } else {
                            Taxonomy__c newTax = new Taxonomy__c();
                            newTax.Name = name;
                            newTax.iCarol_Id__c = combinedId;
                            newTax.Status__c = 'new';
                            newTax.iCarol_Code__c = code;
                            newTax.Path__c = path;
                            newTax.Definition__c =  definition;
                            newTax.Keywords__c= keywords;
                            taxonomiesForDml.add(newTax);
                        }           
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
        
        return taxonomiesForDml;
    }
    
    public void execute(Database.BatchableContext bc, List<Taxonomy__c> taxonomiesForDml) {
        try {
            List<Taxonomy__c> toUpdate =new  List<Taxonomy__c>();
            List<Taxonomy__c> toInsert =new  List<Taxonomy__c>();
            for(Taxonomy__c taxonomy :taxonomiesForDml){
                (taxonomy.Id == null ? toInsert : toUpdate).add(taxonomy);
            }
            insert toInsert;
            update toUpdate; 
        } catch (DmlException dmlEx) {
            System.debug('DML Exception during upsert: ' + dmlEx.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        
    }
}