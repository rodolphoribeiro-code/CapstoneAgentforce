public without sharing class GetMyReservations {
    public class Request {
        @InvocableVariable(label='Customer Email' required=true)
        public String customerEmail;
    }

    public class Result {
        @InvocableVariable(label='Found')
        public Boolean found;

        @InvocableVariable(label='Total Count')
        public Integer totalCount;

        @InvocableVariable(label='Reservations Summary')
        public String reservationsSummary;

        @InvocableVariable(label='No Reservations Message')
        public String noReservationsMessage;
    }

    @InvocableMethod(label='Get My Reservations' description='Returns all bookings for the authenticated customer')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.customerEmail)) {
                res.found = false;
                res.noReservationsMessage = 'No email provided.';
                results.add(res);
                continue;
            }

            String emailVal = req.customerEmail.toLowerCase().trim();

            List<Booking__c> bookings = Database.queryWithBinds(
                'SELECT Name, Restaurant__r.Name, Booking_Date__c, Party_Size__c, Status__c, Special_Requests__c ' +
                'FROM Booking__c ' +
                'WHERE Customer_Email__c = :emailVal ' +
                'ORDER BY Booking_Date__c DESC ' +
                'LIMIT 10',
                new Map<String, Object>{ 'emailVal' => emailVal },
                AccessLevel.SYSTEM_MODE
            );

            if (bookings.isEmpty()) {
                res.found = false;
                res.totalCount = 0;
                res.noReservationsMessage = 'No reservations found for ' + req.customerEmail + '.';
                results.add(res);
                continue;
            }

            res.found = true;
            res.totalCount = bookings.size();

            String summary = 'You have ' + bookings.size() + ' reservation' + (bookings.size() > 1 ? 's' : '') + ':\n\n';
            Integer i = 1;
            for (Booking__c b : bookings) {
                String restaurant = b.Restaurant__r != null ? b.Restaurant__r.Name : 'Unknown';
                String dateStr = b.Booking_Date__c != null ? b.Booking_Date__c.format('MMMM d, yyyy') : 'TBD';
                String timeStr = b.Booking_Date__c != null ? b.Booking_Date__c.format('h:mm a') : '';
                summary += i + '. ' + b.Name + ' — ' + restaurant + '\n';
                summary += '   Date: ' + dateStr + ' at ' + timeStr + '\n';
                summary += '   Guests: ' + Integer.valueOf(b.Party_Size__c) + ' | Status: ' + b.Status__c + '\n';
                if (String.isNotBlank(b.Special_Requests__c)) {
                    summary += '   Requests: ' + b.Special_Requests__c + '\n';
                }
                summary += '\n';
                i++;
            }

            res.reservationsSummary = summary.trim();
            results.add(res);
        }

        return results;
    }
}
