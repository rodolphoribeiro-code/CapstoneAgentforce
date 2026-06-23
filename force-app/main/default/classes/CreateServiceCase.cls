public class CreateServiceCase {
    public class Request {
        @InvocableVariable(label='Contact Id' description='Salesforce Contact Id (optional)')
        public String contactId;

        @InvocableVariable(label='Reason' description='Reason for escalation' required=true)
        public String reason;

        @InvocableVariable(label='Description' description='Summary of the customer issue' required=true)
        public String description;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True if the case was created successfully')
        public Boolean success;

        @InvocableVariable(label='Case Number' description='The generated Salesforce case number')
        public String caseNumber;

        @InvocableVariable(label='Error Message' description='Error details if case creation failed')
        public String errorMessage;
    }

    @InvocableMethod(label='Create Service Case' description='Creates a Salesforce Case to document an escalation from Agentforce')
    public static List<Result> createCase(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();
            try {
                Case c = new Case();
                c.Origin = 'Agentforce';
                c.Status = 'New';
                c.Reason = String.isNotBlank(req.reason) ? req.reason : 'Escalation';
                c.Description = req.description;

                if (String.isNotBlank(req.contactId)) {
                    c.ContactId = req.contactId;
                }

                Database.insert(c, AccessLevel.SYSTEM_MODE);

                // Re-query to get the auto-generated CaseNumber
                Map<String, Object> binds = new Map<String, Object>{ 'caseId' => c.Id };
                List<Case> inserted = Database.queryWithBinds(
                    'SELECT CaseNumber FROM Case WHERE Id = :caseId LIMIT 1',
                    binds,
                    AccessLevel.SYSTEM_MODE
                );

                res.success = true;
                res.caseNumber = inserted.isEmpty() ? '' : inserted[0].CaseNumber;
            } catch (Exception e) {
                res.success = false;
                res.errorMessage = 'Unable to create case: ' + e.getMessage();
            }
            results.add(res);
        }

        return results;
    }
}
