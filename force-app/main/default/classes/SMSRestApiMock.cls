/**
 * Class that mocks the response from the API page.
 * Used for testing purposes by SMSTriggerHandlerTest
 */
@isTest
global class SMSRestApiMock implements HttpCalloutMock {
    // Implement this interface method
    global HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"fail":[],"success":["12099216581"],"error":[]}');
        res.setStatusCode(200);
        return res;
    }
}