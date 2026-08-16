public with sharing class CaseIdLookupInvocable {
    public class Request {
        @InvocableVariable(required=true label='Case Number')
        public String caseNumber;
    }
    
    public class Response {
        @InvocableVariable(label='Case Id' description='The Salesforce Id of the Case that matches the supplied Case Number.')
        public Case caseRecord;
        
        @InvocableVariable(label='Found' description='The Salesforce found of supplied Case Number.')
        public Boolean found;

        @InvocableVariable(label='Message' description='Message')
        public String message;
    }
    
    @InvocableMethod(label='Get Case Id by Case Number' description='Retrieves a Case Id from a Case Number.')
    public static List<Response> getCaseIds(List<Request> requests) {
        Set<String> caseNumbers = new Set<String>();
        for (Request request : requests) {
            if (request != null && String.isNotBlank(request.caseNumber)) {
                caseNumbers.add(request.caseNumber.trim());
            }
        }
        
        Map<String, Case> caseByNumber = new Map<String, Case>();
        
        if (!caseNumbers.isEmpty()) {
            for (Case caseRecord : [
                SELECT Id, CaseNumber
                FROM Case
                WHERE CaseNumber IN :caseNumbers
                WITH USER_MODE
            ]) {
                caseByNumber.put(caseRecord.CaseNumber, caseRecord);
            }
        }
        
        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            Response response = new Response();
            if (request != null && String.isNotBlank(request.caseNumber)) {
                response.caseRecord = caseByNumber.get(request.caseNumber.trim());
                response.found = true;
                response.message = 'Case found.';
            }
            responses.add(response);
        }
        return responses;
    }
}