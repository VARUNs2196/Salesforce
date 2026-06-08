trigger ContractChangeEventTrigger on Contract_Change_Event__e (after insert) {
    List<Contract_Audit__b> auditsToInsert = new List<Contract_Audit__b>();
    for (Contract_Change_Event__e eventObj : Trigger.new) {
        auditsToInsert.add(new Contract_Audit__b(
            Contract_Id__c = eventObj.Contract_Id__c,
            Field_Name__c = eventObj.Field_Name__c,
            Old_Value__c = eventObj.Old_Value__c,
            New_Value__c = eventObj.New_Value__c,
            Changed_By__c = eventObj.Changed_By__c,
            Change_Time__c = eventObj.Change_Time__c,
            Sensitive__c = String.valueOf(eventObj.Sensitive__c)
        ));
    }
    if (!auditsToInsert.isEmpty()) {
        Database.insertImmediate(auditsToInsert);
    }
}