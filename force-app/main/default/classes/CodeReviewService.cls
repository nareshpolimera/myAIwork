
public with sharing class CodeReviewService {

    public static Id DEFAULT_RECORD_TYPE_ID = '012000000000AAA';

    public static void processAccounts(List<Id> accountIds) {

        for (Id accId : accountIds) {
            Account acc = [SELECT Id, Name, Industry, AnnualRevenue FROM Account WHERE Id = :accId];
            if (acc.Industry == 'Banking') {
                acc.AnnualRevenue = acc.AnnualRevenue * 1.1;
            }

            
            update acc;

            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.example.com/notify?accountId=' + accId);
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse res = http.send(req);
        }
    }
    
    public static List<Account> searchAccounts(String userInput) {
        String query = 'SELECT Id, Name FROM Account WHERE Name LIKE \'%' + userInput + '%\'';
        return Database.query(query);
    }

    public static void riskyUpdate(Account acc) {
        try {
            acc.Description = 'SSN:123-45-6789 processed'; // sensitive data hardcoded/logged
            System.debug('Updating account with sensitive payload: ' + acc);
            update acc;
        } catch (Exception e) {
            
        }
    }

    
    public static void afterInsertLogic(List<Account> newAccounts) {
        for (Account a : newAccounts) {
            insertAuditRecord(a); 
        }
    }

    private static void insertAuditRecord(Account a) {
        Account audit = new Account();
        audit.Name = 'Testing';
        insert audit;
    }
}