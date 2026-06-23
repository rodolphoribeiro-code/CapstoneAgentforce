public class LogAgentInteraction {
    public class Request {
        @InvocableVariable(label='Contact Id' description='Salesforce Contact Id of the customer (optional)')
        public String contactId;

        @InvocableVariable(label='Booking Number' description='Booking number from this session e.g. BKG-0001 (optional)')
        public String bookingNumber;

        @InvocableVariable(label='DSAT Score' description='Customer satisfaction rating 1 to 5' required=true)
        public String dsatScore;

        @InvocableVariable(label='Interaction Type' description='BOOKING_CREATED, BOOKING_MODIFIED, BOOKING_CANCELLED, FAQ, ESCALATION, or GENERAL' required=true)
        public String interactionType;

        @InvocableVariable(label='Notes' description='Optional session notes')
        public String notes;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True if the interaction was logged successfully')
        public Boolean success;

        @InvocableVariable(label='Interaction Id' description='Id of the created Agent_Interaction__c record')
        public String interactionId;

        @InvocableVariable(label='Message' description='Confirmation or error message')
        public String message;
    }

    @InvocableMethod(label='Log Agent Interaction' description='Creates an Agent_Interaction__c record with DSAT rating and session details')
    public static List<Result> logInteraction(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();
            try {
                Agent_Interaction__c interaction = new Agent_Interaction__c();

                if (String.isNotBlank(req.contactId)) {
                    interaction.Contact__c = req.contactId;
                }

                if (String.isNotBlank(req.bookingNumber)) {
                    String bookingNum = req.bookingNumber.toUpperCase().trim();
                    Map<String, Object> binds = new Map<String, Object>{ 'bookingNum' => bookingNum };
                    List<Booking__c> bookings = Database.queryWithBinds(
                        'SELECT Id FROM Booking__c WHERE Name = :bookingNum LIMIT 1',
                        binds,
                        AccessLevel.SYSTEM_MODE
                    );
                    if (!bookings.isEmpty()) {
                        interaction.Booking__c = bookings[0].Id;
                    }
                }

                if (String.isNotBlank(req.dsatScore)) {
                    try {
                        interaction.DSAT_Score__c = Integer.valueOf(req.dsatScore.trim());
                    } catch (Exception e) {
                        // Non-numeric rating — skip the score field
                    }
                }

                interaction.Interaction_Type__c = String.isNotBlank(req.interactionType) ? req.interactionType : 'GENERAL';
                interaction.Notes__c = req.notes;

                Database.insert(interaction, AccessLevel.SYSTEM_MODE);

                res.success = true;
                res.interactionId = interaction.Id;
                res.message = 'Thank you for your feedback!';
            } catch (Exception e) {
                res.success = false;
                res.message = 'Unable to log interaction: ' + e.getMessage();
            }
            results.add(res);
        }

        return results;
    }
}
