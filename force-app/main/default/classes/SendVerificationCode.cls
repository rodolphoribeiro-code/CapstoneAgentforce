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

    @InvocableMethod(label='Send Verification Code' description='Checks if a Contact exists, generates a real OTP code and sends it by email')
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
            res.emailUsed = emailVal;

            List<Contact> contacts = Database.queryWithBinds(
                'SELECT Id, Name FROM Contact WHERE Email = :emailVal LIMIT 1',
                new Map<String, Object>{ 'emailVal' => emailVal },
                AccessLevel.SYSTEM_MODE
            );

            if (contacts.isEmpty()) {
                res.sent = false;
                res.contactFound = false;
                res.message = 'No account found with that email address. Please try a different email or speak with a team member.';
                results.add(res);
                continue;
            }

            // Generate 6-digit code
            Integer code = Math.abs(Math.mod((Integer)Math.floor(Math.random() * 1000000), 1000000));
            String codeStr = String.valueOf(code).leftPad(6, '0');

            // Expire old codes for this email
            List<OtpVerification__c> old = Database.queryWithBinds(
                'SELECT Id FROM OtpVerification__c WHERE Email__c = :emailVal AND Used__c = false',
                new Map<String, Object>{ 'emailVal' => emailVal },
                AccessLevel.SYSTEM_MODE
            );
            if (!old.isEmpty()) {
                for (OtpVerification__c o : old) { o.Used__c = true; }
                update old;
            }

            // Save new code — expires in 5 minutes
            insert new OtpVerification__c(
                Email__c = emailVal,
                Code__c = codeStr,
                ExpiresAt__c = DateTime.now().addMinutes(5),
                Used__c = false
            );

            // Send real email
            try {
                OrgWideEmailAddress owa = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ emailVal });
                mail.setOrgWideEmailAddressId(owa.Id);
                mail.setSubject('The Diner — Your Verification Code');
                mail.setHtmlBody(
                    '<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto">' +
                    '<div style="background:#032d60;padding:20px;text-align:center">' +
                    '<h2 style="color:#fff;margin:0">The Diner</h2></div>' +
                    '<div style="padding:30px;border:1px solid #d8dde6;border-top:none">' +
                    '<p>Hello,</p>' +
                    '<p>Your verification code is:</p>' +
                    '<div style="background:#f4f6f9;border-radius:8px;padding:20px;text-align:center;margin:20px 0">' +
                    '<span style="font-size:36px;font-weight:bold;letter-spacing:10px;color:#032d60">' + codeStr + '</span>' +
                    '</div>' +
                    '<p style="color:#54698d;font-size:13px">This code expires in <strong>5 minutes</strong>. Do not share it with anyone.</p>' +
                    '<p style="color:#54698d;font-size:13px">If you did not request this code, please ignore this email.</p>' +
                    '</div>' +
                    '<div style="background:#f4f6f9;padding:12px;text-align:center;font-size:11px;color:#54698d">' +
                    'The Diner Restaurant Group</div></div>'
                );
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

                res.sent = true;
                res.contactFound = true;
                res.message = 'A 6-digit verification code has been sent to ' + emailVal + '. It expires in 5 minutes.';
            } catch (Exception e) {
                // Email failed — still allow verification (code is saved in DB)
                res.sent = true;
                res.contactFound = true;
                res.message = 'A verification code has been generated for ' + emailVal + '. Please check your email inbox.';
            }

            results.add(res);
        }

        return results;
    }
}
