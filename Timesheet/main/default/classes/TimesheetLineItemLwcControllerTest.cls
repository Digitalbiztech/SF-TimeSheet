@isTest
public class TimesheetLineItemLwcControllerTest {

    @testSetup
    public static void setupData(){
        User noAccessUser = createUser('NoAccess', 'User');
        insert noAccessUser;
        
        User standardUser = createUser('Standard', 'User');
        insert standardUser;
        
        assignpermissionSetForUser(standardUser);
        User adminUser = createAdminUser('Admin', 'User');
        insert adminUser;
        
        assignpermissionSetForAdmin(adminUser);
        Employee__c employee = createEmployeeForUser(standardUser.Id);
        insert employee;
        
        Timesheet__c timesheet = createTimesheet(employee.Id, standardUser.Id);
        insert timesheet;
        
        Project__c project = createProjectAsBillable('Test Project','Yes');
        insert project;
        
        Project_Employee__c projectEmployee = createProjectEmployee(project.id, employee.Id);
        insert projectEmployee;
        
        Timesheet_Line_Item__c timesheetLineItem = createTimesheetLineItem(timesheet.Id, project.Id);
        insert timesheetLineItem;
    }
    
    @isTest
    public static void getProjectsTest(){
        Employee__c employee = [SELECT Id, Name FROM Employee__c LIMIT 1];
        User u = [Select Id, Name from User where FirstName = 'Standard' AND LastName = 'User' LIMIT 1];
        System.runAs(u){
            Test.startTest();
            List<Project_Employee__c> projectEmployees = TimesheetLineItemLwcController.getProjects(employee.Id);
            Test.stopTest();
            Assert.areEqual(1, projectEmployees.size(), 'The projectEmployees size assertion failed');
        }
    }
    
    @isTest
    public static void getProjectsTestwithException(){
        Employee__c employee = [SELECT Id, Name FROM Employee__c LIMIT 1];
        User u = [Select Id, Name from User Where FirstName = 'NoAccess' AND LastName ='User'];
        System.runAs(u){
            try{
                Test.startTest();
                List<Project_Employee__c> projectEmployees = TimesheetLineItemLwcController.getProjects(employee.Id);
                Test.stopTest();
            }catch(AuraHandledException e){
                Assert.areEqual('You do not have access, please contact System Admin', e.getMessage());
            }
        }
    }
    
    @isTest
    public static void getTimesheetLineItemsTest(){
        Timesheet__c timesheet = [Select Id, Name from Timesheet__c LIMIT 1];
        User u = [Select Id, Name from User Where FirstName = 'Standard' AND LastName ='User'];
        System.runAs(u){
            Test.startTest();
            List<Timesheet_Line_Item__c> timesheetLineItems = TimesheetLineItemLwcController.getTimesheetLineItems(timesheet.Id);
            Test.stopTest();
            Assert.areEqual(1, timesheetLineItems.size(), 'Assertion failed for timesheet line items size');
        }
    }
    
    @isTest
    public static void getTimesheetLineItemsTestWithException(){
        Timesheet__c timesheet = [Select Id, Name from Timesheet__c LIMIT 1];
        User u = [Select Id, Name from User Where FirstName = 'NoAccess' AND LastName ='User'];
        System.runAs(u){
            try{
                Test.startTest();
                List<Timesheet_Line_Item__c> timesheetLineItems = TimesheetLineItemLwcController.getTimesheetLineItems(timesheet.Id);
                Test.stopTest();
            }catch(Exception e){
                Assert.areEqual('You do not have access, please contact System Admin', e.getMessage());
            }
        }
    }
    
    @isTest
    public static void updateTimesheetLineItemsTest(){
        Timesheet__c timesheet = [Select Id, Name from Timesheet__c LIMIT 1];
        Timesheet_Line_Item__c timesheetLineItem1 = [Select Id, Name, Employee__c from Timesheet_Line_Item__c LIMIT 1];
        Project__c newProject = createProjectAsBillable('TestName', 'Yes');
        insert newProject;
        Timesheet_Line_Item__c timesheetLineItem2 = createTimesheetLineItem(timesheet.Id, newProject.Id);
        timesheetLineItem2.Activity__c = 'Testing';
        List<Timesheet_Line_Item__c> timesheetLineItems = new List<Timesheet_Line_Item__c>();
        timesheetLineItems.add(timesheetLineItem2);
        List<Id> ids = new List<Id>();
        ids.add(timesheetLineItem1.Id);
        
        Test.startTest();
        TimesheetLineItemLwcController.updateTimesheetLineItems(timesheetLineItems, ids);
        Test.stopTest();
        
        Timesheet_Line_Item__c timesheetLineItemFromDB = [Select Id, Name from Timesheet_Line_Item__c LIMIT 1];
        Assert.areNotEqual(timesheetLineItem1.Id, timesheetLineItemFromDB.Id, 'Assertion failed when two timesheet line items should not match');

    }
    
    @isTest
    public static void updateTimesheetLineItemsTestWithException(){
        Timesheet__c timesheet = [Select Id, Name from Timesheet__c LIMIT 1];
        Timesheet_Line_Item__c timesheetLineItem1 = [Select Id, Name, Employee__c from Timesheet_Line_Item__c LIMIT 1];
        Project__c newProject = createProjectAsBillable('TestName', 'Yes');
        insert newProject;
        Timesheet_Line_Item__c timesheetLineItem2 = createTimesheetLineItem(timesheet.Id, newProject.Id);
        timesheetLineItem2.Activity__c = 'Testing';
        List<Timesheet_Line_Item__c> timesheetLineItems = new List<Timesheet_Line_Item__c>();
        timesheetLineItems.add(timesheetLineItem2);
        List<Id> ids = new List<Id>();
        ids.add(timesheetLineItem1.Id);
        
        User u = [Select Id, Name from User Where FirstName = 'NoAccess' AND LastName ='User'];
        System.runAs(u){
            try{
                Test.startTest();
                TimesheetLineItemLwcController.updateTimesheetLineItems(timesheetLineItems, ids);
                Test.stopTest();
            }catch(Exception e){
                Assert.areEqual('You do not have access, please contact System Admin', e.getMessage());
            }
        }
    }
        
    private static User createAdminUser(String firstName, String lastName){
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
        u.FirstName = firstName;
        u.LastName = lastName;
        u.Phone = '9876543210';
        return u;
    }
    
    private static Employee__c createEmployeeForUser(Id userId){
        Employee__c employee = new Employee__c();
        employee.Name = '';
        employee.OwnerId = userId;
        employee.First_Name__c = 'first';
        employee.Last_Name__c = 'last';
        employee.User__c = userId;
        employee.Email__c = 'testEmail@'+ Datetime.now().format('hh.mm.ss.SSS') + '.com';
        employee.Manager__c = userInfo.getUserId();
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
    
    private static void assignpermissionSetForAdmin(User u){
        Id userId = UserInfo.getUserId();
        User user = [Select Id, Name from User Where Id =: userId];
        PermissionSet ps = [Select 
                            Id, 
                            Name 
                            FROM PermissionSet 
                            WHERE Name = 'Timesheet_HR_Admin'];
        System.runAs(user){
            PermissionSetAssignment psa = new PermissionSetAssignment();
        	psa.PermissionSetId = ps.Id;
        	psa.AssigneeId = u.Id;
            insert psa;
        }
    }
    
    private static void assignpermissionSetForUser(User u){
        Id userId = UserInfo.getUserId();
        User user = [Select Id, Name from User Where Id =: userId];
        PermissionSet ps = [Select 
                            Id, 
                            Name 
                            FROM PermissionSet 
                            WHERE Name = 'Timesheet_User'];
        System.runAs(user){
            PermissionSetAssignment psa = new PermissionSetAssignment();
        	psa.PermissionSetId = ps.Id;
        	psa.AssigneeId = u.Id;
            insert psa;
        }
    }
    
    private static User createUser(String firstName, String lastName){
        Profile p = [Select Id, Name from Profile where Name = 'Standard User' LIMIT 1];
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
        u.FirstName = firstName;
        u.LastName = lastName;
        u.Phone = '9876543210';
        return u;
    }
    
    private static Project_Employee__c createProjectEmployee(Id projectId, Id employeeId){
        Project_Employee__c projectEmployee = new Project_Employee__c();
        projectEmployee.Project__c = projectId;
        projectEmployee.Employee__c = employeeId;
        return projectEmployee;
    }
}