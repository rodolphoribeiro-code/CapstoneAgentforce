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

            // Send confirmation email if customer email is available
            if (String.isNotBlank(emailVal)) {
                try {
                    OrgWideEmailAddress owa = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{ emailVal });
                    mail.setOrgWideEmailAddressId(owa.Id);
                    mail.setSubject('Booking Confirmed — ' + restaurant.Name + ' (' + bkgName + ')');
                    mail.setHtmlBody(
                        '<div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto">' +
                        '<div style="background:#1a1a1a;padding:24px;text-align:center">' +
                        '<h1 style="color:#c8a96e;margin:0;font-size:1.4rem">The Diner</h1>' +
                        '<p style="color:rgba(255,255,255,.6);margin:.4rem 0 0;font-size:.85rem">Your reservation is confirmed 🎉</p>' +
                        '</div>' +
                        '<div style="padding:28px;border:1px solid #e8e0d0;border-top:none">' +
                        '<h2 style="color:#1a1a1a;margin:0 0 1.2rem;font-size:1.1rem">Hi ' + req.customerName.split(' ')[0] + '!</h2>' +
                        '<p style="color:#555;margin-bottom:1.5rem">We have your table ready. Here are your booking details:</p>' +
                        '<table style="width:100%;border-collapse:collapse;font-size:.9rem">' +
                        '<tr style="border-bottom:1px solid #f0e8d8"><td style="padding:.6rem 0;color:#888;width:120px">Booking #</td><td style="padding:.6rem 0;font-weight:700;color:#1a1a1a">' + bkgName + '</td></tr>' +
                        '<tr style="border-bottom:1px solid #f0e8d8"><td style="padding:.6rem 0;color:#888">Restaurant</td><td style="padding:.6rem 0;font-weight:600;color:#1a1a1a">' + restaurant.Name + '</td></tr>' +
                        '<tr style="border-bottom:1px solid #f0e8d8"><td style="padding:.6rem 0;color:#888">Date</td><td style="padding:.6rem 0;color:#1a1a1a">' + dateStr + '</td></tr>' +
                        '<tr style="border-bottom:1px solid #f0e8d8"><td style="padding:.6rem 0;color:#888">Time</td><td style="padding:.6rem 0;color:#1a1a1a">' + timeStr + '</td></tr>' +
                        '<tr style="border-bottom:1px solid #f0e8d8"><td style="padding:.6rem 0;color:#888">Party size</td><td style="padding:.6rem 0;color:#1a1a1a">' + req.partySize + ' guest' + (req.partySize > 1 ? 's' : '') + '</td></tr>' +
                        (String.isNotBlank(req.specialRequests) ? '<tr><td style="padding:.6rem 0;color:#888">Special requests</td><td style="padding:.6rem 0;color:#1a1a1a">' + req.specialRequests + '</td></tr>' : '') +
                        '</table>' +
                        '<div style="background:#f7f5f0;border-radius:8px;padding:14px 16px;margin-top:1.5rem">' +
                        '<p style="margin:0;font-size:.82rem;color:#666">Need to change or cancel? Chat with <strong>Aria</strong> anytime — free cancellation up to 24 hours before your booking.</p>' +
                        '</div>' +
                        '</div>' +
                        '<div style="background:#f7f5f0;padding:14px;text-align:center;font-size:.75rem;color:#999">' +
                        'The Diner Restaurant Group — See you soon! 🍽️</div>' +
                        '</div>'
                    );
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
                } catch (Exception e) {
                    // Email failure should not block booking confirmation
                    System.debug('Booking confirmation email failed: ' + e.getMessage());
                }
            }

            results.add(res);
        }

        return results;
    }
}
