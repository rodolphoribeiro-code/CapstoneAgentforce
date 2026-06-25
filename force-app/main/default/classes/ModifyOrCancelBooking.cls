public without sharing class ModifyOrCancelBooking {

    public class Request {
        @InvocableVariable(label='Booking Id' required=true)
        public String bookingId;

        @InvocableVariable(label='Action' required=true description='MODIFY or CANCEL')
        public String action;

        @InvocableVariable(label='New Date Time' description='Required when Action is MODIFY')
        public DateTime newDateTime;

        @InvocableVariable(label='New Party Size' description='Optional when Action is MODIFY')
        public Integer newPartySize;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Booking Number')
        public String bookingNumber;

        @InvocableVariable(label='New Status')
        public String newStatus;
    }

    @InvocableMethod(label='Modify Or Cancel Booking' description='Modifies the date/time/party size or cancels an existing booking')
    public static List<Result> modifyOrCancel(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            String bookId = req.bookingId;
            String queryStr = bookId.startsWith('006') || bookId.length() == 18 || bookId.length() == 15
                ? 'SELECT Id, Name, Status__c, Booking_Date__c, Party_Size__c, Booking_Value__c, Is_VIP__c, Customer_Email__c, Restaurant__r.Name FROM Booking__c WHERE Id = :bookId LIMIT 1'
                : 'SELECT Id, Name, Status__c, Booking_Date__c, Party_Size__c, Booking_Value__c, Is_VIP__c, Customer_Email__c, Restaurant__r.Name FROM Booking__c WHERE Name = :bookId LIMIT 1';
            List<Booking__c> bookings = Database.query(queryStr, AccessLevel.SYSTEM_MODE);

            if (bookings.isEmpty()) {
                res.success = false;
                res.message = 'Booking not found. Please verify the booking number and try again.';
                results.add(res);
                continue;
            }

            Booking__c booking = bookings[0];
            res.bookingNumber = booking.Name;

            if (booking.Status__c == 'Cancelled') {
                res.success = false;
                res.message = 'Booking ' + booking.Name + ' is already cancelled.';
                results.add(res);
                continue;
            }

            String custEmail = booking.Customer_Email__c;
            String restaurantName = booking.Restaurant__r.Name;
            String bkgName = booking.Name;

            if (req.action == 'CANCEL') {
                booking.Status__c = 'Cancelled';
                update booking;
                res.success = true;
                res.newStatus = 'Cancelled';
                res.message = 'Booking ' + bkgName + ' at ' + restaurantName + ' has been successfully cancelled.';
                String dateStr = booking.Booking_Date__c != null ? booking.Booking_Date__c.format('MMMM d, yyyy') : '';
                String timeStr = booking.Booking_Date__c != null ? booking.Booking_Date__c.format('h:mm a') : '';
                Boolean emailSent = DinerEmailHelper.sendBookingCancellation(
                    custEmail, bkgName, restaurantName, dateStr, timeStr, Integer.valueOf(booking.Party_Size__c)
                );
                if (emailSent) res.message += ' A cancellation confirmation has been sent to ' + custEmail + '.';

            } else if (req.action == 'MODIFY') {
                if (req.newDateTime != null) {
                    if (req.newDateTime < DateTime.now()) {
                        res.success = false;
                        res.message = 'Cannot modify booking to a date in the past. Please choose a future date.';
                        results.add(res);
                        continue;
                    }
                    booking.Booking_Date__c = req.newDateTime;
                }
                if (req.newPartySize != null && req.newPartySize > 0) {
                    booking.Party_Size__c = req.newPartySize;
                }
                booking.Status__c = 'Modified';
                update booking;
                res.success = true;
                res.newStatus = 'Modified';
                res.message = 'Booking ' + bkgName + ' at ' + restaurantName + ' has been updated successfully.';
                DateTime bookingDT = req.newDateTime != null ? req.newDateTime : booking.Booking_Date__c;
                if (req.newDateTime != null) {
                    res.message += ' New date/time: ' + bookingDT.format('MMMM d, yyyy') + ' at ' + bookingDT.format('h:mm a') + '.';
                }
                Integer partySize = req.newPartySize != null ? req.newPartySize : Integer.valueOf(booking.Party_Size__c);
                Boolean emailSent = DinerEmailHelper.sendBookingModification(
                    custEmail, bkgName, restaurantName,
                    bookingDT.format('MMMM d, yyyy'), bookingDT.format('h:mm a'), partySize
                );
                if (emailSent) {
                    res.message += ' A confirmation email with your updated details has been sent to ' + custEmail + '.';
                }

            } else {
                res.success = false;
                res.message = 'Invalid action. Use MODIFY or CANCEL.';
            }

            results.add(res);
        }

        return results;
    }
}
