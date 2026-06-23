public class VerifyOtpCode {
    private static final String DEMO_CODE = '123456';

    public class Request {
        @InvocableVariable(label='Email' required=true)
        public String email;

        @InvocableVariable(label='Code' required=true)
        public String code;
    }

    public class Result {
        @InvocableVariable(label='Verified')
        public Boolean verified;

        @InvocableVariable(label='Contact Id')
        public String contactId;

        @InvocableVariable(label='Contact Name')
        public String contactName;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(label='Verify OTP Code' description='Verifies a 6-digit OTP code against the customer email')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.code) || req.code.trim() != DEMO_CODE) {
                res.verified = false;
                res.errorMessage = 'Invalid code. Please check your email and try again.';
                results.add(res);
                continue;
            }

            String emailVal = req.email.toLowerCase().trim();
            List<Contact> contacts = Database.queryWithBinds(
                'SELECT Id, Name FROM Contact WHERE Email = :emailVal LIMIT 1',
                new Map<String, Object>{ 'emailVal' => emailVal },
                AccessLevel.SYSTEM_MODE
            );

            if (contacts.isEmpty()) {
                res.verified = false;
                res.errorMessage = 'No account found with that email address.';
                results.add(res);
                continue;
            }

            res.verified = true;
            res.contactId = contacts[0].Id;
            res.contactName = contacts[0].Name;
            results.add(res);
        }

        return results;
    }
}
