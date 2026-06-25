public without sharing class CreateBooking {

    public class Request {
        @InvocableVariable(label='Restaurant Name' required=true)
        public String restaurantName;

        @InvocableVariable(label='Booking Date Time' required=true)
        public DateTime bookingDateTime;

        @InvocableVariable(label='Party Size' required=true)
        public Integer partySize;

        @InvocableVariable(label='Customer Name' required=true)
        public String customerName;

        @InvocableVariable(label='Customer Email')
        public String customerEmail;

        @InvocableVariable(label='Special Requests')
        public String specialRequests;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Booking Number')
        public String bookingNumber;
    }

    @InvocableMethod(label='Create Booking' description='Creates a new restaurant booking')
    public static List<Result> createBooking(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            String searchName = '%' + req.restaurantName + '%';
            List<Restaurant__c> restaurants = Database.queryWithBinds(
                'SELECT Id, Name, Capacity__c FROM Restaurant__c WHERE Name LIKE :searchName LIMIT 1',
                new Map<String, Object>{ 'searchName' => searchName },
                AccessLevel.SYSTEM_MODE
            );

            if (restaurants.isEmpty()) {
                res.success = false;
                res.message = 'Restaurant "' + req.restaurantName + '" not found. Please check the name and try again.';
                results.add(res);
                continue;
            }

            Restaurant__c restaurant = restaurants[0];

            if (req.bookingDateTime < DateTime.now()) {
                res.success = false;
                res.message = 'Cannot create a booking in the past. Please choose a future date and time.';
                results.add(res);
                continue;
            }

            if (req.partySize != null && restaurant.Capacity__c != null && req.partySize > restaurant.Capacity__c) {
                res.success = false;
                res.message = 'Sorry, the party size of ' + req.partySize + ' exceeds the capacity of ' + restaurant.Name + '.';
                results.add(res);
                continue;
            }

            // Auto-create or find Contact if email provided
            String emailVal = String.isNotBlank(req.customerEmail) ? req.customerEmail.toLowerCase().trim() : null;
            if (String.isNotBlank(emailVal)) {
                List<Contact> existing = Database.queryWithBinds(
                    'SELECT Id FROM Contact WHERE Email = :emailVal LIMIT 1',
                    new Map<String, Object>{ 'emailVal' => emailVal },
                    AccessLevel.SYSTEM_MODE
                );
                if (existing.isEmpty()) {
                    String fullName = req.customerName.trim();
                    Integer spaceIdx = fullName.indexOf(' ');
                    String firstName = spaceIdx > 0 ? fullName.substring(0, spaceIdx) : '';
                    String lastName  = spaceIdx > 0 ? fullName.substring(spaceIdx + 1) : fullName;
                    insert new Contact(FirstName = firstName, LastName = lastName, Email = emailVal);
                }
            }

            Booking__c booking = new Booking__c(
                Restaurant__c = restaurant.Id,
                Booking_Date__c = req.bookingDateTime,
                Party_Size__c = req.partySize,
                Customer_Name__c = req.customerName,
                Customer_Email__c = emailVal,
                Status__c = 'Confirmed',
                Special_Requests__c = req.specialRequests
            );
            insert booking;

            String bookingId = booking.Id;
            List<Booking__c> created = Database.queryWithBinds(
                'SELECT Name FROM Booking__c WHERE Id = :bookingId LIMIT 1',
                new Map<String, Object>{ 'bookingId' => bookingId },
                AccessLevel.SYSTEM_MODE
            );

            String bkgName = created[0].Name;
            String dateStr = req.bookingDateTime.format('MMMM d, yyyy');
            String timeStr = req.bookingDateTime.format('h:mm a');

            res.success = true;
            res.bookingNumber = bkgName;
            res.message = 'Reservation confirmed at ' + restaurant.Name + '! Booking number: ' + bkgName + '. Party of ' + req.partySize + ' on ' + dateStr + ' at ' + timeStr + '.';

            Boolean emailSent = DinerEmailHelper.sendBookingConfirmation(
                emailVal, req.customerName, bkgName, restaurant.Name, dateStr, timeStr,
                req.partySize, req.specialRequests
            );
            if (emailSent) {
                res.message += ' A confirmation email has been sent to ' + emailVal + '.';
            }

            results.add(res);
        }

        return results;
    }
}
