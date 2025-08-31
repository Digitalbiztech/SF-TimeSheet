@isTest
public class WeeklyTimesheetControllerTest {

    @testSetup
    static void setupTestData() {
        // Create a test user
        User u = new User(
            Alias = 'testuser',
            LastName = 'Test',
            Email = 'test@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert u;

        // Create a test employee
        Employee__c emp = new Employee__c(
            Name = 'Test Employee',
            User__c = u.Id,
            Employment_Type__c = 'Full Time'
        );
        insert emp;

        // Create a test project
        Project__c project = new Project__c(Name = 'Test Project', Billable__c = 'Yes',Active__c = true);
        insert project;

        // Assign employee to the project
        Project_Employee__c pe = new Project_Employee__c(
            Employee__c = emp.Id,
            Project__c = project.Id
        );
        insert pe;

        // Create a timesheet
        Timesheet__c ts1 = new Timesheet__c(
            Name = 'Week 1',
            Employee__c = emp.Id,
            Start_Date__c = Date.today().addDays(-7),
            End_Date__c = Date.today()
        );
        insert ts1;

        // Create another timesheet for history
        Timesheet__c ts2 = new Timesheet__c(
            Name = 'Week 0',
            Employee__c = emp.Id,
            Start_Date__c = Date.today().addDays(-14),
            End_Date__c = Date.today().addDays(-8)
        );
        insert ts2;

        // Create timesheet line item
        Timesheet_Line_Item__c lineItem = new Timesheet_Line_Item__c(
            Timesheet__c = ts1.Id,
            Date__c = Date.today().addDays(-5),
            Project__c = project.Id,
            Activity__c = 'Testing',
            Duration__c = 8,
            Description__c = 'Worked on feature A',
            Type__c = 'Attendance'
        );
        insert lineItem;
    }

    @isTest
    static void testGetTimesheet() {
        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        Timesheet__c result = WeeklyTimesheetController.getTimesheet(ts.Id);
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetEmployeeTimesheetItems() {
        Timesheet__c ts = [SELECT Id, Employee__c FROM Timesheet__c LIMIT 1];
        List<Timesheet__c> results = WeeklyTimesheetController.getEmployeeTimesheetItems(
            String.valueOf(ts.Employee__c), String.valueOf(ts.Id));
        System.assert(results != null);
    }

    @isTest
    static void testGetProjects() {
        Timesheet__c ts = [SELECT Employee__c FROM Timesheet__c LIMIT 1];
        List<Project_Employee__c> projects = WeeklyTimesheetController.getProjects(
            String.valueOf(ts.Employee__c));
        System.assert(projects != null);
    }

    @isTest
    static void testGetWeeklyTimesheetItems() {
        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        List<Timesheet_Line_Item__c> items = WeeklyTimesheetController.getWeeklyTimesheetItems(ts.Id);
        System.assert(items.size() > 0, 'Should return at least one line item');
    }

    @isTest
    static void testUpsertLineItems() {
        // Create a test project
        Project__c project = new Project__c(Name = 'Test Project', Billable__c = 'Yes',Active__c = true);
        insert project;
        
        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        Timesheet_Line_Item__c newItem = new Timesheet_Line_Item__c(
            Timesheet__c = ts.Id,
            Date__c = Date.today(),
            Project__c = project.Id,
            Activity__c = 'Testing',
            Duration__c = 4,
            Type__c = 'Attendance'
        );

        List<Timesheet_Line_Item__c> items = new List<Timesheet_Line_Item__c>{ newItem };

        String result = WeeklyTimesheetController.upsertLineItems(items);
        System.assertEquals('Success', result);
    }

    @isTest
    static void testUpsertLineItemsEmptyList() {
        String result = WeeklyTimesheetController.upsertLineItems(new List<Timesheet_Line_Item__c>());
        System.assertEquals(true, result.contains('Error'));
    }

    @isTest
    static void testDeleteTimesheetLineItems() {
        Timesheet_Line_Item__c item = [SELECT Id FROM Timesheet_Line_Item__c LIMIT 1];
        List<Timesheet_Line_Item__c> toDelete = new List<Timesheet_Line_Item__c>{ item };
        String result = WeeklyTimesheetController.deleteTimesheetLineItems(toDelete);
        System.assertEquals('Success', result);
    }

    @isTest
    static void testDeleteTimesheetLineItemsEmptyList() {
        String result = WeeklyTimesheetController.deleteTimesheetLineItems(new List<Timesheet_Line_Item__c>());
        System.assertEquals(true, result.contains('Error'));
    }
}