public class GetCustomerProfile {
    public class Request {
        @InvocableVariable(label='Contact Id' required=true)
        public String contactId;
    }

    public class Result {
        @InvocableVariable(label='Found')
        public Boolean found;

        @InvocableVariable(label='Contact Name')
        public String contactName;

        @InvocableVariable(label='Total Bookings')
        public Integer totalBookings;

        @InvocableVariable(label='Confirmed Bookings')
        public Integer confirmedBookings;

        @InvocableVariable(label='Cancelled Bookings')
        public Integer cancelledBookings;

        @InvocableVariable(label='Is VIP')
        public Boolean isVip;

        @InvocableVariable(label='VIP Tier')
        public String vipTier;

        @InvocableVariable(label='Favourite Restaurant')
        public String favouriteRestaurant;

        @InvocableVariable(label='Last Visit Date')
        public String lastVisitDate;

        @InvocableVariable(label='Preferred Dietary Option')
        public String preferredDietaryOption;

        @InvocableVariable(label='Profile Summary')
        public String profileSummary;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(label='Get Customer Profile' description='Retrieves unified customer profile from booking history for personalised responses')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.contactId)) {
                res.found = false;
                res.errorMessage = 'Contact Id is required.';
                results.add(res);
                continue;
            }

            List<Contact> contacts = Database.queryWithBinds(
                'SELECT Id, Name, Email FROM Contact WHERE Id = :contactId LIMIT 1',
                new Map<String, Object>{ 'contactId' => req.contactId },
                AccessLevel.SYSTEM_MODE
            );

            if (contacts.isEmpty()) {
                res.found = false;
                res.errorMessage = 'No contact found for the provided Id.';
                results.add(res);
                continue;
            }

            Contact c = contacts[0];

            List<Booking__c> bookings = Database.queryWithBinds(
                'SELECT Id, Name, Status__c, Restaurant__r.Name, Booking_Date__c, Special_Requests__c ' +
                'FROM Booking__c WHERE Customer_Email__c = :email ' +
                'ORDER BY Booking_Date__c DESC',
                new Map<String, Object>{ 'email' => c.Email },
                AccessLevel.SYSTEM_MODE
            );

            res.found = true;
            res.contactName = c.Name;
            res.totalBookings = bookings.size();

            Integer confirmed = 0;
            Integer cancelled = 0;
            Map<String, Integer> restaurantCount = new Map<String, Integer>();
            String lastVisit = '';
            Map<String, Integer> dietaryCount = new Map<String, Integer>();

            for (Booking__c b : bookings) {
                if (b.Status__c == 'Confirmed' || b.Status__c == 'Modified') {
                    confirmed++;
                }
                if (b.Status__c == 'Cancelled') {
                    cancelled++;
                }
                String rName = b.Restaurant__r != null ? b.Restaurant__r.Name : 'Unknown';
                restaurantCount.put(rName, (restaurantCount.containsKey(rName) ? restaurantCount.get(rName) : 0) + 1);

                if (String.isBlank(lastVisit) && b.Booking_Date__c != null) {
                    lastVisit = b.Booking_Date__c.format();
                }
                if (String.isNotBlank(b.Special_Requests__c)) {
                    String req2 = b.Special_Requests__c.toLowerCase();
                    for (String diet : new List<String>{'vegetarian','vegan','gluten-free','halal','kosher'}) {
                        if (req2.contains(diet)) {
                            dietaryCount.put(diet, (dietaryCount.containsKey(diet) ? dietaryCount.get(diet) : 0) + 1);
                        }
                    }
                }
            }

            res.confirmedBookings = confirmed;
            res.cancelledBookings = cancelled;
            res.lastVisitDate = String.isNotBlank(lastVisit) ? lastVisit : 'No previous visits';

            // VIP status: 5+ confirmed bookings = VIP, 10+ = Gold VIP
            res.isVip = confirmed >= 5;
            res.vipTier = confirmed >= 10 ? 'Gold VIP' : confirmed >= 5 ? 'VIP' : 'Standard';

            // Favourite restaurant
            String fav = '';
            Integer favCount = 0;
            for (String r : restaurantCount.keySet()) {
                if (restaurantCount.get(r) > favCount) {
                    favCount = restaurantCount.get(r);
                    fav = r;
                }
            }
            res.favouriteRestaurant = String.isNotBlank(fav) ? fav : 'None yet';

            // Preferred dietary
            String topDiet = '';
            Integer topDietCount = 0;
            for (String d : dietaryCount.keySet()) {
                if (dietaryCount.get(d) > topDietCount) {
                    topDietCount = dietaryCount.get(d);
                    topDiet = d;
                }
            }
            res.preferredDietaryOption = String.isNotBlank(topDiet) ? topDiet : 'None noted';

            // Summary for the agent
            String tier = res.vipTier;
            res.profileSummary = c.Name + ' is a ' + tier + ' guest with ' + confirmed +
                ' confirmed booking' + (confirmed != 1 ? 's' : '') + '. ' +
                'Favourite restaurant: ' + res.favouriteRestaurant + '. ' +
                'Last visit: ' + res.lastVisitDate + '. ' +
                (res.isVip ? 'VIP benefits: priority seating, complimentary welcome drink' +
                    (confirmed >= 10 ? ', complimentary dessert' : '') + '.' : '');

            results.add(res);
        }

        return results;
    }
}
