// BAD EXAMPLE CLASS - intentionally violates SALESFORCE_CODE_REVIEW_GUIDELINES.md
// Use this as a fixture to test/demo the code review checklist. DO NOT deploy to production.
public with sharing class CodeReviewService {

    // No sharing declaration specified at all -> defaults are implicit/unclear (violates: explicit sharing)

    // Hardcoded org-specific ID (violates: no hardcoded IDs)
    public static Id DEFAULT_RECORD_TYPE_ID = '012000000000AAA';

    // Magic string used directly instead of a constant/custom label (violates: no magic numbers/strings)
    public static void processAccounts(List<Id> accountIds) {

        for (Id accId : accountIds) {

            // SOQL inside a loop (violates: bulkification / governor limits)
            Account acc = [SELECT Id, Name, Industry, AnnualRevenue FROM Account WHERE Id = :accId];

            // No CRUD/FLS check before reading/updating fields (violates: security)
            if (acc.Industry == 'Banking') {
                acc.AnnualRevenue = acc.AnnualRevenue * 1.1;
            }

            // DML inside a loop (violates: bulkification / governor limits)
            update acc;

            // Callout inside a loop (violates: no callouts in loops)
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.example.com/notify?accountId=' + accId); // SOQL/URL injection-style pattern
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse res = http.send(req); // no try/catch, no timeout handling
        }
    }

    // Dynamic SOQL built via string concatenation -> SOQL injection risk (violates: security)
    public static List<Account> searchAccounts(String userInput) {
        String query = 'SELECT Id, Name FROM Account WHERE Name LIKE \'%' + userInput + '%\'';
        return Database.query(query);
    }

    // Swallows exceptions silently, logs sensitive data (violates: error handling + security)
    public static void riskyUpdate(Account acc) {
        try {
            acc.Description = 'SSN:123-45-6789 processed'; // sensitive data hardcoded/logged
            System.debug('Updating account with sensitive payload: ' + acc);
            update acc;
        } catch (Exception e) {
            // swallowed - no logging, no rethrow, no custom exception (violates: error handling)
        }
    }

    // Unbulkified helper called per-record from a trigger context (violates: bulkification)
    public static void afterInsertLogic(List<Account> newAccounts) {
        for (Account a : newAccounts) {
            insertAuditRecord(a); // DML fired once per record instead of bulk insert
        }
    }

    private static void insertAuditRecord(Account a) {
        Account_Audit__c audit = new Account_Audit__c();
        audit.Account__c = a.Id;
        audit.Note__c = 'Processed';
        insert audit; // DML in a loop via helper method
    }

    // Dead code left commented out (violates: no commented-out dead code)
    // public static void oldProcessAccounts(List<Id> ids) {
    //     for (Id i : ids) {
    //         Account a = [SELECT Id FROM Account WHERE Id = :i];
    //         update a;
    //     }
    // }

    // No test coverage exists for this class at all (violates: testing requirements)
}