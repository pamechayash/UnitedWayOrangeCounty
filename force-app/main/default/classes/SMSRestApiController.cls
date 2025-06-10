/**
 * This class contains methods to make a callout to a SMS Rest API.
 * The credentials are saved as a Custom Metedata record from SMS_EMS__mdt
 */
public with sharing class SMSRestApiController {
    private final static string BOUNDARY = '----sfdc-multi-form';
    public static HttpResponse makeSMSRestCalloutFormData(SMS__c sms){
        SMS_EMS__mdt smsAPIInfo = SMS_EMS__mdt.getInstance('SMS_EMS_Integration');
        String formDataString = writeParam( 'api_key', smsAPIInfo.Api_Key__c );
        formDataString += writeParam( 'api_v', smsAPIInfo.Api_Version__c );
        formDataString += writeParam( 'phone_numbers', sms.Phone_Number__c );
        formDataString += writeParam( 'shortcode', smsAPIInfo.ShortCode__c );
        formDataString += writeParam( 'keyword', smsAPIInfo.Keyword__c );
        
        if(!String.isBlank(sms.BodyLong__c )){
            formDataString += writeParam( 'message', sms.BodyLong__c  );
        }

        Blob formData = EncodingUtil.convertFromHex( formDataString );


        HttpRequest request = new HttpRequest();
        request.setEndpoint(smsAPIInfo.Endpoint__c);
        request.setHeader( 'Content-Length', String.valueOf(formData.size()) );
        request.setHeader( 'Content-Type', 'multipart/form-data; boundary="----sfdc-multi-form"' );
        request.setMethod('POST');
        request.setBodyAsBlob(formData);

        Http http = new Http();        
        HttpResponse response = http.send(request);
        return response;
    }
    public static string writeParam( String key, String value ) {
        String body = '--' + BOUNDARY;
        body += '\r\nContent-Disposition: form-data; name="' + key + '";\r\n\r\n' + value + '\r\n';
        
        return EncodingUtil.convertToHex( Blob.valueOf( body ) );
    }
    public class ApiResponse {
        public List<String> fail;
        public List<String> success;
        public List<String> error;
    }
}