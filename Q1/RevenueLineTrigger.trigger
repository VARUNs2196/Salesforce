trigger RevenueLineTrigger on Revenue_Line__c (after insert, after update, after delete,after undelete) {
    if (RevenueLineTriggerHandler.isFirstRun) {
        if (Trigger.isAfter) {
            if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
                RevenueLineTriggerHandler.handleRevenueLine(Trigger.new);
            }
            if (Trigger.isDelete) {
                RevenueLineTriggerHandler.handleRevenueLine(Trigger.old);
            }
        }
    }
}