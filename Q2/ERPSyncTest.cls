@isTest
public class ERPSyncTest {
  private class MockHttpResponseGenerator implements HttpCalloutMock {
    private Integer statusCode;
    private String status;
    private String body;
    private Boolean throwException = false;

    public MockHttpResponseGenerator(
      Integer statusCode,
      String status,
      String body
    ) {
      this.statusCode = statusCode;
      this.status = status;
      this.body = body;
    }

    public MockHttpResponseGenerator(Boolean throwException) {
      this.throwException = throwException;
    }

    public HTTPResponse respond(HTTPRequest req) {
      if (throwException) {
        throw new CalloutException('Simulated HTTP exception');
      }
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody(body);
      res.setStatusCode(statusCode);
      res.setStatus(status);
      return res;
    }
  }

  @testSetup
  static void setupTestData() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 15; i++) {
      accounts.add(
        new Account(
          Name = 'Test Account ' + i,
          Sync_Status__c = 'Pending',
          Sync_Retry_Count__c = 0
        )
      );
    }
    insert accounts;
  }

  private static void setupMockConfig() {
    ERPSyncQueueable.config = (ERP_Config__mdt) JSON.deserialize(
      '{"Max_Retries__c": 3, "Endpoint_URL__c": "https://api.example.com/erp/sync", "Timeout_ms__c": 10000}',
      ERP_Config__mdt.class
    );
  }

  @isTest
  static void testScheduler() {
    setupMockConfig();
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(200, 'OK', '{"success": true}')
    );

    Test.startTest();
    String cronExpr = '0 0 0 15 3 ? 2030';
    String jobId = System.schedule(
      'TestERPSyncScheduler',
      cronExpr,
      new ERPSyncScheduler()
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      jobId,
      'Scheduler should be scheduled successfully'
    );
  }

  @isTest
  static void testQueueableSuccess() {
    setupMockConfig();
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(200, 'OK', '{"success": true}')
    );

    List<Account> pendingAccs = [
      SELECT Id
      FROM Account
      WHERE Sync_Status__c = 'Pending'
      LIMIT 5
    ];
    List<Id> accIds = new List<Id>();
    for (Account a : pendingAccs) {
      accIds.add(a.Id);
    }

    Test.startTest();
    System.enqueueJob(new ERPSyncQueueable(accIds));
    Test.stopTest();

    List<Account> updatedAccs = [
      SELECT Sync_Status__c, Last_Sync_Time__c
      FROM Account
      WHERE Id IN :accIds
    ];
    for (Account a : updatedAccs) {
      System.assertEquals(
        'Synced',
        a.Sync_Status__c,
        'Account status should be updated to Synced'
      );
      System.assertNotEquals(
        null,
        a.Last_Sync_Time__c,
        'Last sync time should be set'
      );
    }
  }

  @isTest
  static void testQueueableRetryUnderLimit() {
    setupMockConfig();
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(
        500,
        'Error',
        '{"error": "Internal Server Error"}'
      )
    );

    List<Account> pendingAccs = [
      SELECT Id
      FROM Account
      WHERE Sync_Status__c = 'Pending'
      LIMIT 5
    ];
    List<Id> accIds = new List<Id>();
    for (Account a : pendingAccs) {
      accIds.add(a.Id);
    }

    Test.startTest();
    System.enqueueJob(new ERPSyncQueueable(accIds));
    Test.stopTest();

    List<Account> updatedAccs = [
      SELECT Sync_Status__c, Sync_Retry_Count__c
      FROM Account
      WHERE Id IN :accIds
    ];
    for (Account a : updatedAccs) {
      System.assertEquals(
        1,
        a.Sync_Retry_Count__c,
        'Retry count should be incremented'
      );
      System.assertEquals(
        'Pending',
        a.Sync_Status__c,
        'Account status should remain Pending'
      );
    }
  }

  @isTest
  static void testQueueableFailedOverLimit() {
    ERPSyncQueueable.config = (ERP_Config__mdt) JSON.deserialize(
      '{"Max_Retries__c": 1, "Endpoint_URL__c": "https://api.example.com/erp/sync", "Timeout_ms__c": 10000}',
      ERP_Config__mdt.class
    );
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(
        500,
        'Error',
        '{"error": "Failed completely"}'
      )
    );

    List<Account> pendingAccs = [
      SELECT Id
      FROM Account
      WHERE Sync_Status__c = 'Pending'
      LIMIT 2
    ];
    List<Id> accIds = new List<Id>();
    for (Account a : pendingAccs) {
      accIds.add(a.Id);
    }

    Test.startTest();
    System.enqueueJob(new ERPSyncQueueable(accIds));
    Test.stopTest();

    List<Account> updatedAccs = [
      SELECT Sync_Status__c, Sync_Retry_Count__c
      FROM Account
      WHERE Id IN :accIds
    ];
    for (Account a : updatedAccs) {
      System.assertEquals(
        1,
        a.Sync_Retry_Count__c,
        'Retry count should be incremented to 1'
      );
      System.assertEquals(
        'Failed',
        a.Sync_Status__c,
        'Account status should be Failed'
      );
    }

    List<Error_Log__c> logs = [
      SELECT Account__c, Response_Body__c
      FROM Error_Log__c
      WHERE Account__c IN :accIds
    ];
    System.assertEquals(2, logs.size(), 'Two error logs should be created');
    System.assertEquals(
      '{"error": "Failed completely"}',
      logs[0].Response_Body__c,
      'Error log response body should match'
    );
  }

  @isTest
  static void testQueueableBatching() {
    setupMockConfig();
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(200, 'OK', '{"success": true}')
    );

    List<Account> pendingAccs = [
      SELECT Id
      FROM Account
      WHERE Sync_Status__c = 'Pending'
    ];
    List<Id> accIds = new List<Id>();
    for (Account a : pendingAccs) {
      accIds.add(a.Id);
    }

    Test.startTest();
    System.enqueueJob(new ERPSyncQueueable(accIds));
    Test.stopTest();
    Integer firstBatchSyncedCount = [SELECT COUNT() FROM Account WHERE Sync_Status__c = 'Synced'];
    System.assertEquals(10, firstBatchSyncedCount, 'First 10 accounts should be synced after the first job');
    List<Account> remainingAccs = [SELECT Id FROM Account WHERE Sync_Status__c = 'Pending'];
    List<Id> remainingAccIds = new List<Id>();
    for (Account a : remainingAccs) {
      remainingAccIds.add(a.Id);
    }
    ERPSyncQueueable secondJob = new ERPSyncQueueable(remainingAccIds);
    secondJob.execute(null);
    Integer totalSyncedCount = [SELECT COUNT() FROM Account WHERE Sync_Status__c = 'Synced'];
    System.assertEquals(15, totalSyncedCount, 'All 15 accounts should be synced after both jobs execute');
  }

  @isTest
  static void testCalloutExceptionHandling() {
    setupMockConfig();
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

    List<Account> pendingAccs = [
      SELECT Id
      FROM Account
      WHERE Sync_Status__c = 'Pending'
      LIMIT 1
    ];
    List<Id> accIds = new List<Id>();
    accIds.add(pendingAccs[0].Id);

    ERPSyncQueueable.config = (ERP_Config__mdt) JSON.deserialize(
      '{"Max_Retries__c": 1, "Endpoint_URL__c": "https://api.example.com/erp/sync", "Timeout_ms__c": 10000}',
      ERP_Config__mdt.class
    );

    Test.startTest();
    System.enqueueJob(new ERPSyncQueueable(accIds));
    Test.stopTest();

    List<Account> updatedAccs = [
      SELECT Sync_Status__c, Sync_Retry_Count__c
      FROM Account
      WHERE Id IN :accIds
    ];
    System.assertEquals(
      'Failed',
      updatedAccs[0].Sync_Status__c,
      'Account status should be Failed on exception when retry limit is hit'
    );

    List<Error_Log__c> logs = [
      SELECT Response_Body__c
      FROM Error_Log__c
      WHERE Account__c = :accIds[0]
    ];
    System.assertEquals(1, logs.size(), 'An error log should be inserted');
    System.assertEquals(
      'Simulated HTTP exception',
      logs[0].Response_Body__c,
      'Error log response body should contain the exception message'
    );
  }
}