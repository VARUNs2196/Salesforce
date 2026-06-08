public with sharing class ERPSyncScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        List<Id> accIds = new List<Id>();
        for (Account accObj : [SELECT Id FROM Account WHERE Sync_Status__c = 'Pending' ORDER BY CreatedDate]) {
            accIds.add(accObj.Id);
        }
        if (!accIds.isEmpty()) {
            System.enqueueJob(new ERPSyncQueueable(accIds));
        }
    }
}