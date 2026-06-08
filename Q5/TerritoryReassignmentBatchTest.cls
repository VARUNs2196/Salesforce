@isTest
public with sharing class TerritoryReassignmentBatchTest {
    @TestSetup
    static void setupTestData() {

        Sales_Territory__c st1 = new Sales_Territory__c(Name = 'North');
        Sales_Territory__c st2 = new Sales_Territory__c(Name = 'South');
        insert st1;
        insert st2;
        List<Territory_Rule__c> rules = new List<Territory_Rule__c>();
        rules.add(new Territory_Rule__c(Postcode_Prefix__c = 'Nh1', Sales_Territory__c = st1.Id));
        rules.add(new Territory_Rule__c(Postcode_Prefix__c = 'Sh1', Sales_Territory__c = st2.Id));
        insert rules;
        Contact con1 = new Contact(LastName = 'test', Postcode__c = 'Nh110002', Sales_Territory__c = st1.Id);
        insert con1;

    }
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        Sales_Territory__c st = [SELECT Id FROM Sales_Territory__c WHERE Name = 'South' LIMIT 1];
        Contact conObj = [SELECT Id, Sales_Territory__c,Postcode__c FROM Contact WHERE Postcode__c = 'Nh110002' Limit 1];
        conObj.Postcode__c='Sh110002';
        update conObj;
        TerritoryReassignmentBatch batch = new TerritoryReassignmentBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();
            conObj = [SELECT Id, Sales_Territory__c FROM Contact WHERE Id = :conObj.Id];
        System.assertEquals(st.Id, conObj.Sales_Territory__c, 'Contact should be reassigned to South territory');
        
    }
        

}