public with sharing class DocuSignRetryController {
    @AuraEnabled
    public static void retryEnvelopeProcessing(Id opportunityId) {
        Envelope_Event__c event = [
            SELECT Id, Retry_Count__c, Status__c 
            FROM Envelope_Event__c 
            WHERE Opportunity__c = :opportunityId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        event.Retry_Count__c = (event.Retry_Count__c == null) ? 1 : event.Retry_Count__c + 1;
        event.Status__c = 'Received';
        update event;
        System.enqueueJob(new DocuSignEnvelopeProcessor(event.Id));
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getSplitDocuments(Id opportunityId) {
        List<ContentVersion> cvList = new List<ContentVersion>();
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :opportunityId
        ];
        if (!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink l : links) {
                docIds.add(l.ContentDocumentId);
            }
            cvList = [
                SELECT Id, Title, ContentDocumentId 
                FROM ContentVersion 
                WHERE ContentDocumentId IN :docIds AND IsLatest = true
            ];
        }
        return cvList;
    }
}