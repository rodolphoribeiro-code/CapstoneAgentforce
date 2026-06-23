public class VerifyCustomerIdentity {
    public class Request {
        @InvocableVariable(label='Email' description='Customer email address' required=true)
        public String email;

        @InvocableVariable(label='Booking Number' description='Existing booking number in format BKG-XXXX' required=true)
        public String bookingNumber;
    }

    public class Result {
        @InvocableVariable(label='Verified' description='True if identity was successfully verified')
        public Boolean verified;

        @InvocableVariable(label='Contact Id' description='Salesforce Contact Id of the verified customer')
        public String contactId;

        @InvocableVariable(label='Contact Name' description='Full name of the verified customer')
        public String contactName;

        @InvocableVariable(label='Error Message' description='Reason verification failed')
        public String errorMessage;
    }

    @InvocableMethod(label='Verify Customer Identity' description='Verifies a customer by matching their email and an existing booking number')
    public static List<Result> verify(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.email) || String.isBlank(req.bookingNumber)) {
                res.verified = false;
                res.errorMessage = 'Email and booking number are required.';
                results.add(res);
                continue;
            }

            String emailVal = req.email.toLowerCase().trim();
            Map<String, Object> contactBinds = new Map<String, Object>{ 'emailVal' => emailVal };
            List<Contact> contacts = Database.queryWithBinds(
                'SELECT Id, Name FROM Contact WHERE Email = :emailVal LIMIT 1',
                contactBinds,
                AccessLevel.SYSTEM_MODE
            );

            if (contacts.isEmpty()) {
                res.verified = false;
                res.errorMessage = 'No account found with that email address.';
                results.add(res);
                continue;
            }

            Contact c = contacts[0];
            String bookingNum = req.bookingNumber.toUpperCase().trim();

            Map<String, Object> bookingBinds = new Map<String, Object>{
                'bookingNum' => bookingNum,
                'emailVal' => emailVal
            };
            List<Booking__c> bookings = Database.queryWithBinds(
                'SELECT Id, Name FROM Booking__c WHERE Name = :bookingNum AND Customer_Email__c = :emailVal LIMIT 1',
                bookingBinds,
                AccessLevel.SYSTEM_MODE
            );

            if (bookings.isEmpty()) {
                res.verified = false;
                res.errorMessage = 'That booking number was not found on your account. Please check and try again.';
                results.add(res);
                continue;
            }

            res.verified = true;
            res.contactId = c.Id;
            res.contactName = c.Name;
            results.add(res);
        }

        return results;
    }
}
