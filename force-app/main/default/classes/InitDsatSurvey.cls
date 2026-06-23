public class InitDsatSurvey {
    @InvocableMethod(label='Init DSAT Survey' description='Marks the DSAT survey as started')
    public static List<Response> execute(List<Request> requests) {
        Response r = new Response();
        r.started = true;
        return new List<Response>{ r };
    }

    public class Request {
        @InvocableVariable(label='Dummy' required=false)
        public String dummy;
    }

    public class Response {
        @InvocableVariable(label='Started')
        public Boolean started;
    }
}
