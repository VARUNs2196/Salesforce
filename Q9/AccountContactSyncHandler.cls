public with sharing class AccountContactSyncHandler {
    
    public static void afterInsert(List<Account> accList) {
        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : accList) {
            if (acc.Rating == null) {
                accountsToUpdate.add(new Account(
                    Id = acc.Id, 
                    Rating = 'Cold'
                ));
            }
        }
        
        if (!accountsToUpdate.isEmpty()) {
            AccountTriggerContext.isFirstRun = false;
            update accountsToUpdate;
            AccountTriggerContext.isFirstRun = true;
        }
    }

    public static void afterUpdate(List<Account> accList, Map<Id, Account> oldMap) {
        Map<Id, String> accIdDesc = new Map<Id, String>();
        Set<Id> accIds = new Set<Id>();

        for (Account acc : accList) {
            if (acc.Description != null && acc.Description != oldMap.get(acc.Id).Description) {
                accIdDesc.put(acc.Id, acc.Description);
                accIds.add(acc.Id);
            }
        }
        if (!accIds.isEmpty()) {
            List<Contact> contacts = [SELECT Id, Description, AccountId FROM Contact WHERE AccountId IN :accIds];
            List<Contact> contactsToUpdate = new List<Contact>();
            for (Contact con : contacts) {
                if (con.Description != accIdDesc.get(con.AccountId)) {
                    con.Description = accIdDesc.get(con.AccountId);
                    contactsToUpdate.add(con);
                }
            }
            if (!contactsToUpdate.isEmpty()) {
                update contactsToUpdate;
            }
        }
        if (!accIds.isEmpty()) {
            Set<Id> accountsWithOpps = new Set<Id>();
            for (AggregateResult agg : [SELECT AccountId FROM Opportunity WHERE AccountId IN :accIds AND StageName != 'Closed Won' GROUP BY AccountId]) {
                accountsWithOpps.add((Id)agg.get('AccountId'));
            }

            List<Opportunity> oppList = new List<Opportunity>();
            List<Account> accountsToClearDesc = new List<Account>();

            for (Account acc : accList) {
                if (accIds.contains(acc.Id)) {
                    if (!accountsWithOpps.contains(acc.Id)) {
                        oppList.add(new Opportunity(
                            AccountId = acc.Id,
                            Name = acc.Name + ' - Auto Opp',
                            StageName = 'Prospecting',
                            CloseDate = Date.today().addDays(30)
                        ));
                    } else if (acc.Description != 'Has Open Opportunities') {
                        accountsToClearDesc.add(new Account(Id = acc.Id, Description = null));
                    }
                }
            }

            if (!oppList.isEmpty()) {
                insert oppList;
            }
            
            if (!accountsToClearDesc.isEmpty()) {
                AccountTriggerContext.isFirstRun = false;
                update accountsToClearDesc;
                AccountTriggerContext.isFirstRun = true;
            }
        }
    }
}