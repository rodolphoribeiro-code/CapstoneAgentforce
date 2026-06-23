public without sharing class GetRestaurantDetails {

    public class Request {
        @InvocableVariable(label='Restaurant Id or Name' required=true description='Can be a Salesforce Id or restaurant name (partial match supported)')
        public String restaurantIdOrName;
    }

    public class Result {
        @InvocableVariable(label='Found')
        public Boolean found;

        @InvocableVariable(label='Restaurant Id')
        public String restaurantId;

        @InvocableVariable(label='Restaurant Name')
        public String restaurantName;

        @InvocableVariable(label='Cuisine Type')
        public String cuisineType;

        @InvocableVariable(label='Location')
        public String location;

        @InvocableVariable(label='Opening Hours')
        public String openingHours;

        @InvocableVariable(label='Capacity')
        public Integer capacity;

        @InvocableVariable(label='Dietary Options')
        public String dietaryOptions;

        @InvocableVariable(label='Phone')
        public String phone;

        @InvocableVariable(label='Summary')
        public String summary;
    }

    @InvocableMethod(label='Get Restaurant Details' description='Returns full details for a restaurant by Id or name')
    public static List<Result> getDetails(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            List<Restaurant__c> restaurants;
            String reqId = req.restaurantIdOrName;

            if (req.restaurantIdOrName.startsWith('a')) {
                restaurants = Database.query(
                    'SELECT Id, Name, Cuisine_Type__c, Location__c, Opening_Hours__c, Capacity__c, Dietary_Options__c, Phone__c FROM Restaurant__c WHERE Id = :reqId LIMIT 1',
                    AccessLevel.SYSTEM_MODE
                );
            } else {
                String searchTerm = '%' + req.restaurantIdOrName + '%';
                restaurants = Database.query(
                    'SELECT Id, Name, Cuisine_Type__c, Location__c, Opening_Hours__c, Capacity__c, Dietary_Options__c, Phone__c FROM Restaurant__c WHERE Name LIKE :searchTerm LIMIT 1',
                    AccessLevel.SYSTEM_MODE
                );
            }

            if (restaurants.isEmpty()) {
                res.found = false;
                res.summary = 'No restaurant found matching "' + req.restaurantIdOrName + '". Please check the name and try again.';
                results.add(res);
                continue;
            }

            Restaurant__c r = restaurants[0];
            res.found = true;
            res.restaurantId = r.Id;
            res.restaurantName = r.Name;
            res.cuisineType = r.Cuisine_Type__c;
            res.location = r.Location__c;
            res.openingHours = r.Opening_Hours__c;
            res.capacity = r.Capacity__c != null ? Integer.valueOf(r.Capacity__c) : null;
            res.dietaryOptions = r.Dietary_Options__c;
            res.phone = r.Phone__c;
            res.summary = r.Name + ' is a ' + r.Cuisine_Type__c + ' restaurant located at ' + r.Location__c + '. '
                        + 'Hours: ' + r.Opening_Hours__c + '. '
                        + (String.isNotBlank(r.Dietary_Options__c) ? 'Dietary options: ' + r.Dietary_Options__c + '. ' : '')
                        + (String.isNotBlank(r.Phone__c) ? 'Phone: ' + r.Phone__c + '.' : '');

            results.add(res);
        }

        return results;
    }
}
