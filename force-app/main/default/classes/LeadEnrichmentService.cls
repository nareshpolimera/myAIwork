/**
 * LeadEnrichmentService
 * -----------------------
 * Invocable Apex action used by the Agentforce "Lead enrichment & scoring" Topic.
 * READ-ONLY: this class never inserts, updates, or deletes any record.
 *
 * Given a Lead Id, it returns:
 *  - core company fields (industry, size, region)
 *  - whether a matching Account already exists (by email/website domain)
 *  - counts of related Contacts and open Opportunities on that Account
 *
 * This gives the agent everything it needs to write a one-paragraph
 * fit summary without guessing at data it doesn't have.
 */
public with sharing class LeadEnrichmentService {

    @InvocableMethod(
        label='Get Lead Context'
        description='Pulls company info and checks for existing Account, Contact, and Opportunity ties for a Lead.'
        category='Sales Agent'
    )
    public static List<Response> getLeadContext(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        EnrichmentContext ctx = new EnrichmentContext();
        ctx.leadMap = queryLeads(requests);
        ctx.domainContext = buildDomainContext(requests, ctx.leadMap);
        ctx.domainToAccount = queryAccountsByDomains(ctx.domainContext.uniqueDomains);
        Set<Id> matchedAccountIds = collectAccountIds(ctx.domainToAccount);
        ctx.contactCounts = countContactsByAccount(matchedAccountIds);
        ctx.oppSummaries = summarizeOpenOpportunities(matchedAccountIds);

        return buildResponses(requests, ctx);
    }

    private static Map<Id, Lead> queryLeads(List<Request> requests) {
        Set<Id> leadIds = new Set<Id>();
        for (Request req : requests) {
            if (req.leadId != null) {
                leadIds.add(req.leadId);
            }
        }
        return new Map<Id, Lead>([
            SELECT Id, Company, Industry, NumberOfEmployees, Email, Website, Country, State
            FROM Lead
            WHERE Id IN :leadIds
            WITH USER_MODE
        ]);
    }

    private static DomainContext buildDomainContext(List<Request> requests, Map<Id, Lead> leadMap) {
        DomainContext ctx = new DomainContext();
        for (Request req : requests) {
            Lead ld = leadMap.get(req.leadId);
            if (ld == null) {
                continue;
            }
            String domain = extractDomain(ld.Email, ld.Website);
            ctx.leadDomainById.put(ld.Id, domain);
            if (String.isNotBlank(domain)) {
                ctx.uniqueDomains.add(domain);
            }
        }
        return ctx;
    }

    private static Map<String, Account> queryAccountsByDomains(Set<String> domains) {
        Map<String, Account> domainToAccount = new Map<String, Account>();
        if (domains == null || domains.isEmpty()) {
            return domainToAccount;
        }

        List<String> likeFilters = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();
        Integer i = 0;
        for (String d : domains) {
            String bindName = 'd' + i;
            likeFilters.add('(Website LIKE :' + bindName + ')');
            binds.put(bindName, '%' + d + '%');
            i++;
        }
        String query =
            'SELECT Id, Name, Website ' +
            'FROM Account ' +
            'WHERE ' + String.join(likeFilters, ' OR ');
        List<Account> accounts = (List<Account>) Database.queryWithBinds(
            query,
            binds,
            AccessLevel.USER_MODE
        );

        for (Account acct : accounts) {
            String acctDomain = extractDomain(null, acct.Website);
            if (String.isBlank(acctDomain)) {
                continue;
            }
            for (String d : domains) {
                if (acctDomain.contains(d) && !domainToAccount.containsKey(d)) {
                    domainToAccount.put(d, acct);
                }
            }
        }
        return domainToAccount;
    }

    private static Set<Id> collectAccountIds(Map<String, Account> domainToAccount) {
        Set<Id> accountIds = new Set<Id>();
        for (Account acct : domainToAccount.values()) {
            accountIds.add(acct.Id);
        }
        return accountIds;
    }

    private static Map<Id, Integer> countContactsByAccount(Set<Id> accountIds) {
        Map<Id, Integer> counts = new Map<Id, Integer>();
        if (accountIds == null || accountIds.isEmpty()) {
            return counts;
        }
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) cnt
            FROM Contact
            WHERE AccountId IN :accountIds
            WITH USER_MODE
            GROUP BY AccountId
        ]) {
            counts.put((Id) ar.get('AccountId'), (Integer) ar.get('cnt'));
        }
        return counts;
    }

    private static Map<Id, OppSummary> summarizeOpenOpportunities(Set<Id> accountIds) {
        Map<Id, OppSummary> summaries = new Map<Id, OppSummary>();
        if (accountIds == null || accountIds.isEmpty()) {
            return summaries;
        }
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) cnt, StageName
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            WITH USER_MODE
            GROUP BY AccountId, StageName
        ]) {
            Id acctId = (Id) ar.get('AccountId');
            if (!summaries.containsKey(acctId)) {
                OppSummary summary = new OppSummary();
                summary.count = (Integer) ar.get('cnt');
                summary.stage = (String) ar.get('StageName');
                summaries.put(acctId, summary);
            }
        }
        return summaries;
    }

    private static List<Response> buildResponses(List<Request> requests, EnrichmentContext ctx) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(buildSingleResponse(req, ctx));
        }
        return responses;
    }

    private static Response buildSingleResponse(Request req, EnrichmentContext ctx) {
        Response resp = new Response();
        Lead ld = ctx.leadMap.get(req.leadId);
        if (ld == null) {
            return resp;
        }

        resp.company = ld.Company;
        resp.industry = ld.Industry;
        // resp.numberOfEmployees = ld.NumberOfEmployees;
        resp.country = ld.Country;
        resp.state = ld.State;

        String domain = ctx.domainContext.leadDomainById.get(ld.Id);
        resp.domain = domain;

        Account matchedAccount = ctx.domainToAccount.get(domain);
        if (matchedAccount != null) {
            resp.hasExistingAccount = true;
            resp.existingAccountName = matchedAccount.Name;

            //resp.relatedContactCount = ctx.contactCounts.containsKey(matchedAccount.Id) ? ctx.contactCounts.get(matchedAccount.Id)
              //  : 0;

            OppSummary summary = ctx.oppSummaries.get(matchedAccount.Id);
            if (summary != null) {
                //resp.openOpportunityCount = summary.count;
                resp.openOpportunityStage = summary.stage;
            } else {
                //resp.openOpportunityCount = 0;
            }
        } else {
            resp.hasExistingAccount = false;
            // resp.relatedContactCount = 0;
            // resp.openOpportunityCount = 0;
        }
        return resp;
    }

    private class DomainContext {
        Map<Id, String> leadDomainById = new Map<Id, String>();
        Set<String> uniqueDomains = new Set<String>();
    }

    private class OppSummary {
        Integer count = 0;
        String stage;
    }

    private class EnrichmentContext {
        Map<Id, Lead> leadMap;
        DomainContext domainContext;
        Map<String, Account> domainToAccount;
        Map<Id, Integer> contactCounts;
        Map<Id, OppSummary> oppSummaries;
    }

    private static String extractDomain(String email, String website) {
        String source = String.isNotBlank(website) ? website : email;
        if (String.isBlank(source)) {
            return null;
        }
        String domain = source.toLowerCase();
        domain = domain.replace('https://', '').replace('http://', '').replace('www.', '');
        if (domain.contains('@')) {
            domain = domain.substringAfter('@');
        }
        if (domain.contains('/')) {
            domain = domain.substringBefore('/');
        }
        return domain;
    }

    public class Request {
        @InvocableVariable(label='Lead Id' required=true)
        public Id leadId;
    }

    public class Response {
        @InvocableVariable(label='Company Name')
        public String company;

        @InvocableVariable(label='Industry')
        public String industry;

        @InvocableVariable(label='Number Of Employees')
        public Decimal numberOfEmployees;

        @InvocableVariable(label='Country')
        public String country;

        @InvocableVariable(label='State')
        public String state;

        @InvocableVariable(label='Email/Website Domain')
        public String domain;

        @InvocableVariable(label='Has Existing Account')
        public Boolean hasExistingAccount;

        @InvocableVariable(label='Existing Account Name')
        public String existingAccountName;

        // @InvocableVariable(label='Related Contact Count')
        // public Decimal relatedContactCount;

        // @InvocableVariable(label='Open Opportunity Count')
        // public Decimal openOpportunityCount;

        @InvocableVariable(label='Open Opportunity Stage')
        public String openOpportunityStage;
    }
}