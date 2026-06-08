@isTest
private class KanbanBoardControllerTest {
  @testSetup
  static void setupTestData() {
    List<Case> cases = new List<Case>();
    cases.add(new Case(Subject = 'Case 1', Status = 'New', Priority = 'High'));
    cases.add(
      new Case(Subject = 'Case 2', Status = 'Working', Priority = 'Medium')
    );
    insert cases;
  }

  @isTest
  static void testGetCasesByStatus() {
    Test.startTest();
    Map<String, List<Case>> casesMap = KanbanBoardController.getCasesByStatus();
    Test.stopTest();

    System.assertNotEquals(null, casesMap);
    System.assert(casesMap.containsKey('New'));
    System.assert(casesMap.containsKey('Working'));
    System.assertEquals(1, casesMap.get('New').size());
    System.assertEquals('Case 1', casesMap.get('New')[0].Subject);
  }

  @isTest
  static void testUpdateCaseStatusSuccess() {
    Case c = [SELECT Id FROM Case WHERE Status = 'New' LIMIT 1];

    Test.startTest();
    KanbanBoardController.updateCaseStatus(c.Id, 'Working');
    Test.stopTest();

    Case updated = [SELECT Status FROM Case WHERE Id = :c.Id];
    System.assertEquals('Working', updated.Status);
  }

  @isTest
  static void testUpdateCaseStatusFailure() {
    Case c = [SELECT Id FROM Case WHERE Status = 'Working' LIMIT 1];

    Test.startTest();
    try {
      KanbanBoardController.updateCaseStatus(c.Id, 'New');
      System.assert(
        false,
        'Should have failed due to invalid status transition'
      );
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    }
    Test.stopTest();
  }
}