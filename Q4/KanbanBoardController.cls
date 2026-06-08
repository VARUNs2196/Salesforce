public with sharing class KanbanBoardController {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Case>> getCasesByStatus() {
        Map<String, List<Case>> casesByStatus = new Map<String, List<Case>>();
        for (Case csObj : [SELECT Id, Subject, Status,CaseNumber FROM Case]) {
            if (!casesByStatus.containsKey(csObj.Status)) {
                casesByStatus.put(csObj.Status, new List<Case>());
            }
            casesByStatus.get(csObj.Status).add(csObj);
        }
        return casesByStatus;
    }
    @AuraEnabled(cacheable=false)
    public static void updateCaseStatus(Id caseId, String newStatus, String oldStatus) {
        List<Case_Status_Transition__mdt> validTransitions = [SELECT From_Status__c, To_Status__c FROM Case_Status_Transition__mdt WHERE From_Status__c = :oldStatus AND To_Status__c = :newStatus AND Allowed__c = true];
        System.debug('Valid transitions from ' + oldStatus + ' to ' + newStatus + ': ' + validTransitions);
        if (validTransitions.isEmpty()) {
            System.debug('No valid transitions found for new status: ' + newStatus);
            throw new AuraHandledException('Invalid status transition from ' + oldStatus + ' to ' + newStatus);
        }
        
        Case caseToUpdate = [SELECT Id, Status FROM Case WHERE Id = :caseId LIMIT 1];
        caseToUpdate.Status = newStatus;
        update caseToUpdate;
    }
}