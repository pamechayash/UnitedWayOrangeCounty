public class ICarolServiceWrapper {
    public Integer totalResultCount;
    public List<Result> results;

    public class Result {
        public Resource resource;
    }

    public class Resource {
        public String id;
        public Integer databaseID;
        public List<Name> names;
        public String description;
        public String type;
        public List<Related> related;
        public String status;
        public String modified;
    }

    public class Name {
        public String value;
        public String purpose;
    }

    public class Related {
        public Long id;
        public String type;
        public String name;
        public Contact contact;
    }

    public class Contact {
        public String city;
    }
}