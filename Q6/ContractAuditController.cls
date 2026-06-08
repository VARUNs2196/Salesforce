public with sharing class ContractAuditController {
    @AuraEnabled(cacheable=true)
    public static List<Contract_Audit__b> getAuditHistory(Id contractId) {
        System.debug('Fetching audit history for Contract ID: ' + contractId);
        return [SELECT Sensitive__c,Contract_Id__c, Field_Name__c, Old_Value__c, New_Value__c, Changed_By__c, Change_Time__c FROM Contract_Audit__b 
                WHERE Contract_Id__c = :contractId ];
    }
}