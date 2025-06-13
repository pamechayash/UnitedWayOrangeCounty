public with sharing class ServiceLocator {
    
    //Method to get top 10 closest services to the input lat/lon
    @AuraEnabled
    public static list<Service__c> getTop10NearestServices(Decimal inputLat, Decimal inputLon){
        //Fetch all services with coordinates
        List<Service__c> allServices = [select id,name, Website__c, Email__c, Description__c, Hours_of_Operation_Long__c, Program_Service_Days__c from service__c limit 10];
        //List to hold services and their distances
        List<ServiceDistanceWrapper> servicesWithDistance = new List<ServiceDistanceWrapper>();
        for(Service__c service : allServices){
            //double distance = calculateHaversineDistance(inputLat,inputLon,service.Latitude__c, service.Longitude__c);
            double distance = 10.10;
            servicesWithDistance.add(new ServiceDistanceWrapper(service,distance));
        }
        //Sort by distance
        servicesWithDistance.sort();
        //Return top 10 services
        List<Service__c> top10 = new List<Service__c>();
        for(integer i=0;i<math.min(10,servicesWithDistance.size());i++){
            top10.add(servicesWithDistance[i].service);
        }
        return top10;
    }
    //Haversine Formula implementation
    public static double calculateHaversineDistance(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2){
        final Double R = 6371.0; // Radius of the earth in KM
        Double dLat = (lat2 - lat1).doubleValue() * Math.PI / 180;
        Double dLon = (lon2 - lon1).doubleValue() * Math.PI / 180;
        Double radLat1 = lat1.doubleValue() * Math.PI / 180;
        Double radLat2 = lat2.doubleValue() * Math.PI / 180;
        // Haversine formula
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(radLat1) * Math.cos(radLat2) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        
        return R * c; // Distance in KM
    }
    
    //Helper class to sort services by distance
    public class ServiceDistanceWrapper implements Comparable{
        @AuraEnabled
        public Service__c service;
        @AuraEnabled
        public Double distance;
        public ServiceDistanceWrapper(Service__C service, Double distance){
            this.service = service;
            this.distance = distance;
        }
        public Integer compareTo(Object o){
            //ServiceDistanceWrapper other =  o;
            return 1;//this.compareTo(o);
        }
    }
}