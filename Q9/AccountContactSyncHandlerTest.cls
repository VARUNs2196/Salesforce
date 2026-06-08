@isTest
public with sharing class AccountContactSyncHandlerTest {
    @isTest
    public static void testInsertAccounts() {
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 0; i < 250; i++) {
            accountsToInsert.add(new Account(Name = 'Test Account ' + i, Description = 'Description ' + i));
        }
        insert accountsToInsert;
        List<Account> insertedAccounts = [SELECT Id, Name, Rating FROM Account];
        for (Account acc : insertedAccounts) {
            System.assertEquals('Cold', acc.Rating, 'Rating should be set to Cold for all accounts');
        }
    }
    @isTest
    public static void testUpdateContacts() {
        List<Account> accList = new List<Account>();
        for (Integer i = 0; i < 250; i++) {
            accList.add(new Account(Name = 'Test Account ' + i, Description = 'Description ' + i));
        }
        insert accList;
        List<Contact> conList = new List<Contact>();
        for (Account acc : accList) {
            conList.add(new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id, Description = acc.Description));
        }
        insert conList;
        for (Account acc : accList) {
            acc.Description = 'Updated Description';
        }
        update accList;
    }
    @isTest
    public static void testOpportunityCreation() {
        List<Account> accList = new List<Account>();
        for (Integer i = 0; i < 250; i++) {
            accList.add(new Account(Name = 'Test Account ' + i, Description = 'Description ' + i));
        }
        insert accList;
        List<Opportunity> oppList = new List<Opportunity>();
        for (Account acc : accList) {
            oppList.add(new Opportunity(Name = 'Test Opportunity', AccountId = acc.Id, StageName = 'Closed Won', CloseDate = Date.today().addDays(30)));
        }
        insert oppList;
        for (Account acc : accList) {
            acc.Description = 'Has Open Opportunities';
        }
        update accList;
        List<Opportunity> openOpps = [SELECT Id FROM Opportunity WHERE StageName != 'Closed Won'];
        System.assertEquals(250, openOpps.size(), 'Error');
    }
}