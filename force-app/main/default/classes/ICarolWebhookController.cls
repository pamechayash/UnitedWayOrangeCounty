@RestResource(urlMapping='/icarolhook')
global with sharing class ICarolWebhookController {
    
    //Handles POST requests and saves the raw JSON payload to the Integration__c object.
    @HttpPost
    global static void receivePayload() {
        RestRequest req = RestContext.request;
  		RestResponse res = RestContext.response;
        String body = req.requestBody.toString();
        Integration__c record = new Integration__c();
        record.DxF_to_GetHelp_Put__c = body;
        try {
            insert record;
            res.statusCode = 201;   //success
            res.responseBody = Blob.valueOf('Record Created Successfully');           
        } catch (Exception e) {
        	res.statusCode = 500;  //failed
          	res.responseBody = Blob.valueOf('Server Error: ' + e.getMessage());
        }    
    }
}