public with sharing class FscDashboardController {

    public class SummaryDTO {
        @AuraEnabled public Integer householdCount;
        @AuraEnabled public Integer accountCount;
        @AuraEnabled public Decimal totalAum; // sum of balances if FSC
        @AuraEnabled public String mode;      // "FSC" or "CORE"
    }

    public class RecentItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public Date lastActivity;
        @AuraEnabled public Decimal balance;
    }

    // Detect if FSC managed objects exist
    private static Boolean hasFsc() {
        return Schema.getGlobalDescribe().containsKey('FinServ__FinancialAccount__c');
    }

    @AuraEnabled(cacheable=true)
    public static SummaryDTO getSummary() {
        SummaryDTO s = new SummaryDTO();
        if (hasFsc()) {
            // Households in FSC are Accounts with a record type or Type = 'Household' depending on org setup.
            // Use a safe filter on Type when present.
            Integer hh = (Integer)Database.countQuery('SELECT COUNT() FROM Account WHERE Type = \'Household\'');
            Integer fa = (Integer)Database.countQuery('SELECT COUNT() FROM FinServ__FinancialAccount__c');
            // Balance field often is FinServ__Balance__c (Number(16,2))
            Decimal aum = 0;
            for (AggregateResult ar : [
                SELECT SUM(FinServ__Balance__c) total
                FROM FinServ__FinancialAccount__c
            ]) {
                aum = (Decimal)ar.get('total');
            }
            s.householdCount = hh;
            s.accountCount = fa;
            s.totalAum = aum != null ? aum : 0;
            s.mode = 'FSC';
        } else {
            // CORE fallback: treat Accounts as "households" and Opportunities as "accounts"
            Integer hh = (Integer)Database.countQuery('SELECT COUNT() FROM Account');
            Integer opp = (Integer)Database.countQuery('SELECT COUNT() FROM Opportunity');
            Decimal amountSum = 0;
            for (AggregateResult ar : [SELECT SUM(Amount) total FROM Opportunity WHERE IsClosed = false]) {
                amountSum = (Decimal)ar.get('total');
            }
            s.householdCount = hh;
            s.accountCount = opp;
            s.totalAum = amountSum != null ? amountSum : 0;
            s.mode = 'CORE';
        }
        return s;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecentItemDTO> getRecent(int limitSize) {
        List<RecentItemDTO> outList = new List<RecentItemDTO>();
        if (hasFsc()) {
            // Latest financial accounts first
            for (FinServ__FinancialAccount__c fa : [
                SELECT Id, Name, FinServ__FinancialAccountType__c, LastActivityDate, FinServ__Balance__c
                FROM FinServ__FinancialAccount__c
                ORDER BY LastActivityDate DESC NULLS LAST
                LIMIT :limitSize
            ]) {
                RecentItemDTO r = new RecentItemDTO();
                r.id = fa.Id;
                r.name = fa.Name;
                r.type = String.valueOf(fa.FinServ__FinancialAccountType__c);
                r.lastActivity = fa.LastActivityDate;
                r.balance = fa.FinServ__Balance__c;
                outList.add(r);
            }
        } else {
            // Fallback: recent open opportunities as "accounts"
            for (Opportunity o : [
                SELECT Id, Name, StageName, LastActivityDate, Amount
                FROM Opportunity
                ORDER BY LastActivityDate DESC NULLS LAST
                LIMIT :limitSize
            ]) {
                RecentItemDTO r = new RecentItemDTO();
                r.id = o.Id;
                r.name = o.Name;
                r.type = o.StageName;
                r.lastActivity = o.LastActivityDate;
                r.balance = o.Amount;
                outList.add(r);
            }
        }
        return outList;
    }
}

