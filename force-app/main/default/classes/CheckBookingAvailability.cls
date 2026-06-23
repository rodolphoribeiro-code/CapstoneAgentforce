public without sharing class CheckBookingAvailability {

    public class Request {
        @InvocableVariable(label='Restaurant Id' required=true)
        public String restaurantId;

        @InvocableVariable(label='Requested Date Time' required=true)
        public DateTime requestedDateTime;

        @InvocableVariable(label='Party Size' required=true)
        public Integer partySize;
    }

    public class Result {
        @InvocableVariable(label='Is Available')
        public Boolean isAvailable;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Restaurant Name')
        public String restaurantName;

        @InvocableVariable(label='Available Slots')
        public String availableSlots;
    }

    @InvocableMethod(label='Check Booking Availability' description='Checks if a restaurant has availability for the requested date, time and party size')
    public static List<Result> checkAvailability(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            String restId = req.restaurantId;
            List<Restaurant__c> restaurants = Database.query(
                'SELECT Id, Name, Capacity__c, Opening_Hours__c FROM Restaurant__c WHERE Id = :restId LIMIT 1',
                AccessLevel.SYSTEM_MODE
            );

            if (restaurants.isEmpty()) {
                res.isAvailable = false;
                res.message = 'Restaurant not found.';
                results.add(res);
                continue;
            }

            Restaurant__c restaurant = restaurants[0];
            res.restaurantName = restaurant.Name;

            DateTime reqDT = req.requestedDateTime;
            Integer existingBookings = Database.countQuery(
                'SELECT COUNT() FROM Booking__c WHERE Restaurant__c = :restId AND Booking_Date__c = :reqDT AND Status__c IN (\'Confirmed\', \'Modified\')',
                AccessLevel.SYSTEM_MODE
            );

            Integer totalBooked = existingBookings * 2;
            Integer capacity = restaurant.Capacity__c != null ? Integer.valueOf(restaurant.Capacity__c) : 50;

            if ((totalBooked + req.partySize) <= capacity) {
                res.isAvailable = true;
                res.message = 'Available! ' + restaurant.Name + ' can accommodate your party of ' + req.partySize + ' on ' + req.requestedDateTime.format('MMMM d, yyyy') + ' at ' + req.requestedDateTime.format('h:mm a') + '.';
                res.availableSlots = String.valueOf(capacity - totalBooked);
            } else {
                res.isAvailable = false;
                res.message = 'Sorry, ' + restaurant.Name + ' is fully booked for that time. Would you like to try a different time or date?';
                res.availableSlots = '0';
            }

            results.add(res);
        }

        return results;
    }
}
