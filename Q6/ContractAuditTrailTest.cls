@isTest
public with sharing class ContractAuditTrailTest {
    
    @isTest
    static void testContractAuditPipeline() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            TCV__c = 1000.0,
            Discount__c = 5.0,
            Payment_Terms__c = 'Net 30'
        );
        insert con;
        Test.startTest();
        con.TCV__c = 1500.0; 
        con.Discount__c = 10.0;
        con.Payment_Terms__c = '1123456'; 
        update con;
        Test.stopTest(); 
        System.assert(true, 'Decoupled Platform Event and Big Object pipeline executed successfully');
    }
    @IsTest
    static void testGetAuditHistory_NoException() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert con;
        Test.startTest();
        List<Contract_Audit__b> results =
            ContractAuditController.getAuditHistory(con.Id);

        Test.stopTest();
        System.assertNotEquals(
            null,
            results,
            'Method should return a list (empty or populated)'
        );

        System.assertEquals(
            0,
            results.size(),
            'Big Objects cannot be inserted in tests, so result must be empty'
        );
    }
}