@isTest
public with sharing class RevenueLineTriggerHandlerTest {
    @isTest
    static void testRevenueLineTrigger() {
        List<Revenue_Line__c> revenueLines = new List<Revenue_Line__c>();
        Opportunity oppt = new Opportunity(Name = 'Test Opportunity', CloseDate = Date.today().addDays(30), StageName = 'Prospecting');
        insert oppt;
        Id oppId = oppt.Id;
        for (Integer i = 0; i < 200; i++) {
            revenueLines.add(new Revenue_Line__c(
                Name = 'Test Revenue Line ' + i,
                Amount__c = 100,
                Stage__c = 'Active',
                Month__c = Date.today().addMonths(i),
                Opportunity__c = oppId
            ));
        }
        insert revenueLines;
        Opportunity opp = [SELECT Total_Revenue__c, Cancelled_Revenue__c, Projected_Close_Month__c FROM Opportunity WHERE Id = :oppId];
        System.assertEquals(20000, opp.Total_Revenue__c);
        System.assertEquals(0, opp.Cancelled_Revenue__c);
        System.assertEquals(Date.today().addMonths(199), opp.Projected_Close_Month__c);
        for (Revenue_Line__c rl : revenueLines) {
            rl.Stage__c = 'Cancelled';
        }
        update revenueLines;
        opp = [SELECT Total_Revenue__c, Cancelled_Revenue__c FROM Opportunity WHERE Id = :oppId];
        System.assertEquals(0, opp.Total_Revenue__c);
        System.assertEquals(20000, opp.Cancelled_Revenue__c);
        delete revenueLines;
        opp = [SELECT Total_Revenue__c, Cancelled_Revenue__c FROM Opportunity WHERE Id = :oppId];
        System.assertEquals(0, opp.Total_Revenue__c);
        System.assertEquals(0, opp.Cancelled_Revenue__c);
        undelete revenueLines;
        opp = [SELECT Total_Revenue__c, Cancelled_Revenue__c FROM Opportunity WHERE Id = :oppId];
        System.assertEquals(0, opp.Total_Revenue__c);
        System.assertEquals(20000, opp.Cancelled_Revenue__c);
    }
}