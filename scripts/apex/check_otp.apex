// Check recent OTP records and email deliverability
List<OtpVerification__c> otps = [
    SELECT Name, Email__c, Code__c, ExpiresAt__c, Is_Used__c, CreatedDate
    FROM OtpVerification__c
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('Total OTP records: ' + otps.size());
for (OtpVerification__c o : otps) {
    System.debug(o.Name + ' | ' + o.Email__c + ' | Code: ' + o.Code__c + ' | Expires: ' + o.ExpiresAt__c + ' | Used: ' + o.Is_Used__c);
}

// Check email logs
List<EmailMessage> emails = [
    SELECT Id, Subject, ToAddress, MessageDate, Status
    FROM EmailMessage
    WHERE Subject LIKE '%Verification%'
    ORDER BY MessageDate DESC
    LIMIT 5
];
System.debug('Email messages found: ' + emails.size());
for (EmailMessage e : emails) {
    System.debug(e.Subject + ' | To: ' + e.ToAddress + ' | Status: ' + e.Status + ' | Date: ' + e.MessageDate);
}
