public with sharing class TerritoryReassignmentBatch implements Database.Batchable<SObject> , Database.Stateful {
    public Map<String, Id> trList=new Map<String, Id>();
    Integer totalProcessed = 0;
    Integer totalChanged = 0;

    public Database.QueryLocator start(Database.BatchableContext BC) {
        for (Territory_Rule__c rule : [SELECT Id, Postcode_Prefix__c, Sales_Territory__c FROM Territory_Rule__c]) {
            trList.put(rule.Postcode_Prefix__c, rule.Sales_Territory__c);
        }
        return Database.getQueryLocator('SELECT Id, Postcode__c, Sales_Territory__c FROM Contact');
    }
    public void execute(Database.BatchableContext BC, List<Contact> conList) {
         List<Contact> contactsToUpdate = new List<Contact>();
         for (Contact conObj : conList) {
            Id bestMatchTerritoryId = null; 
            if (String.isBlank(conObj.Postcode__c) || conObj.Postcode__c.length() < 3) {
                continue;
            }

             if(trList.containsKey(conObj.Postcode__c.substring(0, 3))) {
                 bestMatchTerritoryId = trList.get(conObj.Postcode__c.substring(0, 3));
             }
            if (bestMatchTerritoryId != null && conObj.Sales_Territory__c != bestMatchTerritoryId) {
                conObj.Sales_Territory__c = bestMatchTerritoryId;
                contactsToUpdate.add(conObj);
                totalChanged++;
                
            }
            totalProcessed++;
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }
    public void finish(Database.BatchableContext BC) {
        Batch_Summary__c bsObj = new Batch_Summary__c();
        bsObj.Total_Processed__c = totalProcessed;
        bsObj.Total_Changed__c = totalChanged;
        bsObj.Details__c = 'Batch job completed.';
        bsObj.Run_Date__c = System.now();
        insert bsObj;
        // Schedule the next run after 90 days
        Datetime targetDate = Datetime.now().addDays(90);
        String cronExpression = targetDate.format('0 m H d M ? yyyy');
        System.schedule('Territory Reassignment Batch - ' + targetDate.format('yyyy-MM-dd'), cronExpression, new TerritoryReassignmentBatchScheduleable());
    }
    public with sharing class TerritoryReassignmentBatchScheduleable implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TerritoryReassignmentBatch(), 200);
    }
}
}