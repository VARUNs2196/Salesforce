public with sharing class KpiDashBoardController {
  @AuraEnabled(cacheable=true)
  public static Map<String, String> getKpiSummary(String region) {
    Decimal openPipeline = 0;
    for (AggregateResult agg : [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE isClosed = FALSE AND Region__c = :region
      GROUP BY Region__c
    ]) {
      openPipeline = (Decimal) agg.get('total');
    }
    Decimal wonRevenue = 0;
    for (AggregateResult agg : [
      SELECT SUM(Amount) total
      FROM Opportunity
      WHERE StageName = 'Closed Won' AND Region__c = :region
      GROUP BY Region__c
    ]) {
      wonRevenue = (Decimal) agg.get('total');
    }
    Decimal avgDealSize = 0;
    for (AggregateResult agg : [
      SELECT AVG(Amount) total
      FROM Opportunity
      WHERE isClosed = TRUE AND Region__c = :region
      GROUP BY Region__c
    ]) {
      avgDealSize = (Decimal) agg.get('total');
    }
    Decimal winRate = 0;
    Decimal totalOpportunities = 0;
    Decimal wonOpportunities = 0;
    for (AggregateResult agg : [
      SELECT COUNT(Id) total
      FROM Opportunity
      WHERE Region__c = :region
      GROUP BY Region__c
    ]) {
      totalOpportunities = (Decimal) agg.get('total');
    }
    for (AggregateResult agg : [
      SELECT COUNT(Id) total
      FROM Opportunity
      WHERE Region__c = :region AND StageName = 'Closed Won'
      GROUP BY Region__c
    ]) {
      wonOpportunities = (Decimal) agg.get('total');
    }
    if (totalOpportunities > 0) {
      winRate = wonOpportunities / totalOpportunities;
    }
    Map<String, String> kpiSummary = new Map<String, String>();
    kpiSummary.put('openPipeline', openPipeline.toString());
    kpiSummary.put('wonRevenue', wonRevenue.toString());
    kpiSummary.put('avgDealSize', avgDealSize.toString());
    kpiSummary.put('winRate', (winRate * 100) + '%');

    return kpiSummary;
  }
  @AuraEnabled(cacheable=true)
  public static List<Opportunity> getTopOpportunities(
    String kpiType,
    String region
  ) {
    List<Opportunity> oppList = new List<Opportunity>();
    Boolean hasRegionFilter = (region != null &&
    region != 'None' &&
    region != '');

    String baseQuery = 'SELECT Id, Name, Amount, StageName, CloseDate FROM Opportunity ';
    List<String> conditions = new List<String>();

    if (kpiType == 'openPipeline') {
      conditions.add('isClosed = false');
    } else if (kpiType == 'wonRevenue') {
      conditions.add('StageName = \'Closed Won\'');
    } else if (kpiType == 'avgDealSize') {
      conditions.add('isClosed = true AND Amount != null');
    } else if (kpiType == 'winRate') {
      conditions.add('StageName = \'Closed Won\'');
    }

    if (hasRegionFilter) {
      conditions.add('Region__c = :region');
    }

    if (!conditions.isEmpty()) {
      baseQuery += ' WHERE ' + String.join(conditions, ' AND ');
    }

    baseQuery += ' ORDER BY Amount DESC NULLS LAST LIMIT 5';

    try {
      oppList = Database.query(baseQuery);
    } catch (Exception e) {
      System.debug(
        'Error executing top opportunities query: ' + e.getMessage()
      );
    }

    return oppList;
  }
  @AuraEnabled
  public static String generateCSV() {
    List<Opportunity> opps = [
      SELECT Name, Amount, StageName, CloseDate
      FROM Opportunity
      ORDER BY Amount DESC
      LIMIT 50
    ];
    String csv = 'Name,Amount,Stage,Close Date\n';

    for (Opportunity opp : opps) {
      csv +=
        '"' +
        opp.Name +
        '",' +
        (opp.Amount == null ? 0 : opp.Amount) +
        ',' +
        '"' +
        opp.StageName +
        '",' +
        opp.CloseDate +
        '\n';
    }

    return csv;
  }
}