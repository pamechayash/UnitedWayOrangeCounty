@isTest
global class GetCoordinatesMock implements HttpCalloutMock {

    private static final String RESPONSE_BODY ='[{"icon": "https://nominatim.openstreetmap.org/ui/mapicons/poi_boundary_administrative.p.20.png", "importance":0.5207928158035375, "lat":40.73415662768415, "licence":"OpenStreetMap", "lon":-74.00749712946981}]';

    global HTTPResponse respond(HttpRequest req){
        HttpResponse resp=new HttpResponse();
        resp.setBody(RESPONSE_BODY);
        resp.setStatusCode(200);
        return resp;
    }
 }