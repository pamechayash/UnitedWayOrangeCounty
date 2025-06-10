public with sharing class iCarolConnect Implements  Schedulable {
     private static final String BASE_URL = 'https://api.icarol.com/v1';
    private static final String BEARER_TOKEN = 'Bearer E4F42E57-A48C-4962-9474-AF119555EEA9'; 

    // GET /Database
    public static String getDatabaseInfo() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/Database');
        req.setMethod('GET');
         req.setHeader('Authorization', BEARER_TOKEN);
        req.setHeader('Accept', 'application/json');
        
        HttpResponse res = http.send(req);
        return res.getBody();
    }

    // GET /Resource/Taxonomy
    public static void getTaxonomy() {
       Database.executeBatch(new ICarolTaxonomySyncBatch(), 500);   
    }

    // POST /Resource/Search
    public static void searchResources() {
        Database.executeBatch(new ICarolServiceSyncBatch(), 500);
    }
     public void execute(SchedulableContext sc) {
    getTaxonomy();
    searchResources(); 
    }
  
}