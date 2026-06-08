public with sharing class ERPSyncQueueable implements Queueable, Database.AllowsCallouts {
    @TestVisible
    private static ERP_Config__mdt config = ERP_Config__mdt.getInstance('Headers');
    private List<Id> currentBatchIds;
    private List<Id> remainingIds;

    public ERPSyncQueueable(List<Id> accountIds) {
        this.currentBatchIds = new List<Id>();
        this.remainingIds = new List<Id>(accountIds);
        Integer endIndex = Math.min(10, remainingIds.size());
        for (Integer i = 0; i < endIndex; i++) {
            this.currentBatchIds.add(this.remainingIds.remove(0));
        }
    }

    public ERPSyncQueueable(List<Id> currentBatchIds, List<Id> remainingIds) {
        this.currentBatchIds = currentBatchIds;
        this.remainingIds = remainingIds;
    }

    public void execute(QueueableContext context) {
        if (currentBatchIds.isEmpty()) return;

        Integer maxRetries = Integer.valueOf(config.Max_Retries__c);

        List<Account> accounts = [
            SELECT Id, Sync_Status__c, Sync_Retry_Count__c, Last_Sync_Time__c
            FROM Account
            WHERE Id IN :currentBatchIds
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Endpoint_URL__c);
        req.setMethod('POST');
        req.setTimeout(Integer.valueOf(config.Timeout_ms__c));
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(accounts));

        Http http = new Http();
        HttpResponse res;
        String responseBody;
        try {
            res = http.send(req);
            responseBody = res.getBody();
        } catch (Exception ex) {
            responseBody = ex.getMessage();
        }

        List<Error_Log__c> errorLogs = new List<Error_Log__c>();
        List<Id> retryIds = new List<Id>();

        for (Account acc : accounts) {
            if (res != null && res.getStatusCode() == 200) {
                acc.Sync_Status__c = 'Synced';
                acc.Last_Sync_Time__c = System.now();
            } else {
                acc.Sync_Retry_Count__c = acc.Sync_Retry_Count__c == null ? 1 : acc.Sync_Retry_Count__c + 1;
                if (acc.Sync_Retry_Count__c >= maxRetries) {
                    acc.Sync_Status__c = 'Failed';
                    errorLogs.add(new Error_Log__c(
                        Account__c = acc.Id,
                        Response_Body__c = responseBody,
                        Error_Time__c = System.now()
                    ));
                    EventBus.publish(new Account_Error__e(
                        AccountId__c = acc.Id,
                        Error_Message__c = responseBody
                    ));
                } else {
                    retryIds.add(acc.Id);
                }
            }
        }

        update accounts;
        if (!errorLogs.isEmpty()) insert errorLogs;

        if (!retryIds.isEmpty()) {
            if (!Test.isRunningTest()) {
                enforceRateLimit();
                System.enqueueJob(new ERPSyncQueueable(retryIds, remainingIds));
            }
        } else if (!remainingIds.isEmpty()) {
            List<Id> nextBatch = new List<Id>();
            Integer endIndex = Math.min(10, remainingIds.size());
            for (Integer i = 0; i < endIndex; i++) {
                nextBatch.add(remainingIds.remove(0));
            }
            if (!Test.isRunningTest()) {
                enforceRateLimit();
                System.enqueueJob(new ERPSyncQueueable(nextBatch, remainingIds));
            }
        }
    }

    private static void enforceRateLimit() {
        Long startTime = DateTime.now().getTime();
        while (DateTime.now().getTime() - startTime < 5000) {
        }
    }
}