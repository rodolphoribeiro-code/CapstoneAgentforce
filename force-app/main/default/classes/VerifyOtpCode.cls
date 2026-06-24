public class VerifyOtpCode {
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

    @InvocableMethod(label='Verify OTP Code' description='Validates the 6-digit OTP code sent to the customer email. Checks expiry and marks as used.')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.code) || String.isBlank(req.email)) {
                res.verified = false;
                res.errorMessage = 'Email and code are required.';
                results.add(res);
                continue;
            }

            String emailVal = req.email.toLowerCase().trim();
            String codeVal = req.code.trim();
            DateTime now = DateTime.now();

            List<OtpVerification__c> otps = Database.queryWithBinds(
                'SELECT Id, Code__c, ExpiresAt__c, Used__c FROM OtpVerification__c ' +
                'WHERE Email__c = :emailVal AND Used__c = false ' +
                'ORDER BY CreatedDate DESC LIMIT 1',
                new Map<String, Object>{ 'emailVal' => emailVal },
                AccessLevel.SYSTEM_MODE
            );

            if (otps.isEmpty()) {
                res.verified = false;
                res.errorMessage = 'No active verification code found. Please request a new code.';
                results.add(res);
                continue;
            }

            OtpVerification__c otp = otps[0];

            if (otp.ExpiresAt__c < now) {
                otp.Used__c = true;
                update otp;
                res.verified = false;
                res.errorMessage = 'Your verification code has expired. Please request a new one.';
                results.add(res);
                continue;
            }

            if (otp.Code__c != codeVal) {
                res.verified = false;
                res.errorMessage = 'Invalid code. Please check your email and try again.';
                results.add(res);
                continue;
            }

            // Mark as used
            otp.Used__c = true;
            update otp;

            List<Contact> contacts = Database.queryWithBinds(
                'SELECT Id, Name FROM Contact WHERE Email = :emailVal LIMIT 1',
                new Map<String, Object>{ 'emailVal' => emailVal },
                AccessLevel.SYSTEM_MODE
            );

            if (contacts.isEmpty()) {
                res.verified = false;
                res.errorMessage = 'No account found for this email.';
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
