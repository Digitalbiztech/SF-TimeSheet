@isTest
public class TimesheetLineItemControllerTest {
    
    @isTest
    public static void getTimesheetLineItemsTest(){
        User u = createAdminUser();
        insert u;
        
        Employee__c employee = createEmployeeForUser(u.Id);
        insert employee;
        
        Timesheet__c timesheet = createTimesheet(employee.Id, u.Id);
        insert timesheet;
        
        Project__c project1 = createProjectAsBillable('Test Project 1',true);
        insert project1;
        
        Project__c project2 = createProjectAsBillable('Test Project 2',true);
        insert project2;
        
        Project__c project3 = createProjectAsBillable('Test Project 3',true);
        insert project3;
        
        Timesheet_Line_Item__c timesheetLineItem1 = createTimesheetLineItemForAttendace(timesheet.Id, project1.Id);
        insert timesheetLineItem1;
        Timesheet_Line_Item__c timesheetLineItem2 = createTimesheetLineItemForAttendace(timesheet.Id, project2.Id);
        timesheetLineItem2.Date__c = System.today()+1;
        insert timesheetLineItem2;
        Timesheet_Line_Item__c timesheetLineItem3 = createTimesheetLineItemForAttendace(timesheet.Id, project3.Id);
        timesheetLineItem3.Date__c = System.today()+2;
        insert timesheetLineItem3;
        Timesheet_Line_Item__c timesheetLineItem4 = createTimesheetLineItemForAbsence(timesheet.Id);
        timesheetLineItem4.Date__c = System.today()+3;
        insert timesheetLineItem4;
        Timesheet_Line_Item__c timesheetLineItem5 = createTimesheetLineItemForAbsence(timesheet.Id);
        timesheetLineItem5.Date__c = System.today()+4;
        insert timesheetLineItem5;
        
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(timesheet.Id);
        Approval.ProcessResult result = Approval.process(req);
        
        System.assert(result.isSuccess());
        System.assertEquals('Pending', result.getInstanceStatus(), 'Instance Status is : '+result.getInstanceStatus());
        
        List<ProcessInstance> piList = [Select Id, Status, CreatedDate from ProcessInstance where TargetObjectId = : timesheet.Id ORDER BY CreatedDate DESC];
        ProcessInstance pi = piList.get(0);
        List<ProcessInstanceWorkItem> piWiList = [Select Id, CreatedDate from ProcessInstanceWorkItem where ProcessInstanceId = : pi.Id ORDER BY CreatedDate DESC];
        ProcessInstanceWorkItem piWi = piWiList.get(0);
        
        Test.startTest();
        List<Timesheet_Line_Item__c> timesheetLineItemList = TimesheetLineItemController.getTimesheetLineItems(piWi.Id);
        Test.stopTest();
        System.assertEquals(5, timesheetLineItemList.size(), 'timesheetLineItemList size should be 5');
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
        timesheet.Manager__c = UserInfo.getUserId();
        return timesheet;
    }
    
    private static Project__c createProjectAsBillable(String projectName, Boolean isBillable){
        Project__c project = new Project__c();
        project.Name = projectName;
        project.Start_Date__c = System.today();
        project.End_Date__c = System.today()+365;
        project.Active__c = true;
        if(isBillable == true){
            project.Billable__c = 'Yes';
          } else{
              project.Billable__c = 'No';
          }
        project.Billable__c = 'Yes';
        return project;
    }
    
    private static Timesheet_Line_Item__c createTimesheetLineItemForAttendace(Id timesheetId, Id projectId){
        Timesheet_Line_Item__c timesheetLineItem = new Timesheet_Line_Item__c();
        timesheetLineItem.Type__c = 'Attendance';
        timesheetLineItem.Timesheet__c = timesheetId;
        timesheetLineItem.Date__c = System.today();
        timesheetLineItem.Project__c = projectId;
        timesheetLineItem.Activity__c = 'other';
        timesheetLineItem.Duration__c = 8;
        timesheetLineItem.Description__c = 'Test Description';
        return timesheetLineItem;
    }
    
    private static Timesheet_Line_Item__c createTimesheetLineItemForAbsence(Id timesheetId){
        Timesheet_Line_Item__c timesheetLineItem = new Timesheet_Line_Item__c();
        timesheetLineItem.Type__c = 'Absence';
        timesheetLineItem.Timesheet__c = timesheetId;
        timesheetLineItem.Date__c = System.today();
        timesheetLineItem.Absence_Category__c = 'Sick Leave';
        timesheetLineItem.Duration__c = 8;
        timesheetLineItem.Description__c = 'Test Description';
        return timesheetLineItem;
    }
}