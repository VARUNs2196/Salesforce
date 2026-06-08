trigger ContractTrigger on Contract (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        ContractTriggerHandler.handleContract(Trigger.new, Trigger.oldMap);
    }

}