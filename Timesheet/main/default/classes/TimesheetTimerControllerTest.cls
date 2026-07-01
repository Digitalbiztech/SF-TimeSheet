@isTest
private class TimesheetTimerControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create an employee
        Employee__c emp = new Employee__c(
            First_Name__c = 'Test',
            Last_Name__c = 'User',
            User__c = UserInfo.getUserId(),
            Active__c = true
        );
        insert emp;
        
        // Create a project
        Project__c proj = new Project__c(
            Name = 'Test Project',
            Active__c = true,
            Billable__c = 'Yes'
        );
        insert proj;
        
        // Assign employee to project
        Project_Employee__c pe = new Project_Employee__c(
            Project__c = proj.Id,
            Employee__c = emp.Id
        );
        insert pe;
    }
    
    @isTest
    static void testGetTimerInitData() {
        Test.startTest();
        Map<String, Object> result = TimesheetTimerController.getTimerInitData();
        Test.stopTest();
        
        System.assertNotEquals(null, result.get('employeeId'), 'Employee ID should be returned');
        List<Project_Employee__c> projects = (List<Project_Employee__c>)result.get('projects');
        System.assertEquals(1, projects.size(), 'Should have 1 project assigned');
    }
    
    @isTest
    static void testStartAndStopTimer() {
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        
        Test.startTest();
        // Start timer
        Timesheet_Line_Item__c activeTimer = TimesheetTimerController.startTimer(emp.Id, proj.Id, 'Development-Coding');
        System.assertNotEquals(null, activeTimer.Start_Time__c, 'Start time should be set');
        
        // Stop timer
        TimesheetTimerController.stopTimer(activeTimer.Id, Datetime.now().getTime());
        Test.stopTest();
        
        Timesheet_Line_Item__c updatedTimer = [SELECT Id, Start_Time__c, End_Time__c, Duration__c FROM Timesheet_Line_Item__c WHERE Id = :activeTimer.Id];
        System.assertNotEquals(null, updatedTimer.End_Time__c, 'End time should be set');
        System.assertNotEquals(null, updatedTimer.Duration__c, 'Duration should be calculated');
    }
}
