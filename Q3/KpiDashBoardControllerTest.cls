@isTest
private class KpiDashBoardControllerTest {
  @testSetup
  static void setupTestData() {
    List<Opportunity> oppList = new List<Opportunity>();
    oppList.add(
      new Opportunity(
        Name = 'Opp West Open',
        Amount = 100000,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        Region__c = 'West'
      )
    );
    oppList.add(
      new Opportunity(
        Name = 'Opp West Won',
        Amount = 50000,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-5),
        Region__c = 'West'
      )
    );
    oppList.add(
      new Opportunity(
        Name = 'Opp None Won',
        Amount = 120000,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-10)
      )
    );

    insert oppList;
  }

  @isTest
  static void testGetKpiSummary() {
    Test.startTest();
    Map<String, String> summaryWest = KpiDashBoardController.getKpiSummary(
      'West'
    );
    Map<String, String> summaryNone = KpiDashBoardController.getKpiSummary(
      'None'
    );
    Test.stopTest();

    System.assertNotEquals(null, summaryWest);
    System.assertEquals('100000.0', summaryWest.get('openPipeline'));
    System.assertEquals('50000.0', summaryWest.get('wonRevenue'));
    System.assertEquals('50000.0', summaryWest.get('avgDealSize'));
    System.assertEquals('50.0%', summaryWest.get('winRate'));

    System.assertNotEquals(null, summaryNone);
    System.assertEquals('0', summaryNone.get('openPipeline'));
    System.assertEquals('0', summaryNone.get('wonRevenue'));
    System.assertEquals('0', summaryNone.get('avgDealSize'));
    System.assertEquals('0%', summaryNone.get('winRate'));
  }

  @isTest
  static void testGetTopOpportunities() {
    Test.startTest();
    List<Opportunity> openOpps = KpiDashBoardController.getTopOpportunities(
      'openPipeline',
      'West'
    );
    List<Opportunity> wonOpps = KpiDashBoardController.getTopOpportunities(
      'wonRevenue',
      'West'
    );
    List<Opportunity> avgOpps = KpiDashBoardController.getTopOpportunities(
      'avgDealSize',
      'None'
    );
    List<Opportunity> winRateOpps = KpiDashBoardController.getTopOpportunities(
      'winRate',
      'West'
    );
    Test.stopTest();

    System.assertEquals(1, openOpps.size());
    System.assertEquals('Opp West Open', openOpps[0].Name);

    System.assertEquals(1, wonOpps.size());
    System.assertEquals('Opp West Won', wonOpps[0].Name);
  }

  @isTest
  static void testGenerateCSV() {
    Test.startTest();
    String csv = KpiDashBoardController.generateCSV();
    Test.stopTest();

    System.assertNotEquals(null, csv);
    System.assert(csv.contains('Name,Amount,Stage,Close Date'));
    System.assert(csv.contains('Opp West Open'));
  }
}