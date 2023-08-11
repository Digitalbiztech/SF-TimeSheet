@isTest
public class TimesheetLineItemTriggerHandlerTest {
    
    @isTest
    public static void beforeInsertTest(){
        User u = createAdminUser();
        insert u;
        
        Employee__c employee = createEmployeeForUser(u.Id);
        insert employee;
        
        Timesheet__c timesheet = createTimesheet(employee.Id, u.Id);
        insert timesheet;
        
        Project__c project = createProjectAsBillable('Test Project','Yes');
        insert project;
        
        Timesheet_Line_Item__c timesheetLineItem = createTimesheetLineItem(timesheet.Id, project.Id);
        Timesheet_Line_Item__c timesheetLineItem2 = createTimesheetLineItem(timesheet.Id, project.Id);
        
        Test.startTest();
	    insert timesheetLineItem;
        try{
            insert timesheetLineItem2;
        } catch(DmlException e){
            Assert.areEqual('LineItem with the same project and activity already exists for this date, please update the existing record', e.getDmlMessage(0), 'Assertion failed when a timesheet line item is created with same project');
        }
        Test.stopTest();
        
        Timesheet_Line_Item__c timesheetLineItemFromDB = [Select Id, Employee__c, Billable__c from Timesheet_Line_Item__c where Id = : timesheetLineItem.Id];
        Assert.areEqual(timesheet.Employee__c, timesheetLineItemFromDB.Employee__c, 'Assertion failed for Employee');
        Assert.areEqual(project.Billable__c, timesheetLineItemFromDB.Billable__c, 'Assertion failed for Billable field');
    }
    
    @isTest
    public static void beforeUpdateTest(){
        
        User u = createAdminUser();
        insert u;
        
        Employee__c employee = createEmployeeForUser(u.Id);
        insert employee;
        
        Timesheet__c timesheet = createTimesheet(employee.Id, u.Id);
        insert timesheet;
        
        Project__c project = createProjectAsBillable('Test Project','Yes');
        insert project;
        Project__c project2 = createProjectAsBillable('Test Project 2','Yes');
        insert project2;
        
        Timesheet_Line_Item__c timesheetLineItem = createTimesheetLineItem(timesheet.Id, project.Id);
        Timesheet_Line_Item__c timesheetLineItem2 = createTimesheetLineItem(timesheet.Id, project2.Id);
        insert timesheetLineItem;
        insert timesheetLineItem2;
        timesheetLineItem2.Project__c = project.Id;
        
        Test.startTest();
	    
        try{
            update timesheetLineItem2;
        } catch(DmlException e){
            Assert.areEqual('LineItem with the same project and activity already exists for this date, please update the existing record', e.getDmlMessage(0), 'Assertion failed when a timesheet line item is created with same project');
        }
        Test.stopTest();
    }
    
    private static User createAdminUser(){
        Profile p = [Select Id, Name from Profile where Name = 'System Administrator' LIMIT 1];
        
        User u = new User();
        u.Email = 'testEmail@'+ Datetime.now().format('hh.mm.ss.SSS') + '.com';
        u.ProfileId = p.Id;
        u.Username = 'testUserName'+ Datetime.now().format('hh.mm.ss.SSS')+'@testmail.com';
        u.Alias = 'abcd';
        u.CommunityNickname = 'nickName' + Datetime.now().format('hh.mm.ss.SSS');
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey='ISO-8859-1';
        u.ManagerId = UserInfo.getUserId();
        u.LanguageLocaleKey='en_US';
        u.FirstName = 'fName'+ Datetime.now().format('hh.mm.ss.SSS');
        u.LastName = 'lName' + Datetime.now().format('hh.mm.ss.SSS');
        u.Phone = '9876543210';
        return u;
    }
    
    private static Employee__c createEmployeeForUser(Id userId){
        Employee__c employee = new Employee__c();
        employee.Name = '-';
        employee.First_Name__c = 'fName';
        employee.Last_Name__c = 'lName';
        employee.User__c = userId;
        employee.Email__c = 'testEmail@'+ Datetime.now().format('hh.mm.ss.SSS') + '.com';
        employee.Manager__c = UserInfo.getUserId();
        return employee;
    }
    
    private static Timesheet__c createTimesheet(Id employeeId, Id userId){
        Timesheet__c timesheet = new Timesheet__c();
        timesheet.Start_Date__c = System.today();
        timesheet.End_Date__c = System.today()+6;
        timesheet.Name = 'Timesheet for ' + timesheet.Start_Date__c + ' to '+ timesheet.End_Date__c;
        timesheet.Employee__c = employeeId;
        timesheet.OwnerId = userId;
        return timesheet;
    }
    
    private static Project__c createProjectAsBillable(String projectName, String isBillable){
        Project__c project = new Project__c();
        project.Name = projectName;
        project.Start_Date__c = System.today();
        project.End_Date__c = System.today()+365;
        project.Active__c = true;
        project.Billable__c = isBillable;
        return project;
    }
    
    private static Timesheet_Line_Item__c createTimesheetLineItem(Id timesheetId, Id projectId){
        Timesheet_Line_Item__c timesheetLineItem = new Timesheet_Line_Item__c();
        timesheetLineItem.Type__c = 'Attendance';
        timesheetLineItem.Timesheet__c = timesheetId;
        timesheetLineItem.Date__c = System.today();
        timesheetLineItem.Project__c = projectId;
        timesheetLineItem.Activity__c = 'other';
        timesheetLineItem.Duration__c = 5;
        timesheetLineItem.Description__c = 'Test Description';
        return timesheetLineItem;
    }
}