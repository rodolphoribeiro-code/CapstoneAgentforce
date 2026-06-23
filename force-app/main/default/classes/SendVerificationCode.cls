public class SendVerificationCode {
    public class Request {
        @InvocableVariable(label='Email' required=true)
        public String email;
    }

    public class Result {
        @InvocableVariable(label='Sent')
        public Boolean sent;

        @InvocableVariable(label='Contact Found')
        public Boolean contactFound;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Email Used')
        public String emailUsed;
    }

    @InvocableMethod(label='Send Verification Code' description='Checks if a Contact exists for the email and sends a verification code')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.email)) {
                res.sent = false;
                res.contactFound = false;
                res.message = 'Please provide a valid email address.';
                results.add(res);
                continue;
            }

            String emailVal = req.email.toLowerCase().trim();
            List<Contact> contacts = Database.queryWithBinds(
                'SELECT Id FROM Contact WHERE Email = :emailVal LIMIT 1',
                new Map<String, Object>{ 'emailVal' => emailVal },
                AccessLevel.SYSTEM_MODE
            );

            if (contacts.isEmpty()) {
                res.sent = false;
                res.contactFound = false;
                res.emailUsed = emailVal;
                res.message = 'No account found with that email address. Please try a different email or speak with a team member.';
                results.add(res);
                continue;
            }

            // For demo purposes the code is fixed at 123456
            res.sent = true;
            res.contactFound = true;
            res.emailUsed = emailVal;
            res.message = 'A 6-digit verification code has been sent to ' + req.email + '. Please check your inbox and enter the code.';
            results.add(res);
        }

        return results;
    }
}
