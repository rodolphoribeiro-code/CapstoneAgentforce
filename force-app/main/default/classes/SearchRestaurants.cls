public without sharing class SearchRestaurants {

    public class Request {
        @InvocableVariable(label='Query' required=true description='City, cuisine type, restaurant name, or dietary option to search for')
        public String query;
    }

    public class Result {
        @InvocableVariable(label='Found')
        public Boolean found;

        @InvocableVariable(label='Total Results')
        public Integer totalResults;

        @InvocableVariable(label='Results Summary')
        public String resultsSummary;

        @InvocableVariable(label='No Results Message')
        public String noResultsMessage;
    }

    @InvocableMethod(label='Search Restaurants' description='Search restaurants by city, cuisine type, name, or dietary option. Returns a formatted list of matches.')
    public static List<Result> search(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (String.isBlank(req.query)) {
                res.found = false;
                res.noResultsMessage = 'Please provide a search term such as a city, cuisine type, or dietary option.';
                results.add(res);
                continue;
            }

            // Split query into individual keywords and score each restaurant
            List<String> keywords = req.query.trim().toLowerCase().split('\\s+');

            // Build a SOQL condition per keyword (OR across fields, AND across keywords not needed — any match is useful)
            String whereClause = '';
            Map<String, Object> binds = new Map<String, Object>();
            Integer idx = 0;
            for (String kw : keywords) {
                if (String.isBlank(kw)) continue;
                String paramName = 'kw' + idx;
                String likeTerm = '%' + kw + '%';
                binds.put(paramName, likeTerm);
                String condition = '(Name LIKE :' + paramName +
                    ' OR Cuisine_Type__c LIKE :' + paramName +
                    ' OR Location__c LIKE :' + paramName +
                    ' OR Dietary_Options__c LIKE :' + paramName + ')';
                whereClause += (whereClause == '' ? '' : ' OR ') + condition;
                idx++;
            }

            if (whereClause == '') {
                res.found = false;
                res.noResultsMessage = 'Please provide a valid search term.';
                results.add(res);
                continue;
            }

            List<Restaurant__c> restaurants = Database.queryWithBinds(
                'SELECT Name, Cuisine_Type__c, Location__c, Opening_Hours__c, ' +
                'Dietary_Options__c, Phone__c ' +
                'FROM Restaurant__c ' +
                'WHERE ' + whereClause +
                ' ORDER BY Name LIMIT 10',
                binds,
                AccessLevel.SYSTEM_MODE
            );

            if (restaurants.isEmpty()) {
                res.found = false;
                res.totalResults = 0;
                res.noResultsMessage = 'No restaurants found matching "' + req.query + '". '
                    + 'Try searching by city (San Francisco, London, Paris, Sao Paulo), '
                    + 'cuisine (Italian, Japanese, French, Brazilian), or dietary option (Vegan, Gluten-Free).';
                results.add(res);
                continue;
            }

            res.found = true;
            res.totalResults = restaurants.size();

            String summary = 'Found ' + restaurants.size() + ' restaurant' + (restaurants.size() > 1 ? 's' : '') + ' matching "' + req.query + '":\n\n';
            Integer i = 1;
            for (Restaurant__c r : restaurants) {
                summary += i + '. ' + r.Name + '\n';
                summary += '   Cuisine: ' + r.Cuisine_Type__c + '\n';
                summary += '   Address: ' + r.Location__c + '\n';
                summary += '   Hours: ' + r.Opening_Hours__c + '\n';
                if (String.isNotBlank(r.Dietary_Options__c)) {
                    summary += '   Dietary: ' + r.Dietary_Options__c + '\n';
                }
                if (String.isNotBlank(r.Phone__c)) {
                    summary += '   Phone: ' + r.Phone__c + '\n';
                }
                summary += '\n';
                i++;
            }

            res.resultsSummary = summary.trim();
            results.add(res);
        }

        return results;
    }
}
